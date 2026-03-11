## @brief Unified terrain benchmark that runs the real generation pipeline.
##
## @details Consumes TerrainConfiguration resources through BenchmarkProfile.
## Measures pipeline generation, chunk generation at all LOD levels,
## cache behavior, and collects static triangle budgets 
class_name TerrainBenchmark extends RefCounted

signal benchmark_started()
signal config_started(config_name: String, index: int, total: int)
signal config_completed(config_name: String, result_count: int, elapsed_ms: float)
signal benchmark_completed(report: BenchmarkReport)

## Bytes per megabyte for memory unit conversion.
const BYTES_PER_MB: float = 1048576.0

## Number of triangles per quad (each quad = 2 triangles in a terrain grid).
const TRIS_PER_QUAD: int = 2

## Number of vertices (or indices) that define a single triangle.
const VERTS_PER_TRIANGLE: int = 3

## Milliseconds per second for unit conversion.
const MS_PER_SEC: float = 1000.0

func run(profile: BenchmarkProfile) -> BenchmarkReport:
	assert(not profile.configurations.is_empty(), "TerrainBenchmark: Profile has no configurations")
	_print_header(profile)
	benchmark_started.emit()
	var report := BenchmarkReport.new()
	var total_start := Time.get_ticks_usec()
	for i in range(profile.configurations.size()):
		report.add_results(_run_single_config(profile, i))
	report.add_results(_collect_render_snapshot())
	var total_elapsed := (Time.get_ticks_usec() - total_start) / 1000.0
	print("")
	print("Total: %d results in %.1f ms" % [report.get_result_count(), total_elapsed])
	report.print_report()
	_save_report(report, profile)
	benchmark_completed.emit(report)
	return report

func _run_single_config(profile: BenchmarkProfile, index: int) -> Array[BenchmarkResult]:
	var config := profile.configurations[index]
	var config_name := profile.get_config_name(index)
	print("\nConfiguration %d/%d: %s" % [index + 1, profile.configurations.size(), config_name])
	config_started.emit(config_name, index, profile.configurations.size())
	var config_start := Time.get_ticks_usec()
	var config_results := _benchmark_single_config(config, config_name, profile)
	var config_elapsed := (Time.get_ticks_usec() - config_start) / 1000.0
	config_completed.emit(config_name, config_results.size(), config_elapsed)
	print("  -> %d results in %.1f ms" % [config_results.size(), config_elapsed])
	return config_results

func _benchmark_single_config(
	config: TerrainConfigurationV2,
	config_name: String,
	profile: BenchmarkProfile
) -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	results.append_array(_benchmark_pipeline(config, config_name, profile))
	var definition := _generate_definition_quiet(config)
	if not definition:
		push_error("TerrainBenchmark: Failed to generate definition for %s" % config_name)
		return results
	results.append_array(_benchmark_chunks(config, config_name, definition, profile))
	return results

func _benchmark_pipeline(
	config: TerrainConfigurationV2,
	config_name: String,
	profile: BenchmarkProfile
) -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	var meta := {"config_name": config_name, "terrain_size": config.terrain_size.x}
	print("[Pipeline] Measuring full pipeline generation...")
	for _w in profile.warmup_iterations:
		_generate_definition_quiet(config)
	var total_samples := PackedFloat64Array()
	var stage_timings: Dictionary = {}   # stage_name -> PackedFloat64Array
	for _i in profile.iterations:
		var per_stage: Dictionary = {}   # stage_name -> float (single run)
		var generator := TerrainDefinitionGenerator.new()
		generator.verbose = false
		generator.stage_completed.connect(
			func(stage_name: String, elapsed_ms: float) -> void:
				per_stage[stage_name] = elapsed_ms
		)
		var context := _make_context(config)
		var start_time := Time.get_ticks_usec()
		generator.generate(
			config.heightmap_source, config.terrain_size, config.height_scale,
			config.modifier_stages, config.generation_seed,
			context, config.prop_placement_rules
		)
		total_samples.append((Time.get_ticks_usec() - start_time) / 1000.0)
		context.dispose()
		for stage_name in per_stage:
			if not stage_timings.has(stage_name):
				stage_timings[stage_name] = PackedFloat64Array()
			stage_timings[stage_name].append(per_stage[stage_name])
	results.append(BenchmarkResult.new("pipeline_total", "pipeline", "ms", total_samples, meta))
	for stage_name in stage_timings:
		var stage_meta := meta.duplicate()
		stage_meta["stage"] = stage_name
		results.append(BenchmarkResult.new(
			"pipeline_stage_%s" % stage_name, "pipeline", "ms", stage_timings[stage_name], stage_meta
		))
	var height_map_samples := PackedFloat64Array()
	for _i in profile.iterations:
		var context := _make_context(config)
		var t := Time.get_ticks_usec()
		config.heightmap_source.generate(context)
		height_map_samples.append((Time.get_ticks_usec() - t) / 1000.0)
		context.dispose()
	results.append(BenchmarkResult.new("heightmap_generation", "pipeline", "ms", height_map_samples, meta))
	return results

