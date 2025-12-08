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
	return false  # Could add lights later

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
	
	# Use optimized image-based sampling instead of vertex iteration
	var sample_count := tunnel_count * 5  # Oversample to account for filtering
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
	
	# Filter entry points based on tunnel geometry constraints
	var time_before_filtering := Time.get_ticks_msec()
	entry_points = _filter_entry_points_by_tunnel_constraints(entry_points, context)
	var filtering_time := Time.get_ticks_msec() - time_before_filtering
	print("Filtered to %d valid entry points in %d ms" % [entry_points.size(), filtering_time])
	
	if entry_points.is_empty():
		var elapsed_to_error := Time.get_ticks_msec() - start_time
		return MeshModifierResult.create_failure("No valid entry points found for tunnel placement", elapsed_to_error)
	
	# Create tunnels
	_debug_draw_entry_points(entry_points.slice(0, tunnel_count), context.scene_root)
	var tunnels_created := 0
	var tunnel_locations: Array[Dictionary] = []
	var time_before_creation := Time.get_ticks_msec()
	for i in range(min(tunnel_count, entry_points.size())):
		var entry := entry_points[i]
		
		progress_updated.emit(float(i) / tunnel_count, "Creating tunnel %d/%d" % [i + 1, tunnel_count])
		
		if _create_tunnel_at(entry, context):
			tunnels_created += 1
			tunnel_locations.append({
				"position": entry.position,
				"normal": entry.tunnel_normal,  # Use precomputed tunnel direction
				"radius": tunnel_radius,
				"length": tunnel_length
			})
	var creation_time := Time.get_ticks_msec() - time_before_creation
	print("Created %d tunnel(s) in %d ms." % [tunnels_created, creation_time])
	var elapsed := Time.get_ticks_msec() - start_time
	var metadata := get_metadata()
	return MeshModifierResult.create_success(
		elapsed,
		"Created %d tunnel(s) (radius: %.1f, length: %.1f)" % [tunnels_created, tunnel_radius, tunnel_length],
		metadata
	)


## Filter entry points from image sampling based on tunnel geometry constraints.
## Ensures tunnels don't go out of bounds and have valid direction vectors.
func _filter_entry_points_by_tunnel_constraints(entry_points: Array[Dictionary], context: MeshModifierContext) -> Array[Dictionary]:
	var valid_points: Array[Dictionary] = []
	var terrain_size := context.terrain_size()
	
	for entry in entry_points:
		var position: Vector3 = entry.position
		var slope_normal: Vector3 = entry.normal
		
		# Calculate tunnel direction (horizontal, into the cliff)
		var tunnel_normal := -Vector3(slope_normal.x, 0.0, slope_normal.z).normalized()
		
		# Skip if tunnel direction is too vertical or invalid
		if tunnel_normal.length() < 0.1:
			continue
		
		# Check if tunnel end would be within terrain bounds
		var tunnel_end := position + tunnel_normal * tunnel_length
		if abs(tunnel_end.x) > terrain_size.x * 0.4 or abs(tunnel_end.z) > terrain_size.y * 0.4:
			continue
		
		# Add tunnel direction to entry point
		entry["tunnel_normal"] = tunnel_normal
		valid_points.append(entry)
	
	# Sort by slope angle (steeper cliffs first - more dramatic tunnels)
	valid_points.sort_custom(func(a, b): return a.slope_angle > b.slope_angle)
	
	return valid_points

## Debug: Draw spheres at entry points in the scene.
func _debug_draw_entry_points(entry_points: Array[Dictionary], root: Node3D) -> void:
	var container_name := "TunnelDebugSpheres"
	var container := root.get_node_or_null(container_name)
	if container == null:
		container = Node3D.new()
		container.name = container_name
		root.add_child(container)
	else:
		for child in container.get_children():
			child.queue_free()

	# Create a red sphere at each entry point
	var debug_sphere_radius := 1
	var debug_sphere_segments := 16
	for entry in entry_points:
		var pos: Vector3 = entry.position

		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = debug_sphere_radius
		sm.height = debug_sphere_radius * 2.0
		sm.radial_segments = debug_sphere_segments
		sm.rings = debug_sphere_segments  
		mi.mesh = sm

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.0, 0.0)
		mi.material_override = mat
		mi.global_transform = Transform3D(Basis(), pos)

		container.add_child(mi)

