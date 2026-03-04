## @brief Unified terrain benchmark that runs the real generation pipeline.
##
## @details Replaces the old suite-based architecture. Consumes real
## TerrainConfigurationV2 resources through BenchmarkProfile2.
## Measures pipeline generation, chunk generation at all LOD levels,
## cache behavior, and collects static triangle budgets — all derived
## from the actual resources your scene uses.
##
## Usage:
##   var benchmark := TerrainBenchmark2.new()
##   var report := benchmark.run(profile)
class_name TerrainBenchmark extends RefCounted

signal benchmark_started()
signal config_started(config_name: String, index: int, total: int)
signal config_completed(config_name: String, result_count: int, elapsed_ms: float)
signal benchmark_completed(report: BenchmarkReport)

func run(profile: BenchmarkProfile) -> BenchmarkReport:
	assert(not profile.configurations.is_empty(), "TerrainBenchmark: Profile has no configurations")
	_print_header(profile)
	benchmark_started.emit()
	var report := BenchmarkReport.new()
	var total_start := Time.get_ticks_usec()
	for i in range(profile.configurations.size()):
		var config := profile.configurations[i]
		var config_name := profile.get_config_name(i)
		print("║")
		print("║ ━━━ Configuration %d/%d: %s ━━━" % [i + 1, profile.configurations.size(), config_name])
		config_started.emit(config_name, i, profile.configurations.size())
		var config_start := Time.get_ticks_usec()
		var config_results := _benchmark_single_config(config, config_name, profile)
		var config_elapsed := (Time.get_ticks_usec() - config_start) / 1000.0
		report.add_results(config_results)
		config_completed.emit(config_name, config_results.size(), config_elapsed)
		print("║  -> %d results in %.1f ms" % [config_results.size(), config_elapsed])
	report.add_results(_collect_render_snapshot())
	var total_elapsed := (Time.get_ticks_usec() - total_start) / 1000.0
	print("║")
	print("║ Total: %d results in %.1f ms" % [report.get_result_count(), total_elapsed])
	print("╚══════════════════════════════════════════════════════════════╝")
	report.print_report()
	_save_report(report, profile)
	benchmark_completed.emit(report)
	return report


func _benchmark_single_config(
	config: TerrainConfigurationV2,
	config_name: String,
	profile: BenchmarkProfile
) -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	results.append_array(_benchmark_pipeline(config, config_name, profile))
	var definition := _generate_definition_quiet(config)
	if not definition:
		push_error("TerrainBenchmark2: Failed to generate definition for %s" % config_name)
		return results
	results.append_array(_benchmark_chunks(config, config_name, definition, profile))
	results.append_array(_collect_static_budget(config, config_name))
	return results

