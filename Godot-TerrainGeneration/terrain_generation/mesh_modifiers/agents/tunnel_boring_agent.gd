## @brief Agent that creates cylindrical tunnels through terrain.
##
## @details Demonstrates topology modification by adding non-grid vertices.
## Finds steep cliff faces and bores horizontal tunnels into the terrain.
## The tunnel is created as an interior cylinder with inverted normals.
@tool
class_name TunnelBoringAgent extends MeshModifierAgent

@export_group("Tunnel Parameters")
## Length of the tunnel (depth into terrain).
@export var tunnel_length: float = 20.0

## Radius of the tunnel (width).
@export_range(1.0, 10.0, 0.5) var tunnel_radius: float = 3.0

## Extra length to open tunnel entrance above terrain surface.
@export var tunnel_entrance_extra_length: float = 2.0

## Number of radial segments (cylinder smoothness).
@export_range(6, 32, 1) var tunnel_segments: int = 8

## Number of segments along tunnel length.
@export_range(2, 20, 1) var tunnel_depth_segments: int = 5

@export_group("Placement")
## Minimum cliff height to place tunnel entrance.
@export var min_cliff_height: float = 15.0

## Minimum slope angle (degrees) for cliff detection.
@export_range(30.0, 80.0, 5.0) var min_cliff_angle: float = 45.0

## Number of tunnels to create.
@export_range(1, 10, 1) var tunnel_count: int = 1

## Random seed for placement (0 = random).
@export var placement_seed: int = 0

func _init() -> void:
	agent_name = "Tunnel Boring Agent"

func get_agent_type() -> String:
	return "TunnelBoring"

func modifies_mesh() -> bool:
	return true

func generates_scene_nodes() -> bool:
	return false

func get_produced_data_types() -> Array[String]:
	return ["tunnel_locations"]

func validate(context: MeshModifierContext) -> bool:
	if not context.get_mesh_data():
		push_error("TunnelBoringAgent: No mesh data in context")
		return false
	if tunnel_radius <= 0 or tunnel_length <= 0:
		push_error("TunnelBoringAgent: Invalid tunnel dimensions")
		return false
	
	return true

func execute(context: MeshModifierContext) -> MeshModifierResult:
	var start_time := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Finding cliff faces using optimized image sampling")
	var time_before_search := Time.get_ticks_msec()
	var sample_count := tunnel_count * 2
	var entry_points := context.sample_cliff_positions(
		min_cliff_angle,
		min_cliff_height,
		sample_count,
		placement_seed
	)
	var search_time := Time.get_ticks_msec() - time_before_search
	print("Found %d cliff positions in %d ms (image-based sampling)" % [entry_points.size(), search_time])
	if entry_points.is_empty():
		var elapsed_to_error := Time.get_ticks_msec() - start_time
		return MeshModifierResult.create_failure("No suitable cliff faces found for tunnel placement", elapsed_to_error)
	var time_before_filtering := Time.get_ticks_msec()
	var filtered_entry_points := _filter_entry_points(entry_points, context)
	var filtering_time := Time.get_ticks_msec() - time_before_filtering
	print("Filtered to %d valid entry points in %d ms" % [filtered_entry_points.size(), filtering_time])
	if filtered_entry_points.is_empty():
		var elapsed_to_error := Time.get_ticks_msec() - start_time
		return MeshModifierResult.create_failure("No valid entry points found for tunnel placement", elapsed_to_error)
	var entry_points_to_use: Array[TunnelEntryPoint]= filtered_entry_points.slice(0, tunnel_count)
	_lengthen_entry_points(entry_points_to_use)
	_debug_draw_entry_points(entry_points_to_use, context.scene_root)
	var tunnels_created := 0
	var time_before_creation := Time.get_ticks_msec()
	for i in range(entry_points_to_use.size()):
		var entry := entry_points_to_use[i]
		progress_updated.emit(float(i) / tunnel_count, "Creating tunnel %d/%d" % [i + 1, tunnel_count])
		if _create_tunnel_at(entry, context):
			tunnels_created += 1
	var creation_time := Time.get_ticks_msec() - time_before_creation
	print("Created %d tunnel(s) in %d ms." % [tunnels_created, creation_time])
	var elapsed := Time.get_ticks_msec() - start_time	
	return MeshModifierResult.create_success(
		elapsed,
		"Created %d tunnel(s) (radius: %.1f, length: %.1f)" % [tunnels_created, tunnel_radius, tunnel_length],
		get_metadata()	
	)
	
## Extend entry points above terrain surface for better tunnel entrances.
func _lengthen_entry_points(entry_points: Array[TunnelEntryPoint]) -> void:
	for entry in entry_points:
		entry.position -= entry.tunnel_direction * tunnel_entrance_extra_length
		entry.length += tunnel_entrance_extra_length

## Filter entry points by tunnel geometry constraints.
## Ensures tunnels don't go out of bounds and have valid direction vectors.
func _filter_entry_points(entry_points: Array[TunnelEntryPoint], context: MeshModifierContext) -> Array[TunnelEntryPoint]:
	var valid_points: Array[TunnelEntryPoint] = []
	var terrain_size := context.terrain_size()
	for entry in entry_points:
		if not entry.has_valid_direction():
			continue
		if not entry.is_within_bounds(tunnel_length, terrain_size):
			continue
		
		valid_points.append(entry)
	return valid_points

