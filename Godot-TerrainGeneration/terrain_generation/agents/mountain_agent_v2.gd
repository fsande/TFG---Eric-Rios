## @brief Agent that creates mountain ridges (new architecture).
##
## @details Generates height deltas for the mountain base and optionally
## overhang volumes for cliff formations. Uses token-based path following.
@tool
class_name MountainAgentV2 extends TerrainModifierAgent

# Small typed data class for path points to replace Dictionary usage
class MountainPoint:
	var position: Vector2
	var direction: Vector2
	var width_mult: float
	var length_mult: float
	var token_index: int

	func _init(pos := Vector2(), dir := Vector2(), 
				width_m: float = 1.0, length_m: float = 1.0, 
				idx := 0) -> void:
		position = pos
		direction = dir
		width_mult = width_m
		length_mult = length_m
		token_index = idx

@export var config: MountainAgentConfig = MountainAgentConfig.new()

func _init() -> void:
	agent_name = "Mountain V2"
	tokens = 25

func get_modifier_type() -> ModifierType:
	if config.enable_overhangs:
		return ModifierType.COMPOSITE
	return ModifierType.HEIGHT_DELTA

func get_agent_type() -> String:
	return "MountainV2"

func validate(context: TerrainGenerationContext) -> bool:
	if tokens <= 0:
		push_error("MountainAgentV2: tokens must be positive")
		return false
	if config.step_distance <= 0:
		push_error("MountainAgentV2: step_distance must be positive")
		return false
	return true

func generate(context: TerrainGenerationContext) -> TerrainModifierResult:
	var start_time := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Calculating mountain path")
	var rng := RandomNumberGenerator.new()
	rng.seed = config.direction_seed if config.direction_seed != 0 else context.generation_seed
	var path_points := _calculate_path(rng)
	progress_updated.emit(0.2, "Calculating mountain bounds")
	var bounds := _calculate_bounds(path_points)
	progress_updated.emit(0.3, "Creating height delta texture")
	var delta := HeightDeltaMap.create(config.delta_resolution, config.delta_resolution, bounds)
	delta.blend_strategy = AdditiveBlendStrategy.new()
	delta.intensity = 1.0
	delta.edge_falloff = 0.1
	delta.source_agent = get_display_name()
	progress_updated.emit(0.4, "Generating mountain ridge")
	for i in range(path_points.size()):
		var point: MountainPoint = path_points[i]
		var position: Vector2 = point.position
		var direction: Vector2 = point.direction
		_apply_wedge_to_delta(delta, bounds, position, direction, point.width_mult, point.length_mult)
		if i % 5 == 0:
			progress_updated.emit(0.4 + 0.4 * float(i) / float(path_points.size()),
				"Processing token %d/%d" % [i, path_points.size()])
	var result := TerrainModifierResult.create_success()
	result.add_height_delta(delta)
	if config.enable_overhangs:
		progress_updated.emit(0.85, "Generating overhangs")
		var overhangs := _generate_overhangs(path_points, context, rng)
		for overhang in overhangs:
			result.add_volume(overhang)
	progress_updated.emit(1.0, "Complete")
	var elapsed := Time.get_ticks_msec() - start_time
	result.elapsed_time_ms = elapsed
	result.error_message = "Created mountain ridge with %d tokens" % tokens
	if config.enable_overhangs:
		result.error_message += ", %d overhangs" % result.volumes.size()
	return result

## Calculate the path points for the mountain ridge.
func _calculate_path(rng: RandomNumberGenerator) -> Array[MountainPoint]:
	var path: Array[MountainPoint] = []
	var initial_direction_rad := deg_to_rad(config.initial_direction_degrees)
	var original_direction := Vector2(sin(initial_direction_rad), cos(initial_direction_rad)).normalized()
	var current_direction := original_direction
	var current_position := config.start_position
	for i in range(tokens):
		path.append(MountainPoint.new(current_position, current_direction,
			1.0 + rng.randf_range(-config.width_variation, config.width_variation),
			1.0 + rng.randf_range(-config.length_variation, config.length_variation),
			i))
		current_position += current_direction * config.step_distance
		if config.direction_change_interval > 0 and (i + 1) % config.direction_change_interval == 0:
			var angle_offset := rng.randf_range(-config.direction_change_angle, config.direction_change_angle)
			var new_angle := atan2(original_direction.x, original_direction.y) + deg_to_rad(angle_offset)
			current_direction = Vector2(sin(new_angle), cos(new_angle)).normalized()
	return path

