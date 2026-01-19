## @brief Agent that creates mountain ridges using token-based path following.
##
## @details Creates mountain ranges by elevating wedge-shaped areas perpendicular
## to a direction vector, with periodic direction changes. Uses a token-based
## iteration system with smoothing for natural-looking mountain formation.
@tool
class_name MountainAgent extends MeshModifierAgent

@export_group("Mountain Parameters")
## Starting position of the mountain ridge (grid coordinates).
@export var start_position: Vector2 = Vector2(0, 0)

## Initial direction angle in degrees (0 = North/+Z, 90 = East/+X).
@export_range(0.0, 360.0, 1.0) var initial_direction_degrees: float = 0.0

## Distance to move forward each token.
@export var step_distance: float = 5.0

## Wedge width (perpendicular to direction).
@export var wedge_width: float = 20.0

## Wedge length (along direction).
@export var wedge_length: float = 10.0

## Height to elevate at wedge center.
@export var elevation_height: float = 15.0

## Falloff strength for wedge elevation (higher = sharper).
@export_range(0.1, 5.0, 0.1) var elevation_falloff: float = 1.0

@export_group("Randomization")
## Height variation per wedge (0.0 = no variation, 1.0 = can vary from 0 to 2x height).
@export_range(0.0, 1.0, 0.05) var wedge_height_variation: float = 0.3

## Width variation per wedge (0.0 = no variation, 1.0 = can vary from 0.5x to 1.5x width).
@export_range(0.0, 1.0, 0.05) var wedge_width_variation: float = 0.2

## Noise strength for vertex elevation (0.0 = no noise, 1.0 = significant noise).
@export_range(0.0, 1.0, 0.05) var noise_strength: float = 0.15

## Noise generator for terrain variation (configure type, frequency, seed, etc. in inspector).
@export var noise: FastNoiseLite = null

@export_group("Direction Changes")
## Change direction every N tokens (0 = never change).
@export_range(0, 100, 1) var direction_change_interval: int = 10

## Angle change in degrees (+/- this value from original direction).
@export_range(0.0, 90.0, 5.0) var direction_change_angle: float = 45.0

## Random seed for direction changes (0 = use generation seed).
@export var direction_seed: int = 0

func _init() -> void:
	agent_name = "Mountain Agent"

func get_agent_type() -> String:
	return "MountainAgent"

func modifies_mesh() -> bool:
	return true

func validate(context: MeshModifierContext) -> bool:
	if not context.get_mesh_generation_result():
		push_error("MountainAgent: No mesh data in context")
		return false
	if tokens <= 0:
		push_error("MountainAgent: tokens must be positive")
		return false
	if step_distance <= 0.0:
		push_error("MountainAgent: step_distance must be positive")
		return false
	return true

func execute(context: MeshModifierContext) -> MeshModifierResult:
	var start_time := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Starting mountain ridge generation")
	_apply_mountain(context)
	progress_updated.emit(1.0, "Mountain ridge generation complete")
	var elapsed := Time.get_ticks_msec() - start_time
	var metadata := {
		"start_position": start_position,
		"initial_direction": initial_direction_degrees,
		"tokens": tokens,
		"wedge_dimensions": Vector2(wedge_width, wedge_length),
		"elevation_height": elevation_height
	}
	return MeshModifierResult.create_success(
		elapsed,
		"Created mountain ridge with %d tokens" % [tokens],
		metadata
	)

func _apply_mountain(context: MeshModifierContext) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = direction_seed if direction_seed != 0 else context.get_generation_seed()
	var initial_direction_rad := deg_to_rad(initial_direction_degrees)
	var original_direction := Vector2(sin(initial_direction_rad), cos(initial_direction_rad)).normalized()
	var current_direction := original_direction
	var current_position := start_position
	for token in range(tokens):
		_elevate_wedge(context, current_position, current_direction, rng, noise)
		current_position += current_direction * step_distance
		if direction_change_interval > 0 and (token + 1) % direction_change_interval == 0:
			var angle_offset := rng.randf_range(-direction_change_angle, direction_change_angle)
			var new_angle := atan2(original_direction.x, original_direction.y) + deg_to_rad(angle_offset)
			current_direction = Vector2(sin(new_angle), cos(new_angle)).normalized()
	context.mark_mesh_dirty()

## Elevate a wedge-shaped area perpendicular to the direction.
func _elevate_wedge(context: MeshModifierContext, position: Vector2, direction: Vector2, rng: RandomNumberGenerator, noise_gen: FastNoiseLite) -> int:
	var perpendicular := Vector2(-direction.y, direction.x)
	var center_vertex_index := context.find_nearest_vertex(position)
	if center_vertex_index < 0:
		push_error("Find_nearest_vertex returned -1 for position (%0.2f, %0.2f)" % [position.x, position.y])
		return 0
	var height_multiplier := 1.0 + rng.randf_range(-wedge_height_variation, wedge_height_variation)
	var width_multiplier := 1.0 + rng.randf_range(-wedge_width_variation * 0.5, wedge_width_variation * 0.5)
	var actual_wedge_width := wedge_width * width_multiplier
	var actual_elevation := elevation_height * height_multiplier
	var vertices := context.get_vertex_array()
	var search_radius: float = max(actual_wedge_width, wedge_length) * 1.5
	var scaled_search_radius := context.scale_to_grid(search_radius)
	var candidates := context.get_neighbours_chebyshev(center_vertex_index, scaled_search_radius)
	candidates.append(center_vertex_index)
	var affected_count := 0
	for vertex_index in candidates:
		var vertex := vertices[vertex_index]
		var vertex_2d := Vector2(vertex.x, vertex.z)
		var offset := vertex_2d - position
		var along_direction := offset.dot(direction)
		var perpendicular_distance := offset.dot(perpendicular)
		if abs(along_direction) > wedge_length * 0.5:
			continue
		if abs(perpendicular_distance) > actual_wedge_width * 0.5:
			continue
		var distance_from_center := offset.length()
		var falloff_factor: float = 1.0 - (distance_from_center / (max(actual_wedge_width, wedge_length) * 0.5))
		falloff_factor = clamp(falloff_factor, 0.0, 1.0)
		falloff_factor = pow(falloff_factor, elevation_falloff)
		var noise_multiplier := 1.0
		if noise_gen != null and noise_strength > 0.0:
			var noise_value := noise_gen.get_noise_2d(vertex.x, vertex.z) 
			noise_multiplier = 1.0 + (noise_value * noise_strength)
		vertices[vertex_index].y += actual_elevation * falloff_factor * noise_multiplier
		affected_count += 1
	return affected_count
	