## Debug: Draw cylinders at entry points in the scene.
func _debug_draw_entry_points(entry_points: Array[TunnelEntryPoint], root: Node3D) -> void:
	var container_name := "TunnelDebugCylinders"
	var container := root.get_node_or_null(container_name)
	if container == null:
		container = Node3D.new()
		container.name = container_name
		root.add_child(container)
	else:
		for child in container.get_children():
			child.queue_free()
	# Create a semi-transparent red cylinder for each tunnel
	for entry in entry_points:
		# Create cylinder volume for debug visualization
		var cylinder := CylinderVolume.new(entry.position, entry.tunnel_direction, tunnel_radius, tunnel_length)
		var debug_data := cylinder.get_debug_mesh()
		var mesh: Mesh = debug_data[0]
		var transform: Transform3D = debug_data[1]
		
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		
		# Semi-transparent red material
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.0, 0.0, 0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
		mi.material_override = mat
		mi.global_transform = transform
		
		container.add_child(mi)

## Create a tunnel at the specified entry point using CSG boolean subtraction.
func _create_tunnel_at(entry: TunnelEntryPoint, context: MeshModifierContext) -> bool:
	var entry_pos: Vector3 = entry.position
	var tunnel_direction: Vector3 = entry.tunnel_direction
	var cylinder := CylinderVolume.new(entry_pos, tunnel_direction, tunnel_radius, tunnel_length)
	var original_mesh := context.get_mesh_data().mesh_data
	var csg_operator := CSGBooleanOperator.new()
	print("  CSG: Subtracting cylinder from mesh (%d triangles)" % original_mesh.get_triangle_count())
	var modified_mesh := csg_operator.subtract_volume_from_mesh(original_mesh, cylinder)
	print("  CSG: Result has %d triangles (removed %d)" % [modified_mesh.get_triangle_count(), 
		original_mesh.get_triangle_count() - modified_mesh.get_triangle_count()])
	_replace_mesh_in_context(context, modified_mesh)
	# _generate_tunnel_interior_underground(entry_pos, tunnel_direction, context)
	return true

## Replace mesh data in context with new mesh
func _replace_mesh_in_context(context: MeshModifierContext, new_mesh_data: MeshData) -> void:
	var mesh_result := context.get_mesh_data()
	mesh_result.mesh_data = new_mesh_data
	mesh_result.mark_dirty()

## Generate tunnel interior walls
func _generate_tunnel_interior_underground(origin: Vector3, direction: Vector3, context: MeshModifierContext) -> void:
	var positions := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var forward := direction.normalized()
	var up := Vector3.UP
	if abs(forward.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var right := forward.cross(up).normalized()
	up = right.cross(forward).normalized()
	var ring_start_indices: Array[int] = []
	for depth_slice in range(tunnel_depth_segments + 1):
		var t := float(depth_slice) / tunnel_depth_segments
		var slice_center := origin + forward * (tunnel_length * t)
		var terrain_height := _get_terrain_height_at_xz(slice_center.x, slice_center.z, context)
		if slice_center.y > terrain_height:
			continue
		var ring_base := positions.size()
		ring_start_indices.append(ring_base)
		for segment in range(tunnel_segments + 1):
			var angle := (float(segment) / tunnel_segments) * TAU
			var x := cos(angle) * tunnel_radius
			var y := sin(angle) * tunnel_radius
			var offset := right * x + up * y
			
			positions.append(slice_center + offset)
			uvs.append(Vector2(float(segment) / tunnel_segments, t))
	for ring_idx in range(ring_start_indices.size() - 1):
		var curr_base := ring_start_indices[ring_idx]
		var next_base := ring_start_indices[ring_idx + 1]
		for seg in range(tunnel_segments):
			var i0 := curr_base + seg
			var i1 := i0 + 1
			var i2 := next_base + seg
			var i3 := i2 + 1
			indices.append(i0)
			indices.append(i2)
			indices.append(i1)
			indices.append(i1)
			indices.append(i2)
			indices.append(i3)
	if positions.size() > 0:
		var base_vertex_idx := context.add_vertices(positions, uvs)
		if base_vertex_idx >= 0:
			var offset_indices := PackedInt32Array()
			for idx in indices:
				offset_indices.append(idx + base_vertex_idx)
			context.add_triangles(offset_indices)
			print("  Generated %d tunnel wall vertices" % positions.size())

## Get terrain height at XZ position
func _get_terrain_height_at_xz(x: float, z: float, context: MeshModifierContext) -> float:
	var pos_2d := Vector2(x, z)
	var nearest_idx := context.find_nearest_vertex(pos_2d)
	if nearest_idx < 0:
		return 0.0
	var nearest_vertex := context.get_vertex_position(nearest_idx)
	return nearest_vertex.y

## Get metadata about this agent.
func get_metadata() -> Dictionary:
	var base := super.get_metadata()
	base["tunnel_radius"] = tunnel_radius
	base["tunnel_length"] = tunnel_length
	base["tunnel_segments"] = tunnel_segments
	return base
