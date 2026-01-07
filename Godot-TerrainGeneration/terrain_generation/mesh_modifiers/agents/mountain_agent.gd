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

@export_group("Smoothing")
## Smoothing radius around each location.
@export var smooth_radius: float = 15.0

## Smoothing strength (0.0 = no smoothing, 1.0 = full averaging).
@export_range(0.0, 1.0, 0.05) var smooth_strength: float = 0.3

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
	if not context.get_mesh_data():
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
	var terrain_sz := context.terrain_size()
	var mesh_data := context.get_mesh_data()
	print("Terrain size: ", terrain_sz)
	print("Mesh dimensions: %dx%d" % [mesh_data.width, mesh_data.height])
	print("First vertex: ", mesh_data.get_vertex(0))
	print("Last vertex: ", mesh_data.get_vertex(mesh_data.get_vertex_count() - 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = direction_seed if direction_seed != 0 else context.get_generation_seed()
	var initial_direction_rad := deg_to_rad(initial_direction_degrees)
	var original_direction := Vector2(sin(initial_direction_rad), cos(initial_direction_rad)).normalized()
	var current_direction := original_direction
	var current_position := start_position
	var total_affected_vertices := 0
	for token in range(tokens):
		if token % 10 == 0:
			progress_updated.emit(float(token) / tokens, "Processing token %d/%d" % [token + 1, tokens])
		var wedge_affected := _elevate_wedge(context, current_position, current_direction, rng, noise)
		print("Token %d - Position: (%0.2f, %0.2f), Affected: %d vertices" % [token + 1, current_position.x, current_position.y, wedge_affected])
		total_affected_vertices += wedge_affected
		_smooth_area(context, current_position)
		current_position += current_direction * step_distance
		if direction_change_interval > 0 and (token + 1) % direction_change_interval == 0:
			var angle_offset := rng.randf_range(-direction_change_angle, direction_change_angle)
			var new_angle := atan2(original_direction.x, original_direction.y) + deg_to_rad(angle_offset)
			current_direction = Vector2(sin(new_angle), cos(new_angle)).normalized()
	context.mark_mesh_dirty()
	progress_updated.emit(1.0, "Mountain ridge generation complete")
	var elapsed := Time.get_ticks_msec() - start_time
	var metadata := {
		"start_position": start_position,
		"initial_direction": initial_direction_degrees,
		"tokens": tokens,
		"total_affected_vertices": total_affected_vertices,
		"wedge_dimensions": Vector2(wedge_width, wedge_length),
		"elevation_height": elevation_height
	}
	return MeshModifierResult.create_success(
		elapsed,
		"Created mountain ridge with %d tokens (affected %d vertices)" % [tokens, total_affected_vertices],
		metadata
	)

## Elevate a wedge-shaped area perpendicular to the direction.
func _elevate_wedge(context: MeshModifierContext, position: Vector2, direction: Vector2, rng: RandomNumberGenerator, noise_gen: FastNoiseLite) -> int:
	var perpendicular := Vector2(-direction.y, direction.x)
	var center_vertex_index := context.find_nearest_vertex(position)
	if center_vertex_index < 0:
		print("ERROR: find_nearest_vertex returned -1 for position (%0.2f, %0.2f)" % [position.x, position.y])
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

## Smooth the area around a position using Gaussian-like averaging.
func _smooth_area(context: MeshModifierContext, position: Vector2) -> void:
	if smooth_strength <= 0.0 or smooth_radius <= 0.0:
		return
	var center_vertex_index := context.find_nearest_vertex(position)
	if center_vertex_index < 0:
		return
	var scaled_radius := context.scale_to_grid(smooth_radius)
	var candidates := context.get_neighbours_chebyshev(center_vertex_index, scaled_radius)
	candidates.append(center_vertex_index)
	var vertices := context.get_vertex_array()
	var radius_sq := smooth_radius * smooth_radius
	var original_heights: Dictionary = {}
	for vertex_index in candidates:
		original_heights[vertex_index] = vertices[vertex_index].y
	for vertex_index in candidates:
		var vertex := vertices[vertex_index]
		var vertex_2d := Vector2(vertex.x, vertex.z)
		var dist_sq := vertex_2d.distance_squared_to(position)
		if dist_sq > radius_sq:
			continue
		var weighted_sum := 0.0
		var weight_total := 0.0
		for neighbor_index in candidates:
			var neighbor := vertices[neighbor_index]
			var neighbor_2d := Vector2(neighbor.x, neighbor.z)
			var neighbor_dist_sq := neighbor_2d.distance_squared_to(vertex_2d)
			var weight := exp(-neighbor_dist_sq / (smooth_radius * smooth_radius * 0.5))
			weighted_sum += original_heights[neighbor_index] * weight
			weight_total += weight
		if weight_total > 0.0:
			var smoothed_height := weighted_sum / weight_total
			vertices[vertex_index].y = lerp(original_heights[vertex_index], smoothed_height, smooth_strength)