func _benchmark_chunks(
	config: TerrainConfigurationV2,
	config_name: String,
	definition: TerrainDefinition,
	profile: BenchmarkProfile
) -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	var chunk_size := config.chunk_size
	var lod_levels := profile.get_lod_levels_for_config(config)
	var coords := _spiral_chunk_coords(config, profile.chunks_to_generate)
	print("[Chunks] %d chunks × LODs %s ..." % [coords.size(), str(lod_levels)])
	var use_gpu := config.use_gpu_mesh_generation
	var strategy := CpuChunkGenerationStrategy.new()
	for lod in lod_levels:
		var effective_resolution := strategy.calculate_resolution_for_lod(config.base_chunk_resolution, lod)
		var meta := {
			"config_name": config_name, "lod_level": lod,
			"base_resolution": config.base_chunk_resolution,
			"effective_resolution": effective_resolution,
			"chunk_size": chunk_size.x,
			"processor": "gpu" if use_gpu else "cpu",
		}
		var chunk_generator := ChunkGenerator.new(definition, config.base_chunk_resolution, use_gpu)
		var substep_timings: Dictionary = {}   # substep_name -> PackedFloat64Array
		chunk_generator.get_strategy().substep_completed.connect(
			func(substep_name: String, elapsed_ms: float) -> void:
				if not substep_timings.has(substep_name):
					substep_timings[substep_name] = PackedFloat64Array()
				substep_timings[substep_name].append(elapsed_ms)
		)
		for _w in profile.warmup_iterations:
			chunk_generator.generate_chunk(coords[0], chunk_size, lod)
			substep_timings.clear()
		var gen_samples := PackedFloat64Array()
		var last_chunk: ChunkMeshData = null
		for coord in coords:
			var t := Time.get_ticks_usec()
			last_chunk = chunk_generator.generate_chunk(coord, chunk_size, lod)
			gen_samples.append((Time.get_ticks_usec() - t) / 1000.0)
		results.append(BenchmarkResult.new(
			"chunk_gen_lod%d" % lod, "chunk_generation", "ms", gen_samples, meta
		))
		for substep_name in substep_timings:
			results.append(BenchmarkResult.new(
				"chunk_substep_%s_lod%d" % [substep_name, lod],
				"chunk_generation", "ms", substep_timings[substep_name], meta
			))
		results.append_array(_benchmark_chunk_mesh(profile, last_chunk, lod, meta))
	results.append_array(_benchmark_cache(config, config_name, definition, profile, coords))
	results.append_array(_benchmark_prop_placement(config, config_name, definition, profile, coords))
	return results

func _benchmark_chunk_mesh(profile: BenchmarkProfile, last_chunk: ChunkMeshData, lod: int, meta: Dictionary) -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	if last_chunk and last_chunk.mesh_data:
		var mb_samples := PackedFloat64Array()
		for _n in profile.iterations:
			var t := Time.get_ticks_usec()
			ArrayMeshBuilder.build_mesh(last_chunk.mesh_data)
			mb_samples.append((Time.get_ticks_usec() - t) / 1000.0)
		results.append(BenchmarkResult.new(
			"array_mesh_build_lod%d" % lod, "chunk_generation", "ms", mb_samples, meta
		))
		meta["actual_vertices"] = last_chunk.mesh_data.get_vertex_count()
		meta["actual_triangles"] = last_chunk.mesh_data.get_triangle_count()
		results.append(BenchmarkResult.new(
			"vertex_count_lod%d" % lod, "chunk_generation", "count",
			PackedFloat64Array([float(last_chunk.mesh_data.get_vertex_count())]), meta
		))
		results.append(BenchmarkResult.new(
			"triangle_count_lod%d" % lod, "chunk_generation", "count",
			PackedFloat64Array([float(last_chunk.mesh_data.get_triangle_count())]), meta
		))
	return results