func _benchmark_pipeline(
	config: TerrainConfigurationV2,
	config_name: String,
	profile: BenchmarkProfile
) -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	var meta := {"config_name": config_name, "terrain_size": config.terrain_size.x}
	print("║   [Pipeline] Measuring full pipeline generation...")
	for _w in profile.warmup_iterations:
		_generate_definition_quiet(config)

	# ── Timed iterations ──────────────────────────────────────────
	# We collect per-stage timing from TerrainDefinitionGenerator.stage_completed.
	# That signal already exists and fires with (stage_name, elapsed_ms).
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
		var ctx := _make_context(config)
		var t := Time.get_ticks_usec()
		generator.generate(
			config.heightmap_source, config.terrain_size, config.height_scale,
			config.modifier_stages, config.generation_seed,
			ctx, config.prop_placement_rules
		)
		total_samples.append((Time.get_ticks_usec() - t) / 1000.0)
		ctx.dispose()
		for sn in per_stage:
			if not stage_timings.has(sn):
				stage_timings[sn] = PackedFloat64Array()
			stage_timings[sn].append(per_stage[sn])
	results.append(BenchmarkResult.new("pipeline_total", "pipeline", "ms", total_samples, meta))
	for stage_name in stage_timings:
		var sm := meta.duplicate()
		sm["stage"] = stage_name
		results.append(BenchmarkResult.new(
			"pipeline_stage_%s" % stage_name, "pipeline", "ms", stage_timings[stage_name], sm
		))
	var hm_samples := PackedFloat64Array()
	for _i in profile.iterations:
		var ctx := _make_context(config)
		var t := Time.get_ticks_usec()
		config.heightmap_source.generate(ctx)
		hm_samples.append((Time.get_ticks_usec() - t) / 1000.0)
		ctx.dispose()
	results.append(BenchmarkResult.new("heightmap_generation", "pipeline", "ms", hm_samples, meta))
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
	print("║   [Chunks] %d chunks × LODs %s ..." % [coords.size(), str(lod_levels)])
	var strategy := CpuChunkGenerationStrategy.new()
	for lod in lod_levels:
		var eff_res := strategy.calculate_resolution_for_lod(config.base_chunk_resolution, lod)
		var meta := {
			"config_name": config_name, "lod_level": lod,
			"base_resolution": config.base_chunk_resolution,
			"effective_resolution": eff_res,
			"chunk_size": chunk_size.x,
		}
		var gen := ChunkGenerator.new(definition, config.base_chunk_resolution, false)
		for _w in profile.warmup_iterations:
			gen.generate_chunk(coords[0], chunk_size, lod)
		# ── Full chunk generation timing ──────────────────────────
		# This exercises the real CpuChunkGenerationStrategy:
		#   height grid → mesh build → normals → tangents
		# NOTE: CpuChunkGenerationStrategy.generate_chunk does NOT emit
		# per-substep signals today. If you want per-substep timing
		# (height_grid, mesh_build, normals, tangents) without duplicating
		# code, add these signals to CpuChunkGenerationStrategy:
		#
		#   signal substep_completed(substep_name: String, elapsed_ms: float)
		#
		# Emit it after _generate_height_grid, _build_mesh_from_height_grid,
		# MeshNormalCalculator, MeshTangentCalculator calls inside generate_chunk.
		# The benchmark would then connect to it just like pipeline stage_completed.
		var gen_samples := PackedFloat64Array()
		var last_chunk: ChunkMeshData = null
		for coord in coords:
			var t := Time.get_ticks_usec()
			last_chunk = gen.generate_chunk(coord, chunk_size, lod)
			gen_samples.append((Time.get_ticks_usec() - t) / 1000.0)
		results.append(BenchmarkResult.new(
			"chunk_gen_lod%d" % lod, "chunk_generation", "ms", gen_samples, meta
		))
		# ── ArrayMesh build (main-thread cost per chunk load) ─────
		# This is called inside TerrainPresenterV2._instantiate_chunk.
		# We time it separately because it runs on the main thread even
		# when chunk generation itself is async.
		if last_chunk and last_chunk.mesh_data:
			var mb_samples := PackedFloat64Array()
			for _n in profile.iterations:
				# Reset cached data to force full rebuild each iteration
				var md := last_chunk.mesh_data
				var saved_normals := md.cached_normals
				var saved_tangents := md.cached_tangents
				md.cached_normals = PackedVector3Array()
				md.cached_tangents = PackedVector4Array()
				var t := Time.get_ticks_usec()
				ArrayMeshBuilder.build_mesh(md)
				mb_samples.append((Time.get_ticks_usec() - t) / 1000.0)
				md.cached_normals = saved_normals
				md.cached_tangents = saved_tangents
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
	results.append_array(_benchmark_cache(config, config_name, definition, profile, coords))
	return results

