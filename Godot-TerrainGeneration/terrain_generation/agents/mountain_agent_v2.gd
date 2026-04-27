## @brief Agent that creates mountain ridges (new architecture).
##
## @details Generates height deltas for the mountain base using token-based
## path following. Overhang generation has been moved to OverhangAgent,
## which should run in a later pipeline stage after this agent's delta has
## been committed to TerrainDefinition.
@tool
class_name MountainAgentV2 extends TerrainModifierAgent

@export var config: MountainAgentConfig = MountainAgentConfig.new()
@export var save_deltas_images: bool = false
@export var save_path: String = "mountain_deltas.png"

func _init() -> void:
	agent_name = "Mountain V2"
	tokens = 25

func get_modifier_type() -> ModifierType:
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
	delta.zone_tags = [&"mountain"]
	var accum := PackedFloat32Array()
	accum.resize(config.delta_resolution * config.delta_resolution)
	accum.fill(0.0)
	progress_updated.emit(0.4, "Generating mountain ridge")
	for i in range(path_points.size()):
		var point: MountainPoint = path_points[i]
		_apply_wedge_to_accum(accum, bounds, point.position, point.direction, point.width_mult, point.length_mult, config.delta_resolution)
		if i % 5 == 0:
			progress_updated.emit(0.4 + 0.4 * float(i) / float(path_points.size()), "Processing token %d/%d" % [i, path_points.size()])
	for y in range(config.delta_resolution):
		for x in range(config.delta_resolution):
			delta.set_at_uv(
				Vector2(float(x) / float(config.delta_resolution - 1), float(y) / float(config.delta_resolution - 1)),
				accum[y * config.delta_resolution + x]
			)
	var result := TerrainModifierResult.create_success()
	result.add_height_delta(delta)
	progress_updated.emit(1.0, "Complete")
	var elapsed := Time.get_ticks_msec() - start_time
	result.elapsed_time_ms = elapsed
	result.error_message = "Created mountain ridge with %d tokens" % tokens
	if save_deltas_images:
		result.export_deltas(save_path)
	return result

## Calculate the path points for the mountain ridge.
func _calculate_path(rng: RandomNumberGenerator) -> Array[MountainPoint]:
	var path: Array[MountainPoint] = []
	var initial_direction_rad := deg_to_rad(config.initial_direction_degrees)
	var original_direction := Vector2(sin(initial_direction_rad), cos(initial_direction_rad)).normalized()
	var current_direction := original_direction
	var current_position := config.start_position
	for i in range(tokens):
		path.append(MountainPoint.new(
			current_position, current_direction,
			1.0 + rng.randf_range(-config.width_variation, config.width_variation),
			1.0 + rng.randf_range(-config.length_variation, config.length_variation),
			i
		))
		current_position += current_direction * config.step_distance
		if config.direction_change_interval > 0 and (i + 1) % config.direction_change_interval == 0:
			var angle_offset := rng.randf_range(-config.direction_change_angle, config.direction_change_angle)
			var new_angle := atan2(original_direction.x, original_direction.y) + deg_to_rad(angle_offset)
			current_direction = Vector2(sin(new_angle), cos(new_angle)).normalized()
	return path

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

## Apply a single wedge elevation to the accumulation buffer.
func _apply_wedge_to_accum(
	accum: PackedFloat32Array,
	bounds: AABB,
	position: Vector2,
	direction: Vector2,
	width_mult: float,
	length_mult: float,
	res: int
) -> void:
	var perpendicular := Vector2(-direction.y, direction.x)
	var actual_width := config.wedge_width * width_mult
	var actual_length := config.wedge_length * length_mult
	for y in range(res):
		for x in range(res):
			var u := float(x) / float(res - 1)
			var v := float(y) / float(res - 1)
			var world_x := bounds.position.x + u * bounds.size.x
			var world_z := bounds.position.z + v * bounds.size.z
			var relative := Vector2(world_x, world_z) - position
			var dist_along := relative.dot(direction)
			var dist_perp: float = abs(relative.dot(perpendicular))
			if abs(dist_along) > actual_length or dist_perp > actual_width:
				continue
			var falloff_t := clampf(
				sqrt(pow(abs(dist_along) / actual_length, 2.0) + pow(dist_perp / actual_width, 2.0)),
				0.0, 1.0
			)
			var noise_h_mult := 1.0 + config.height_variation_noise.get_noise_2d(
				world_x * 0.1, world_z * 0.1
			) * config.height_variation
			var strength := pow(1.0 - falloff_t, config.elevation_falloff + 1.0)
			accum[y * res + x] += config.elevation_height * noise_h_mult * strength