func _benchmark_cache(
	config: TerrainConfigurationV2,
	config_name: String,
	definition: TerrainDefinition,
	_profile: BenchmarkProfile,
	coords: Array[Vector2i]
) -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	var meta := {"config_name": config_name, "cache_size_mb": config.cache_size_mb}
	print("[Cache] Measuring hit/miss performance...")
	var service := ChunkGenerationService.new(
		definition, config.base_chunk_resolution, config.cache_size_mb, config.use_gpu_mesh_generation
	)
	var cold_samples := PackedFloat64Array()
	for coord in coords:
		var t := Time.get_ticks_usec()
		service.get_or_generate_chunk(coord, config.chunk_size, 0)
		cold_samples.append((Time.get_ticks_usec() - t) / 1000.0)
	results.append(BenchmarkResult.new("cache_cold_gen", "cache", "ms", cold_samples, meta))
	var warm_samples := PackedFloat64Array()
	for coord in coords:
		var t := Time.get_ticks_usec()
		service.get_or_generate_chunk(coord, config.chunk_size, 0)
		warm_samples.append((Time.get_ticks_usec() - t) / 1000.0)
	results.append(BenchmarkResult.new("cache_warm_hit", "cache", "ms", warm_samples, meta))
	var stats := service.get_cache_stats()
	if stats.has("memory_usage_mb"):
		results.append(BenchmarkResult.new(
			"cache_memory", "cache", "MB",
			PackedFloat64Array([stats["memory_usage_mb"]]), meta
		))
	return results

## Benchmark runtime cost of prop placement per rule per chunk.
## Exercises PropPlacementRule.build_for_chunk() — the same code path
## used by ChunkFeatureManager when a chunk loads at runtime.
func _benchmark_prop_placement(
	config: TerrainConfigurationV2,
	config_name: String,
	definition: TerrainDefinition,
	profile: BenchmarkProfile,
	coords: Array[Vector2i]
) -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	if config.prop_placement_rules.is_empty():
		return results
	print("[Props] Measuring prop placement runtime...")
	var gen_strategy := CpuChunkGenerationStrategy.new()
	for rule in config.prop_placement_rules:
		if not rule or not rule is PropPlacementRule:
			continue
		var prop_rule: PropPlacementRule = rule
		var meta := {
			"config_name": config_name,
			"rule_id": prop_rule.rule_id,
			"density": prop_rule.density,
			"constraint_count": prop_rule.constraints.size(),
			"use_multimesh": prop_rule.use_multimesh,
		}
		var placement_samples := PackedFloat64Array()
		var instance_counts := PackedFloat64Array()
		for coord in coords:
			var chunk_bounds := gen_strategy.calculate_chunk_bounds(
				definition, coord, config.chunk_size
			)
			var terrain_sampler := definition.create_terrain_sampler(chunk_bounds)
			var volumes := definition.get_volumes_for_chunk(chunk_bounds, 0)
			var start_time := Time.get_ticks_usec()
			var placements := prop_rule.build_for_chunk(
				chunk_bounds, terrain_sampler, volumes, definition
			)
			placement_samples.append((Time.get_ticks_usec() - start_time) / 1000.0)
			instance_counts.append(float(placements.size()))
		results.append(BenchmarkResult.new(
			"prop_placement_%s" % prop_rule.rule_id,
			"prop_placement", "ms", placement_samples, meta
		))
		results.append(BenchmarkResult.new(
			"prop_instance_count_%s" % prop_rule.rule_id,
			"prop_placement", "count", instance_counts, meta
		))
	return results