func _benchmark_cache(
	config: TerrainConfigurationV2,
	config_name: String,
	definition: TerrainDefinition,
	profile: BenchmarkProfile,
	coords: Array[Vector2i]
) -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	var meta := {"config_name": config_name, "cache_size_mb": config.cache_size_mb}
	print("║   [Cache] Measuring hit/miss performance...")
	var service := ChunkGenerationService.new(
		definition, config.base_chunk_resolution, config.cache_size_mb, false
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

func _collect_static_budget(
	config: TerrainConfigurationV2,
	config_name: String
) -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	var meta := {"config_name": config_name}
	print("║   [Static] Computing triangle budgets from config resources...")
	var res := config.base_chunk_resolution
	var tris_per_chunk := (res - 1) * (res - 1) * 2
	var max_chunks := _estimate_max_loaded_chunks(config)
	var t_meta := meta.duplicate()
	t_meta["resolution"] = res
	t_meta["tris_per_chunk"] = tris_per_chunk
	t_meta["max_chunks"] = max_chunks
	var terrain_total := tris_per_chunk * max_chunks
	results.append(BenchmarkResult.new(
		"budget_terrain", "static_analysis", "triangles",
		PackedFloat64Array([float(terrain_total)]), t_meta
	))
	var sea_total := 0
	if config.enable_sea:
		var sd := config.sea_subdivisions
		sea_total = sd * sd * 2
		var s_meta := meta.duplicate()
		s_meta["subdivisions"] = sd
		s_meta["sea_vertices"] = (sd + 1) * (sd + 1)
		results.append(BenchmarkResult.new(
			"budget_sea", "static_analysis", "triangles",
			PackedFloat64Array([float(sea_total)]), s_meta
		))
	var chunk_area := config.chunk_size.x * config.chunk_size.y
	var prop_total := 0
	for rule in config.prop_placement_rules:
		if not rule or not rule is PropPlacementRule:
			continue
		var prop_rule: PropPlacementRule = rule
		var tris_per_instance := _count_scene_triangles(prop_rule.prop_scene)
		var instances_per_chunk := int(chunk_area * prop_rule.density)
		var rule_total := tris_per_instance * instances_per_chunk * max_chunks
		var r_meta := meta.duplicate()
		r_meta["rule_id"] = prop_rule.rule_id
		r_meta["density"] = prop_rule.density
		r_meta["tris_per_instance"] = tris_per_instance
		r_meta["instances_per_chunk"] = instances_per_chunk
		r_meta["use_multimesh"] = prop_rule.use_multimesh
		results.append(BenchmarkResult.new(
			"budget_prop_%s" % prop_rule.rule_id, "static_analysis", "triangles",
			PackedFloat64Array([float(rule_total)]), r_meta
		))
		prop_total += rule_total
	results.append(BenchmarkResult.new(
		"budget_props_total", "static_analysis", "triangles",
		PackedFloat64Array([float(prop_total)]), meta
	))
	var grand := terrain_total + sea_total + prop_total
	results.append(BenchmarkResult.new(
		"budget_grand_total", "static_analysis", "triangles",
		PackedFloat64Array([float(grand)]), meta
	))
	if grand > 0:
		results.append(BenchmarkResult.new(
			"budget_pct_terrain", "static_analysis", "%",
			PackedFloat64Array([100.0 * terrain_total / grand]), meta
		))
		results.append(BenchmarkResult.new(
			"budget_pct_sea", "static_analysis", "%",
			PackedFloat64Array([100.0 * sea_total / grand]), meta
		))
		results.append(BenchmarkResult.new(
			"budget_pct_props", "static_analysis", "%",
			PackedFloat64Array([100.0 * prop_total / grand]), meta
		))
	return results

func _collect_render_snapshot() -> Array[BenchmarkResult]:
	var results: Array[BenchmarkResult] = []
	print("║")
	print("║   [Render] Engine snapshot...")
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
		var dv := (val / 1048576.0) if name.contains("mem") else float(val)
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
		if arr[2]: val *= 1000.0
		results.append(BenchmarkResult.new(name, "render_snapshot", arr[1], PackedFloat64Array([val])))
	return results

func _generate_definition_quiet(config: TerrainConfigurationV2) -> TerrainDefinition:
	var gen := TerrainDefinitionGenerator.new()
	gen.verbose = false
	var ctx := _make_context(config)
	var definition := gen.generate(
		config.heightmap_source, config.terrain_size, config.height_scale,
		config.modifier_stages, config.generation_seed,
		ctx, config.prop_placement_rules
	)
	ctx.dispose()
	return definition

func _make_context(config: TerrainConfigurationV2) -> ProcessingContext:
	return ProcessingContext.new(
		config.terrain_size.x,
		ProcessingContext.ProcessorType.CPU,
		ProcessingContext.ProcessorType.CPU,
		config.generation_seed
	)

## Spiral outward from terrain center to collect chunk coordinates.
func _spiral_chunk_coords(config: TerrainConfigurationV2, count: int) -> Array[Vector2i]:
	var cs := config.chunk_size
	var ts := config.terrain_size
	var nx := int(ts.x / cs.x)
	var nz := int(ts.y / cs.y)
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
	if config.load_strategy is GridLoadStrategyV2:
		var grid: GridLoadStrategyV2 = config.load_strategy
		var d := 2 * grid.load_radius + 1
		return d * d
	# TODO: Add get_max_loaded_chunks() to ChunkLoadStrategyV2 base class
	# so custom strategies can report their expected count without instanceof checks.
	return 25

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
		var mi: MeshInstance3D = node
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(si)
				if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
					total += arrays[Mesh.ARRAY_INDEX].size() / 3
				elif arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					total += arrays[Mesh.ARRAY_VERTEX].size() / 3
	for child in node.get_children():
		total += _sum_mesh_triangles(child)
	return total

func _print_header(profile: BenchmarkProfile) -> void:
	print("")
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║  TERRAIN BENCHMARK                                           ║")
	print("║  Configs: %d | Iters: %d | Chunks: %d%s" % [
		profile.configurations.size(), profile.iterations, profile.chunks_to_generate,
		(" | Tag: %s" % profile.run_tag) if profile.run_tag != "" else ""
	])
	print("╠══════════════════════════════════════════════════════════════╣")

func _save_report(report: BenchmarkReport, profile: BenchmarkProfile) -> void:
	var ts := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var tag := ("_%s" % profile.run_tag) if profile.run_tag != "" else ""
	var base := "%s%s%s" % [profile.output_dir, ts, tag]
	report.save_csv("%s.csv" % base, profile.export_raw_samples)
	report.save_json("%s.json" % base)
