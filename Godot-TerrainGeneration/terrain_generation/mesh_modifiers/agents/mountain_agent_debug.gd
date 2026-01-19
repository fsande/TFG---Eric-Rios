@tool
class_name MountainAgentDebug extends MeshModifierAgent

@export_group("Mountain Parameters")
@export var start_position: Vector2 = Vector2(0, 0)
@export_range(0.0, 360.0, 1.0) var initial_direction_degrees: float = 0.0
@export var step_distance: float = 5.0
@export var wedge_width: float = 20.0
@export var wedge_length: float = 10.0
@export var elevation_height: float = 15.0
@export_range(0.1, 5.0, 0.1) var elevation_falloff: float = 1.0

@export_group("Randomization")
@export_range(0.0, 1.0, 0.05) var wedge_height_variation: float = 0.3
@export_range(0.0, 1.0, 0.05) var wedge_width_variation: float = 0.2
@export_range(0.0, 1.0, 0.05) var noise_strength: float = 0.15
@export var noise: FastNoiseLite = null

@export_group("Direction Changes")
@export_range(0, 100, 1) var direction_change_interval: int = 10
@export_range(0.0, 90.0, 5.0) var direction_change_angle: float = 45.0
@export var direction_seed: int = 0

@export_group("Debug Parameters")
@export var update_every_n_vertices: int = 100
@export var update_delay_ms: int = 50


func _init() -> void:
	agent_name = "Mountain Agent (Debug)"

func get_agent_type() -> String:
	return "MountainAgentDebug"

func modifies_mesh() -> bool:
	return true

func validate(context: MeshModifierContext) -> bool:
	if not context.get_mesh_generation_result():
		push_error("MountainAgentDebug: No mesh data in context")
		return false
	if tokens <= 0:
		push_error("MountainAgentDebug: tokens must be positive")
		return false
	if step_distance <= 0.0:
		push_error("MountainAgentDebug: step_distance must be positive")
		return false
	return true

func execute(context: MeshModifierContext) -> MeshModifierResult:
	var start_time := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Starting mountain ridge generation (debug mode)")
	_apply_mountain_incremental(context)
	progress_updated.emit(1.0, "Mountain ridge generation complete")
	var elapsed := Time.get_ticks_msec() - start_time
	var metadata := {
		"start_position": start_position,
		"initial_direction": initial_direction_degrees,
		"tokens": tokens,
		"wedge_dimensions": Vector2(wedge_width, wedge_length),
		"elevation_height": elevation_height,
		"update_interval": update_every_n_vertices,
	}
	return MeshModifierResult.create_success(
		elapsed,
		"Created mountain ridge with %d tokens (debug mode)" % [tokens],
		metadata
	)

func _apply_mountain_incremental(context: MeshModifierContext) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = direction_seed if direction_seed != 0 else context.get_generation_seed()
	var initial_direction_rad := deg_to_rad(initial_direction_degrees)
	var original_direction := Vector2(sin(initial_direction_rad), cos(initial_direction_rad)).normalized()
	var current_direction := original_direction
	var current_position := start_position
	var total_modified := 0
	elevate_vertices_by_grid(context, -1, -1, elevation_height, update_delay_ms)
	elevate_vertices_incrementally(context, context._mesh.vertex_count, elevation_height, update_delay_ms)
#	for token in range(tokens):
#		print("DEBUG: Elevating at token %d at position (%0.2f, %0.2f)" % [token, current_position.x, current_position.y])
#		var modified := _elevate_wedge_incremental(context, current_position, current_direction, rng, noise, total_modified)
#		total_modified += modified
#		current_position += current_direction * step_distance
#		if direction_change_interval > 0 and (token + 1) % direction_change_interval == 0:
#			var angle_offset := rng.randf_range(-direction_change_angle, direction_change_angle)
#			var new_angle := atan2(original_direction.x, original_direction.y) + deg_to_rad(angle_offset)
#			current_direction = Vector2(sin(new_angle), cos(new_angle)).normalized()
#		var progress := float(token + 1) / float(tokens)
#		progress_updated.emit(progress, "Token %d/%d complete" % [token + 1, tokens])
#	context.mark_mesh_dirty()
#	print("DEBUG: Completed mountain operation, modified %d vertices total" % total_modified)