func _collect_render_snapshot() -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	print("[Render] Engine snapshot...")
	var rs := {
		"rs_objects_drawn": RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME,
		"rs_primitives_drawn": RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME,
		"rs_draw_calls": RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME,
		"rs_video_mem": RenderingServer.RENDERING_INFO_VIDEO_MEM_USED,
		"rs_texture_mem": RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED,
		"rs_buffer_mem": RenderingServer.RENDERING_INFO_BUFFER_MEM_USED,
	}
	for name in rs:
		var val: int = RenderingServer.get_rendering_info(rs[name])
		var u := "MB" if name.contains("mem") else "count"
		var dv := (val / BYTES_PER_MB) if name.contains("mem") else float(val)
		results.append(BenchmarkResult.new(name, "render_snapshot", u, PackedFloat64Array([dv])))
	var pm := {
		"perf_fps":           [Performance.TIME_FPS, "fps", false],
		"perf_frame_time":    [Performance.TIME_PROCESS, "ms", true],
		"perf_physics_time":  [Performance.TIME_PHYSICS_PROCESS, "ms", true],
		"perf_object_count":  [Performance.OBJECT_COUNT, "count", false],
		"perf_node_count":    [Performance.OBJECT_NODE_COUNT, "count", false],
		"perf_orphan_nodes":  [Performance.OBJECT_ORPHAN_NODE_COUNT, "count", false],
		"perf_resource_count":[Performance.OBJECT_RESOURCE_COUNT, "count", false],
	}
	for name in pm:
		var arr: Array = pm[name]
		var val: float = Performance.get_monitor(arr[0])
		if arr[2]: val *= MS_PER_SEC
		results.append(BenchmarkResult.new(name, "render_snapshot", arr[1], PackedFloat64Array([val])))
	return results

func _generate_definition_quiet(config: TerrainConfigurationV2) -> TerrainDefinition:
	var gen := TerrainDefinitionGenerator.new()
	gen.verbose = false
	var context := _make_context(config)
	var definition := gen.generate(
		config.heightmap_source, config.terrain_size, config.height_scale,
		config.modifier_stages, config.generation_seed,
		context, config.prop_placement_rules
	)
	context.dispose()
	return definition

func _make_context(config: TerrainConfigurationV2) -> ProcessingContext:
	var heightmap_type := ProcessingContext.ProcessorType.GPU if config.use_gpu_heightmap \
		else ProcessingContext.ProcessorType.CPU
	var mesh_type := ProcessingContext.ProcessorType.GPU if config.use_gpu_mesh_generation \
		else ProcessingContext.ProcessorType.CPU
	return ProcessingContext.new(
		config.terrain_size.x, heightmap_type, mesh_type, config.generation_seed
	)

## Spiral outward from terrain center to collect chunk coordinates.
func _spiral_chunk_coords(config: TerrainConfigurationV2, count: int) -> Array[Vector2i]:
	var chunk_size := config.chunk_size
	var terrain_size := config.terrain_size
	var nx := int(terrain_size.x / chunk_size.x)
	var nz := int(terrain_size.y / chunk_size.y)
	var cx := nx / 2
	var cz := nz / 2
	var coords: Array[Vector2i] = []
	var radius := 0
	while coords.size() < count:
		if radius == 0:
			coords.append(Vector2i(cx, cz))
			radius += 1
			continue
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dz) != radius:
					continue
				var c := Vector2i(cx + dx, cz + dz)
				if c.x >= 0 and c.x < nx and c.y >= 0 and c.y < nz:
					coords.append(c)
					if coords.size() >= count:
						return coords
		radius += 1
		if radius > maxi(nx, nz):
			break
	return coords

func _estimate_max_loaded_chunks(config: TerrainConfigurationV2) -> int:
	return config.load_strategy.get_max_loaded_chunks()

## Count triangles in a PackedScene by instantiating once and walking the mesh tree.
func _count_scene_triangles(scene: PackedScene) -> int:
	if not scene:
		return 0
	var instance := scene.instantiate()
	if not instance:
		return 0
	var count := _sum_mesh_triangles(instance)
	instance.free()
	return count

func _sum_mesh_triangles(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node
		if mesh.mesh:
			for surface_count in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface_count)
				if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
					total += arrays[Mesh.ARRAY_INDEX].size() / VERTS_PER_TRIANGLE
				elif arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					total += arrays[Mesh.ARRAY_VERTEX].size() / VERTS_PER_TRIANGLE
	for child in node.get_children():
		total += _sum_mesh_triangles(child)
	return total

func _print_header(profile: BenchmarkProfile) -> void:
	print("")
	print("TERRAIN BENCHMARK")
	print("Configs: %d | Iters: %d | Chunks: %d%s" % [
		profile.configurations.size(), profile.iterations, profile.chunks_to_generate,
		(" | Tag: %s" % profile.run_tag) if profile.run_tag != "" else ""
	])

func _save_report(report: BenchmarkReport, profile: BenchmarkProfile) -> void:
	var time_stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var tag := ("_%s" % profile.run_tag) if profile.run_tag != "" else ""
	var base := "%s%s%s" % [profile.output_dir, time_stamp, tag]
	report.save_csv("%s.csv" % base, profile.export_raw_samples)
	report.save_json("%s.json" % base)