## Calculate bounds that encompass the entire mountain.
## Calculate bounds that encompass the entire mountain.
func _calculate_bounds(path_points: Array[MountainPoint]) -> AABB:
	if path_points.is_empty():
		return AABB()
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	var max_height := 0.0
	for point in path_points:
		var extent := maxf(config.wedge_width * point.width_mult, config.wedge_length * point.length_mult) * 0.5
		min_pos.x = minf(min_pos.x, point.position.x - extent)
		min_pos.y = minf(min_pos.y, point.position.y - extent)
		max_pos.x = maxf(max_pos.x, point.position.x + extent)
		max_pos.y = maxf(max_pos.y, point.position.y + extent)
		max_height = maxf(max_height, config.elevation_height * config.height_variation)
	return AABB(
		Vector3(min_pos.x, 0, min_pos.y),
		Vector3(max_pos.x - min_pos.x, max_height * 2, max_pos.y - min_pos.y)
	)
	
## Apply a single wedge elevation to the delta texture.
func _apply_wedge_to_delta(
	delta: HeightDeltaMap,
	bounds: AABB,
	position: Vector2,
	direction: Vector2,
	width_mult: float = 1.0,
	length_mult: float = 1.0
) -> void:
	var perpendicular := Vector2(-direction.y, direction.x)
	for y in range(config.delta_resolution):
		for x in range(config.delta_resolution):
			var u := float(x) / float(config.delta_resolution - 1)
			var v := float(y) / float(config.delta_resolution - 1)
			var world_x := bounds.position.x + u * bounds.size.x
			var world_z := bounds.position.z + v * bounds.size.z
			var pixel_pos := Vector2(world_x, world_z)
			var relative := pixel_pos - position
			var dist_along := relative.dot(direction)
			var dist_perp: float = abs(relative.dot(perpendicular))
			var height_mult := 1.0 + config.height_variation_noise.get_noise_2d(world_x * 0.1, world_z * 0.1) * config.height_variation
			var actual_width := config.wedge_width * width_mult
			var actual_height := config.elevation_height * height_mult
			var actual_length := config.wedge_length * length_mult
			if abs(dist_along) > actual_length or dist_perp > actual_width:
				continue
			var normalized_along: float = abs(dist_along) / config.wedge_length
			var normalized_perp: float = dist_perp / actual_width
			var falloff_t := sqrt(normalized_along * normalized_along + normalized_perp * normalized_perp)
			var strength := pow(1.0 - falloff_t, config.elevation_falloff + 1.0)
			var delta_value := actual_height * strength
			var current := delta.sample_at(pixel_pos)
			delta.set_at_uv(Vector2(u, v), maxf(current, delta_value))

## Generate overhang volumes for steep sections.
## TODO: This works terribly and needs complete rewrite
func _generate_overhangs(
	path_points: Array[MountainPoint],
	context: TerrainGenerationContext,
	rng: RandomNumberGenerator
) -> Array[OverhangVolumeDefinition]:
	return []
	#var overhangs: Array[OverhangVolumeDefinition] = []
	#for point_data in path_points:
		#if rng.randf() > config.overhang_probability:
			#continue
		#var position := point_data.position
		#var direction := point_data.direction
		#var height_mult := point_data.height_mult
		#var side := 1.0 if rng.randf() > 0.5 else -1.0
		#var perpendicular := Vector2(-direction.y, direction.x) * side
		#var overhang := OverhangVolumeDefinition.new()
		#var base_height := context.get_scaled_height_at(position)
		#var ridge_height := config.elevation_height * height_mult
		#overhang.attachment_point = Vector3(
			#position.x + perpendicular.x * config.wedge_width * 0.8,
			#base_height + ridge_height * 0.7,
			#position.y + perpendicular.y * config.wedge_width * 0.8
		#)
		#overhang.overhang_direction = Vector3(
			#perpendicular.x,
			#-0.2,
			#perpendicular.y
		#).normalized()
		#overhang.extent = config.overhang_extent * rng.randf_range(0.7, 1.3)
		#overhang.width = config.wedge_length * rng.randf_range(0.5, 1.0)
		#overhang.thickness = 1.5 * rng.randf_range(0.8, 1.2)
		#overhang.noise_strength = 0.3
		#overhang.noise_seed = rng.randi()
		#overhang.update_bounds()
		#overhangs.append(overhang)
	#return overhangs
#
