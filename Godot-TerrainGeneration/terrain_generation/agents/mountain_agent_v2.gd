## @brief Agent that creates mountain ridges (new architecture).
##
## @details Generates height deltas for the mountain base and optionally
## overhang volumes for cliff formations. Uses token-based path following.
@tool
class_name MountainAgentV2 extends TerrainModifierAgent

@export_group("Mountain Parameters")

## Starting position of the mountain ridge (world coordinates)
@export var start_position: Vector2 = Vector2(0, 0)

## Initial direction angle in degrees (0 = North/+Z, 90 = East/+X)
@export_range(0.0, 360.0, 1.0) var initial_direction_degrees: float = 0.0

## Distance to move forward each token
@export var step_distance: float = 5.0

## Wedge width (perpendicular to direction)
@export var wedge_width: float = 20.0

## Wedge length (along direction)
@export var wedge_length: float = 10.0

## Height to elevate at wedge center
@export var elevation_height: float = 15.0

## Falloff strength for wedge elevation
@export_range(0.1, 5.0) var elevation_falloff: float = 1.0

@export_group("Randomization")

## Height variation per wedge
@export_range(0.0, 1.0) var height_variation: float = 0.3

## Width variation per wedge
@export_range(0.0, 1.0) var width_variation: float = 0.2

@export_group("Direction Changes")

## Change direction every N tokens (0 = never)
@export_range(0, 100) var direction_change_interval: int = 10

## Angle change in degrees (+/-)
@export_range(0.0, 90.0) var direction_change_angle: float = 45.0

## Random seed for direction (0 = use context seed)
@export var direction_seed: int = 0

@export_group("Overhangs")

## Enable overhang volume generation
@export var enable_overhangs: bool = false

## Probability of overhang at each token
@export_range(0.0, 1.0) var overhang_probability: float = 0.15

## How far overhangs extend
@export var overhang_extent: float = 4.0

## Minimum slope to create overhang (degrees)
@export_range(0.0, 90.0) var overhang_min_slope: float = 45.0

@export_group("Output")

## Resolution of the generated delta texture
@export_range(64, 1024) var delta_resolution: int = 256

func _init() -> void:
	agent_name = "Mountain V2"
	tokens = 25

func get_modifier_type() -> ModifierType:
	if enable_overhangs:
		return ModifierType.COMPOSITE
	return ModifierType.HEIGHT_DELTA

func get_agent_type() -> String:
	return "MountainV2"

func validate(context: TerrainGenerationContext) -> bool:
	if tokens <= 0:
		push_error("MountainAgentV2: tokens must be positive")
		return false
	if step_distance <= 0:
		push_error("MountainAgentV2: step_distance must be positive")
		return false
	return true

func generate(context: TerrainGenerationContext) -> TerrainModifierResult:
	var start_time := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Calculating mountain path")
	var rng := RandomNumberGenerator.new()
	rng.seed = direction_seed if direction_seed != 0 else context.generation_seed
	var path_points := _calculate_path(rng)
	progress_updated.emit(0.2, "Calculating mountain bounds")
	var bounds := _calculate_bounds(path_points)
	progress_updated.emit(0.3, "Creating height delta texture")
	var delta := HeightDeltaMap.create(delta_resolution, delta_resolution, bounds)
	delta.blend_strategy = AdditiveBlendStrategy.new()
	delta.intensity = 1.0
	delta.edge_falloff = 0.1
	delta.source_agent = get_display_name()
	progress_updated.emit(0.4, "Generating mountain ridge")
	for i in range(path_points.size()):
		var point_data: Dictionary = path_points[i]
		var position: Vector2 = point_data["position"]
		var direction: Vector2 = point_data["direction"]
		var height_mult: float = point_data["height_mult"]
		var width_mult: float = point_data["width_mult"]
		_apply_wedge_to_delta(delta, bounds, position, direction, height_mult, width_mult)
		if i % 5 == 0:
			progress_updated.emit(0.4 + 0.4 * float(i) / float(path_points.size()), 
				"Processing token %d/%d" % [i, path_points.size()])
	var result := TerrainModifierResult.create_success()
	result.add_height_delta(delta)
	if enable_overhangs:
		progress_updated.emit(0.85, "Generating overhangs")
		var overhangs := _generate_overhangs(path_points, context, rng)
		for overhang in overhangs:
			result.add_volume(overhang)
	progress_updated.emit(1.0, "Complete")
	var elapsed := Time.get_ticks_msec() - start_time
	result.elapsed_time_ms = elapsed
	result.error_message = "Created mountain ridge with %d tokens" % tokens
	if enable_overhangs:
		result.error_message += ", %d overhangs" % result.volumes.size()
	return result