## Create a tunnel at the specified entry point.
func _create_tunnel_at(entry: Dictionary, context: MeshModifierContext) -> bool:
	var entry_pos: Vector3 = entry.position
	var tunnel_direction: Vector3 = entry.tunnel_normal  # Use precomputed direction
	
	# STEP 1: Remove terrain triangles inside the tunnel volume
	var removed_tris := _remove_terrain_triangles_in_tunnel(entry_pos, tunnel_direction, context)
	print("  Tunnel: Removed %d triangles" % removed_tris)
	
	# STEP 2: Displace nearby vertices to the tunnel wall (smooth transition)
	var displaced_vertices := _displace_vertices_to_tunnel_wall(entry_pos, tunnel_direction, context)
	print("  Tunnel: Displaced %d vertices" % displaced_vertices.size())
	
	# STEP 3: Generate tunnel geometry
	var tunnel_geom := _generate_tunnel_geometry(entry_pos, tunnel_direction)
	
	var base_vertex_idx := context.add_vertices(tunnel_geom.positions, tunnel_geom.uvs)
	if base_vertex_idx < 0:
		return false
	
	var offset_indices := PackedInt32Array()
	offset_indices.resize(tunnel_geom.indices.size())
	for i in range(tunnel_geom.indices.size()):
		offset_indices[i] = tunnel_geom.indices[i] + base_vertex_idx
	
	context.add_triangles(offset_indices)
	
#	_create_entrance_portal(entry, base_vertex_idx, displaced_vertices, context)
	
	return true


## Generate cylindrical tunnel geometry.
func _generate_tunnel_geometry(entry_pos: Vector3, direction: Vector3) -> Dictionary:
	var positions := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	
	var forward := direction.normalized()
	var up := Vector3.UP
	if abs(forward.dot(up)) > 0.99:
		up = Vector3.RIGHT
	
	var right := forward.cross(up).normalized()
	up = right.cross(forward).normalized()
	
	var vertex_count := (tunnel_segments + 1) * (tunnel_depth_segments + 1)
	positions.resize(vertex_count)
	uvs.resize(vertex_count)
	
	var v_idx := 0
	for depth_slice in range(tunnel_depth_segments + 1):
		var t := float(depth_slice) / tunnel_depth_segments
		var slice_center := entry_pos + forward * (tunnel_length * t)
		
		for segment in range(tunnel_segments + 1):
			var angle := (float(segment) / tunnel_segments) * TAU
			var x := cos(angle) * tunnel_radius
			var y := sin(angle) * tunnel_radius
			
			# Position on cylinder
			var offset := right * x + up * y
			positions[v_idx] = slice_center + offset
			
			# UV coordinates (cylindrical unwrap)
			uvs[v_idx] = Vector2(float(segment) / tunnel_segments, t)
			
			v_idx += 1
	
	# Generate cylinder triangles (INVERTED for interior faces)
	for depth in range(tunnel_depth_segments):
		for seg in range(tunnel_segments):
			var i0 := depth * (tunnel_segments + 1) + seg
			var i1 := i0 + 1
			var i2 := i0 + (tunnel_segments + 1)
			var i3 := i2 + 1
			
			# Inverted winding order (clockwise) for interior faces
			indices.append(i0)
			indices.append(i2)
			indices.append(i1)
			
			indices.append(i1)
			indices.append(i2)
			indices.append(i3)
	
	return {
		"positions": positions,
		"uvs": uvs,
		"indices": indices
	}


## Remove terrain triangles that are inside the tunnel cylinder.
func _remove_terrain_triangles_in_tunnel(entry_pos: Vector3, direction: Vector3, context: MeshModifierContext) -> int:
	var forward := direction.normalized()
	
	# Create filter function that checks if triangle is inside tunnel cylinder
	var filter := func(v0: Vector3, v1: Vector3, v2: Vector3) -> bool:
		# Get triangle centroid
		var centroid := (v0 + v1 + v2) / 3.0
		
		# Check if centroid is inside the tunnel cylinder
		var to_point := centroid - entry_pos
		var projection_length := to_point.dot(forward)
		
		# Check if point is within length bounds
		if projection_length < 0.0 or projection_length > tunnel_length:
			return false
		
		# Check radial distance from cylinder axis
		var projection_point := entry_pos + forward * projection_length
		var radial_distance := centroid.distance_to(projection_point)
		
		return radial_distance < tunnel_radius
	
	return context.remove_triangles_if(filter)


