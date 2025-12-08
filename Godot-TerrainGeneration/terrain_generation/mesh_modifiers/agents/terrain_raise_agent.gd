## @brief Agent that raises terrain in a circular region.
##
## @details Demonstrates spatial queries and region-based modification with falloff.
## Uses the shared memory architecture for efficient vertex manipulation.
@tool
class_name TerrainRaiseAgent extends MeshModifierAgent

@export_group("Raise Parameters")
## Center position of the raise effect (grid coordinates).
@export var center_position: Vector2 = Vector2(0, 0)
## Radius of effect.
@export var radius: float = 50.0
## Height to raise.
@export var height: float = 10.0
## Falloff strength (higher = sharper edge).
@export var falloff: float = 1.0

func _init() -> void:
	agent_name = "Terrain Raise Agent"

func get_agent_type() -> String:
	return "TerrainRaise"

func modifies_mesh() -> bool:
	return true

func validate(context: MeshModifierContext) -> bool:
	if not context.get_mesh_data():
		push_error("TerrainRaiseAgent: No mesh data in context")
		return false
	return true

func execute(context: MeshModifierContext) -> MeshModifierResult:
	var start_time := Time.get_ticks_msec()
	
	progress_updated.emit(0.0, "Starting terrain raise")
	
	# Get affected vertices using spatial index
	var vertex_index := context.find_nearest_vertex(center_position)
	var scaled_radius := context.scale_to_grid(radius)
	var affected := context.get_neighbours_chebyshev(vertex_index, scaled_radius)
	affected.append(vertex_index)
	
	if affected.is_empty():
		return MeshModifierResult.create_failure("No vertices found in radius")
	
	# Get center position (reuse vertex_index, don't recalculate)
	var center_vertex_position := context.get_vertex_position(vertex_index)
	var cx := center_vertex_position.x
	var cz := center_vertex_position.z
	var radius_sq := radius * radius
	
	# Direct array access for performance (eliminates function call overhead)
	var vertices := context.get_vertex_array()
	
	# Process affected vertices
	for vertex_idx in affected:
		# Calculate distance squared (avoid sqrt when possible)
		var vx := vertices[vertex_idx].x
		var vz := vertices[vertex_idx].z
		var dx := vx - cx
		var dz := vz - cz
		var dist_sq := dx * dx + dz * dz
		
		# Early out for vertices outside circular radius
		if dist_sq >= radius_sq:
			continue
		
		# Calculate actual distance and falloff
		var dist := sqrt(dist_sq)
		var strength := 1.0 - (dist / radius)
		strength = pow(strength, falloff + 1.0)
		
		# Apply height modification
		vertices[vertex_idx].y += height * strength
	
	# Mark mesh as dirty to recalculate normals/tangents
	context.mark_mesh_dirty()
	
	progress_updated.emit(1.0, "Terrain raise complete")
	var elapsed := Time.get_ticks_msec() - start_time
	var metadata := {
		"center": center_position,
		"radius": radius,
		"height": height,
		"falloff": falloff,
		"affected_vertices": affected.size()
	}
	
	return MeshModifierResult.create_success(
		elapsed,
		"Raised terrain at %s (radius: %.1f, height: %.1f, vertices: %d)" % [center_position, radius, height, affected.size()],
		metadata
	)