## Calculate the path points for the mountain ridge.
func _calculate_path(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var path: Array[Dictionary] = []
	var initial_direction_rad := deg_to_rad(initial_direction_degrees)
	var original_direction := Vector2(sin(initial_direction_rad), cos(initial_direction_rad)).normalized()
	var current_direction := original_direction
	var current_position := start_position
	for i in range(tokens):
		var height_mult := 1.0 + rng.randf_range(-height_variation, height_variation)
		var width_mult := 1.0 + rng.randf_range(-width_variation * 0.5, width_variation * 0.5)
		path.append({
			"position": current_position,
			"direction": current_direction,
			"height_mult": height_mult,
			"width_mult": width_mult,
			"token_index": i
		})
		current_position += current_direction * step_distance
		if direction_change_interval > 0 and (i + 1) % direction_change_interval == 0:
			var angle_offset := rng.randf_range(-direction_change_angle, direction_change_angle)
			var new_angle := atan2(original_direction.x, original_direction.y) + deg_to_rad(angle_offset)
			current_direction = Vector2(sin(new_angle), cos(new_angle)).normalized()
	return path

## Calculate bounds that encompass the entire mountain.
func _calculate_bounds(path_points: Array[Dictionary]) -> AABB:
	if path_points.is_empty():
		return AABB()
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	var max_height := 0.0
	for point_data in path_points:
		var pos: Vector2 = point_data["position"]
		var width_mult: float = point_data["width_mult"]
		var height_mult: float = point_data["height_mult"]
		var extent := maxf(wedge_width, wedge_length) * width_mult
		min_pos.x = minf(min_pos.x, pos.x - extent)
		min_pos.y = minf(min_pos.y, pos.y - extent)
		max_pos.x = maxf(max_pos.x, pos.x + extent)
		max_pos.y = maxf(max_pos.y, pos.y + extent)
		max_height = maxf(max_height, elevation_height * height_mult)
	var padding := maxf(wedge_width, wedge_length) * 0.5
	min_pos -= Vector2(padding, padding)
	max_pos += Vector2(padding, padding)
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
	height_mult: float,
	width_mult: float
) -> void:
	var perpendicular := Vector2(-direction.y, direction.x)
	var actual_width := wedge_width * width_mult
	var actual_height := elevation_height * height_mult
#	var inv_size := Vector2(1.0 / bounds.size.x, 1.0 / bounds.size.z)
#	var offset := Vector2(bounds.position.x, bounds.position.z)
	for y in range(delta_resolution):
		for x in range(delta_resolution):
			var u := float(x) / float(delta_resolution - 1)
			var v := float(y) / float(delta_resolution - 1)
			var world_x := bounds.position.x + u * bounds.size.x
			var world_z := bounds.position.z + v * bounds.size.z
			var pixel_pos := Vector2(world_x, world_z)
			var relative := pixel_pos - position
			var dist_along := relative.dot(direction)
			var dist_perp: float = abs(relative.dot(perpendicular))
			if abs(dist_along) > wedge_length or dist_perp > actual_width:
				continue
			var t_along: float = abs(dist_along) / wedge_length
			var t_perp: float = dist_perp / actual_width
			var t := maxf(t_along, t_perp)
			var strength := pow(1.0 - t, elevation_falloff + 1.0)
			var delta_value := actual_height * strength
			var current := delta.sample_at(pixel_pos)
			delta.set_at_uv(Vector2(u, v), maxf(current, delta_value))

## Generate overhang volumes for steep sections.
func _generate_overhangs(
	path_points: Array[Dictionary],
	context: TerrainGenerationContext,
	rng: RandomNumberGenerator
) -> Array[OverhangVolumeDefinition]:
	var overhangs: Array[OverhangVolumeDefinition] = []
	for point_data in path_points:
		if rng.randf() > overhang_probability:
			continue
		var position: Vector2 = point_data["position"]
		var direction: Vector2 = point_data["direction"]
		var height_mult: float = point_data["height_mult"]
		var side := 1.0 if rng.randf() > 0.5 else -1.0
		var perpendicular := Vector2(-direction.y, direction.x) * side
		var overhang := OverhangVolumeDefinition.new()
		var base_height := context.get_scaled_height_at(position)
		var ridge_height := elevation_height * height_mult
		overhang.attachment_point = Vector3(
			position.x + perpendicular.x * wedge_width * 0.8,
			base_height + ridge_height * 0.7,
			position.y + perpendicular.y * wedge_width * 0.8
		)
		overhang.overhang_direction = Vector3(
			perpendicular.x,
			-0.2,
			perpendicular.y
		).normalized()
		overhang.extent = overhang_extent * rng.randf_range(0.7, 1.3)
		overhang.width = wedge_length * rng.randf_range(0.5, 1.0)
		overhang.thickness = 1.5 * rng.randf_range(0.8, 1.2)
		overhang.noise_strength = 0.3
		overhang.noise_seed = rng.randi()
		overhang.update_bounds()
		overhangs.append(overhang)
	return overhangs

