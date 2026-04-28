## @brief Agent that places overhang volumes on steep cliff faces.
##
## @details Runs in a pipeline stage AFTER height agents have committed
## their deltas. This means context.calculate_slope_at() and
## context.get_scaled_height_at() already reflect mountains, riverbeds,
## and any other prior modifications — the slope query is always accurate.
##
## Pipeline setup example:
## Stage 0 (SequentialModifierStage): MountainAgentV2
## Stage 1 (SequentialModifierStage): OverhangAgent ← runs after deltas committed
@tool
class_name OverhangAgent extends TerrainModifierAgent

@export var config: OverhangAgentConfig = OverhangAgentConfig.new()

func _init() -> void:
	agent_name = "Overhang"

func get_modifier_type() -> ModifierType:
	return ModifierType.VOLUME_ADDITIVE

func get_agent_type() -> String:
	return "Overhang"

func validate(context: TerrainGenerationContext) -> bool:
	if not enabled:
		return false
	if config.extent_min > config.extent_max:
		push_error("OverhangAgent: extent_min must be <= extent_max")
		return false
	if config.width_min > config.width_max:
		push_error("OverhangAgent: width_min must be <= width_max")
		return false
	if config.thickness_min > config.thickness_max:
		push_error("OverhangAgent: thickness_min must be <= thickness_max")
		return false
	return true

func generate(context: TerrainGenerationContext) -> TerrainModifierResult:
	var start_time := Time.get_ticks_msec()
	var result := TerrainModifierResult.create_success()
	var rng := RandomNumberGenerator.new()
	rng.seed = config.placement_seed if config.placement_seed != 0 else context.generation_seed
	progress_updated.emit(0.0, "Collecting search bounds")
	var search_bounds := _collect_search_bounds(context)
	if search_bounds.is_empty():
		result.elapsed_time_ms = Time.get_ticks_msec() - start_time
		result.error_message = "No search area found (check zone_tag or search_mode)"
		return result
	progress_updated.emit(0.1, "Sampling candidate positions (%d bounds regions)" % search_bounds.size())
	var candidates := _sample_candidates(search_bounds, context, rng)
	if candidates.is_empty():
		result.elapsed_time_ms = Time.get_ticks_msec() - start_time
		result.error_message = "No steep-enough positions found (min_slope_degrees=%.1f)" % config.min_slope_degrees
		return result
	progress_updated.emit(0.5, "Building overhangs from %d candidates" % candidates.size())
	var overhangs_created := 0
	for i in range(candidates.size()):
		if overhangs_created >= config.max_overhangs:
			break
		if rng.randf() > config.overhang_probability:
			continue
		var candidate: CandidatePoint = candidates[i]
		var overhang := _build_overhang(candidate, context, rng)
		if overhang:
			result.add_volume(overhang)
			overhangs_created += 1
		if i % 10 == 0:
			progress_updated.emit(
				0.5 + 0.45 * float(i) / float(candidates.size()),
				"Processing candidate %d/%d" % [i, candidates.size()]
			)
	progress_updated.emit(1.0, "Complete")
	result.elapsed_time_ms = Time.get_ticks_msec() - start_time
	result.error_message = "Created %d overhangs from %d candidates" % [overhangs_created, candidates.size()]
	return result

## Collect the AABB(s) to search for steep slopes.
func _collect_search_bounds(context: TerrainGenerationContext) -> Array[AABB]:
	var bounds: Array[AABB] = []
	var half := context.terrain_size / 2.0
	bounds.append(AABB(
		Vector3(-half.x, 0.0, -half.y),
		Vector3(context.terrain_size.x, context.height_scale * 2.0, context.terrain_size.y)
	))
	return bounds

## Holds a candidate attachment position and the outward-facing cliff normal.
class CandidatePoint:
	var world_pos: Vector2 
	var outward_dir: Vector2 
	var attach_height: float 

	func _init(pos: Vector2, dir: Vector2, height: float) -> void:
		world_pos = pos
		outward_dir = dir
		attach_height = height

## Sample `config.search_grid_resolution` positions distributed across all
## search bounds, keeping those whose slope exceeds min_slope_degrees.
## The sample budget is divided proportionally by each bound's XZ area.
func _sample_candidates(
	search_bounds: Array[AABB],
	context: TerrainGenerationContext,
	rng: RandomNumberGenerator
) -> Array[CandidatePoint]:
	var candidates: Array[CandidatePoint] = []
	var areas: Array[float] = []
	var total_area := 0.0
	for b in search_bounds:
		var a := b.size.x * b.size.z
		areas.append(a)
		total_area += a
	if total_area <= 0.0:
		return candidates
	for region_idx in range(search_bounds.size()):
		var region: AABB = search_bounds[region_idx]
		var region_samples := int(
			float(config.search_grid_resolution) * areas[region_idx] / total_area
		)
		region_samples = maxi(region_samples, 1)
		for _i in range(region_samples):
			var world_pos := Vector2(
				region.position.x + rng.randf() * region.size.x,
				region.position.z + rng.randf() * region.size.z
			)
			var slope := context.calculate_slope_at(world_pos)
			if slope < config.min_slope_degrees:
				continue
			var normal := context.calculate_normal_at(world_pos)
			var outward_xz := Vector2(normal.x, normal.z)
			if outward_xz.length_squared() < 0.0001:
				continue
			outward_xz = outward_xz.normalized()
			var attach_height := context.get_scaled_height_at(world_pos)
			candidates.append(CandidatePoint.new(world_pos, outward_xz, attach_height))
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: CandidatePoint = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	return candidates

## Build a single OverhangVolumeDefinition from a candidate point.
## Returns null if the candidate produces degenerate geometry.
func _build_overhang(
	candidate: CandidatePoint,
	_context: TerrainGenerationContext,
	rng: RandomNumberGenerator
) -> OverhangVolumeDefinition:
	var extent := rng.randf_range(config.extent_min, config.extent_max)
	var width := rng.randf_range(config.width_min, config.width_max)
	var thickness := rng.randf_range(config.thickness_min, config.thickness_max)
	if extent <= 0.0 or width <= 0.0 or thickness <= 0.0:
		return null
	var attach := Vector3(candidate.world_pos.x, candidate.attach_height, candidate.world_pos.y)
	var overhang_dir := Vector3(
		candidate.outward_dir.x,
		-0.15,
		candidate.outward_dir.y
	).normalized()
	var overhang := OverhangVolumeDefinition.new()
	overhang.attachment_point = attach
	overhang.overhang_direction = overhang_dir
	overhang.extent = extent
	overhang.width = width
	overhang.thickness = thickness
	overhang.cliff_embed_depth = config.cliff_embed_depth
	overhang.noise_strength = config.noise_strength
	overhang.noise_seed = _context.generation_seed + 42
	overhang.lod_min = config.lod_min
	overhang.lod_max = config.lod_max
	overhang.source_agent = get_display_name()
	overhang.update_bounds()
	return overhang