func _elevate_wedge_incremental(context: MeshModifierContext, position: Vector2, direction: Vector2, rng: RandomNumberGenerator, noise_gen: FastNoiseLite, total_modified: int) -> int:
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
	print("DEBUG: Number of candidate vertices for wedge elevation: %d" % [candidates.size()])
	var affected_count := 0
	var skip_count := 0
	for vertex_index in candidates:
		var vertex := vertices[vertex_index]
		var vertex_2d := Vector2(vertex.x, vertex.z)
		var offset := vertex_2d - position
		var along_direction := offset.dot(direction)
		var perpendicular_distance := offset.dot(perpendicular)
		var distance_from_center := offset.length()
		var falloff_factor: float = 1.0 - (distance_from_center / (max(actual_wedge_width, wedge_length) * 0.5))
		falloff_factor = clamp(falloff_factor, 0.0, 1.0)
		falloff_factor = pow(falloff_factor, elevation_falloff)
		var noise_multiplier := 1.0
		if noise_gen != null and noise_strength > 0.0:
			var noise_value := noise_gen.get_noise_2d(vertex.x, vertex.z) 
			noise_multiplier = 1.0 + (noise_value * noise_strength)
		vertices[vertex_index].y += 100
		affected_count += 1
		if (total_modified + affected_count) % update_every_n_vertices == 0:
			_apply_incremental_update(context, total_modified + affected_count)
			if update_delay_ms > 0:
				OS.delay_msec(update_delay_ms)
	return affected_count

func _apply_incremental_update(context: MeshModifierContext, current: int) -> void:
	context.mark_mesh_dirty()	
	var presenter := TerrainPresenter.current_presenter
	if presenter:
		var mesh_result := context.get_mesh_generation_result()
		if mesh_result:
			var new_mesh := mesh_result.build_mesh()
			var mesh_instance = presenter._mesh_instance
			if mesh_instance and mesh_instance is MeshInstance3D:
				mesh_instance.mesh = new_mesh

## Elevate vertices incrementally from index 0 to n, updating mesh after each vertex.
## @param context The mesh modifier context containing vertex data
## @param n The number of vertices to elevate (from index 0 to n-1)
## @param elevation_amount The amount to elevate each vertex's Y coordinate
## @param update_delay_ms_per_vertex Delay in milliseconds after each vertex update (default: 10ms)
func elevate_vertices_incrementally(context: MeshModifierContext, n: int, elevation_amount: float = 10.0, update_delay_ms_per_vertex: int = 10) -> void:
	var vertices := context.get_vertex_array()
	var vertex_count := vertices.size()
	n = clampi(n, 0, vertex_count)
	print("DEBUG: Starting incremental elevation of %d vertices (elevation: %.2f)" % [n, elevation_amount])
	for i in range(n):
		vertices[i].y += elevation_amount
		context.mark_mesh_dirty()
		if (i + 1) % update_every_n_vertices == 0:
			_apply_incremental_update(context, i + 1)
		if update_delay_ms_per_vertex > 0:
			OS.delay_msec(update_delay_ms_per_vertex)
	print("DEBUG: Completed incremental elevation of %d vertices" % n)

func elevate_vertices_by_grid(context: MeshModifierContext, max_row: int = -1, max_col: int = -1, elevation_amount: float = 10.0, update_delay_ms_per_vertex: int = 10) -> void:
	var vertices := context.get_vertex_array()
	var grid_dimensions := context._grid.get_dimensions()
	var total_rows := grid_dimensions.y
	var total_cols := grid_dimensions.x
	if max_row < 0 or max_row >= total_rows:
		max_row = total_rows - 1
	if max_col < 0 or max_col >= total_cols:
		max_col = total_cols - 1
	var total_vertices_to_process := (max_row + 1) * (max_col + 1)
	var processed_count := 0
	print("DEBUG: Starting grid-based incremental elevation")
	print("DEBUG: Grid dimensions: %dx%d (rows x cols)" % [total_rows, total_cols])
	print("DEBUG: Processing range: rows 0-%d, cols 0-%d" % [max_row, max_col])
	print("DEBUG: Total vertices to process: %d" % total_vertices_to_process)
	print("DEBUG: Elevation amount: %.2f" % elevation_amount)
	for row in range(max_row + 1):
		for col in range(max_col + 1):
			var vertex_index := context._grid._get_vertex_at(col, row)
			if vertex_index < 0:
				print("DEBUG: Warning - No vertex found at grid position (%d, %d)" % [col, row])
				continue
			if vertex_index >= vertices.size():
				print("DEBUG: Warning - Invalid vertex index %d at grid position (%d, %d)" % [vertex_index, col, row])
				continue
			vertices[vertex_index].y += elevation_amount
			processed_count += 1
			if processed_count % update_every_n_vertices == 0:
				context.mark_mesh_dirty()
				_apply_incremental_update(context, processed_count)
			if update_delay_ms_per_vertex > 0:
				OS.delay_msec(update_delay_ms_per_vertex)
			var progress := float(processed_count) / float(total_vertices_to_process)
			progress_updated.emit(progress, "Elevated vertex at row=%d, col=%d (%d/%d)" % [row, col, processed_count, total_vertices_to_process])
	context.mark_mesh_dirty()
	_apply_incremental_update(context, processed_count)
