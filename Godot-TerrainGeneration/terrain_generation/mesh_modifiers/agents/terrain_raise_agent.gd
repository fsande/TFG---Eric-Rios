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
	if not context.get_mesh_generation_result():
		push_error("TerrainRaiseAgent: No mesh data in context")
		return false
	return true

func execute(context: MeshModifierContext) -> MeshModifierResult:
	var start_time := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Starting terrain raise")
	_raise_terrain(context)
	progress_updated.emit(1.0, "Terrain raise complete")
	var elapsed := Time.get_ticks_msec() - start_time
	var metadata := {
		"center": center_position,
		"radius": radius,
		"height": height,
		"falloff": falloff,
	}
	return MeshModifierResult.create_success(
		elapsed,
		"Raised terrain at %s (radius: %.1f, height: %.1f)" % [center_position, radius, height],
		metadata
	)

func _raise_terrain(context: MeshModifierContext) -> void:
	var vertex_index := context.find_nearest_vertex(center_position)
	print("Raise agent finding nearest vertex for position (%0.2f, %0.2f), which is at world position (%s): %d" % [
		center_position.x,
		center_position.y,
		str(context.get_vertex_position(vertex_index)),
		vertex_index
	])
	var scaled_radius := context.scale_to_grid(radius)
	var affected := context.get_neighbours_chebyshev(vertex_index, scaled_radius)
	affected.append(vertex_index)
	if affected.is_empty():
		return MeshModifierResult.create_failure("No vertices found in radius")
	var center_vertex_position := context.get_vertex_position(vertex_index)
	var cx := center_vertex_position.x
	var cz := center_vertex_position.z
	var radius_sq := radius * radius
	var vertices := context.get_vertex_array()
	for vertex_idx in affected:
		var vx := vertices[vertex_idx].x
		var vz := vertices[vertex_idx].z
		var dx := vx - cx
		var dz := vz - cz
		var dist_sq := dx * dx + dz * dz
		if dist_sq >= radius_sq:
			continue
		var dist := sqrt(dist_sq)
		var strength := 1.0 - (dist / radius)
		strength = pow(strength, falloff + 1.0)
		vertices[vertex_idx].y += height * strength
	context.mark_mesh_dirty()