## Check if a point is inside the tunnel cylinder.
func _is_point_in_tunnel_cylinder(point: Vector3, cylinder_start: Vector3, cylinder_dir: Vector3, cylinder_length: float, cylinder_radius: float) -> bool:
	var to_point := point - cylinder_start
	var projection_length := to_point.dot(cylinder_dir)
	
	# Check if point is within length bounds
	if projection_length < 0.0 or projection_length > cylinder_length:
		return false
	
	# Check radial distance from cylinder axis
	var projection_point := cylinder_start + cylinder_dir * projection_length
	var radial_distance := point.distance_to(projection_point)
	
	return radial_distance < cylinder_radius


## Displace vertices near the tunnel entrance to create smooth transition.
func _displace_vertices_to_tunnel_wall(entry_pos: Vector3, direction: Vector3, context: MeshModifierContext) -> PackedInt32Array:
	var forward := direction.normalized()
	var vertices := context.get_vertex_array()
	var displaced_vertices := PackedInt32Array()
	
	# Find vertices near the tunnel entrance (within 2x radius)
	var search_radius := tunnel_radius * 2.0
	var entry_pos_2d := Vector2(entry_pos.x, entry_pos.z)
	var nearest_vertex := context.find_nearest_vertex(entry_pos_2d)
	
	if nearest_vertex < 0:
		return displaced_vertices
	
	# Get vertices in the neighborhood
	var search_distance := context.scale_to_grid(search_radius)
	var nearby_vertices := context.get_neighbours_chebyshev(nearest_vertex, search_distance)
	
	# Displace vertices that are close to the tunnel
	for vertex_idx in nearby_vertices:
		if not context.is_surface_vertex(vertex_idx):
			continue
		
		var vertex_pos := vertices[vertex_idx]
		var to_vertex := vertex_pos - entry_pos
		var projection_length := to_vertex.dot(forward)
		
		# Only displace vertices within tunnel length and near entrance
		if projection_length < 0.0 or projection_length > tunnel_length * 0.3:
			continue
		
		var projection_point := entry_pos + forward * projection_length
		var radial_offset := vertex_pos - projection_point
		var radial_distance := radial_offset.length()
		
		# Displace vertices inside or very close to the tunnel
		if radial_distance < tunnel_radius * 1.2:
			var falloff: float = clamp(1.0 - (projection_length / (tunnel_length * 0.3)), 0.0, 1.0)
			
			# Push vertex to tunnel wall
			var target_radial_distance := tunnel_radius * 1.05  # Slightly outside wall
			if radial_distance > 0.001:
				var displacement: Vector3 = radial_offset.normalized() * (target_radial_distance - radial_distance) * falloff
				var new_pos := vertex_pos + displacement
				context.set_vertex_position(vertex_idx, new_pos)
				displaced_vertices.append(vertex_idx)
	
	return displaced_vertices


## Create entrance portal connecting terrain to tunnel.
func _create_entrance_portal(entry: Dictionary, tunnel_base_idx: int, displaced_vertices: PackedInt32Array, context: MeshModifierContext) -> void:
	var entry_pos: Vector3 = entry.position
	
	# Find nearest vertex to entry position
	var entry_pos_2d := Vector2(entry_pos.x, entry_pos.z)
	var entry_vertex_idx := context.find_nearest_vertex(entry_pos_2d)
	
	if entry_vertex_idx < 0:
		return  # No valid vertex found
	
	# Connect the first ring of tunnel vertices to displaced terrain vertices
	# This creates a smooth transition from terrain to tunnel interior
	
	# First ring of tunnel vertices (indices 0 to tunnel_segments)
	for seg in range(tunnel_segments):
		var t0 := tunnel_base_idx + seg
		var t1 := tunnel_base_idx + seg + 1
		
		# Create triangle fan from entry point to tunnel ring
		context.add_triangle(entry_vertex_idx, t0, t1)


## Get metadata about this agent.
func get_metadata() -> Dictionary:
	var base := super.get_metadata()
	base["tunnel_radius"] = tunnel_radius
	base["tunnel_length"] = tunnel_length
	base["tunnel_segments"] = tunnel_segments
	return base
