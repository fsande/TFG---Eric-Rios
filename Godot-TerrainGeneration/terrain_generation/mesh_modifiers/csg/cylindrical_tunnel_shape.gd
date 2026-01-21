## @brief Cylindrical tunnel shape implementation.
##
## @details Implements TunnelShape interface for cylindrical tunnels.
## Maintains backward compatibility with CylinderVolume for CSG operations.
## Adds tunnel-specific capabilities: interior mesh generation and collision shapes.
##
## Design Pattern: Strategy Pattern - Concrete strategy for cylindrical tunnels.
@tool
class_name CylindricalTunnelShape extends TunnelShape

## Center point of the cylinder base (tunnel entrance)
var origin: Vector3

## Direction vector of the cylinder axis (normalized, tunnel direction)
var direction: Vector3

## Radius of the cylinder (tunnel width)
var radius: float

## Length of the cylinder along its axis (tunnel depth)
var length: float

## Number of radial segments for interior mesh generation
@export var radial_segments: int = 16

## Number of length segments for interior mesh generation
@export var length_segments: int = 8

## Construct a cylindrical tunnel shape
func _init(p_origin: Vector3, p_direction: Vector3, p_radius: float, p_length: float) -> void:
	origin = p_origin
	direction = p_direction.normalized()
	radius = p_radius
	length = p_length

## Returns signed distance from point to cylinder surface (CSGVolume interface)
## Negative inside, positive outside
func signed_distance(point: Vector3) -> float:
	# Vector from cylinder origin to point
	var to_point := point - origin
	
	# Project onto cylinder axis to get distance along axis
	var axis_distance := to_point.dot(direction)
	
	# Get perpendicular component (distance from axis)
	var axis_point := origin + direction * axis_distance
	var radial_distance := point.distance_to(axis_point)
	
	# Calculate signed distance to cylinder surface
	var radial_sd := radial_distance - radius
	
	# Calculate signed distance to end caps
	var cap_sd: float = max(-axis_distance, axis_distance - length)
	
	# Combine: inside when both are negative
	if radial_sd < 0.0 and cap_sd < 0.0:
		# Inside cylinder - return largest negative value
		return max(radial_sd, cap_sd)
	else:
		# Outside cylinder - return distance to nearest surface
		return sqrt(max(radial_sd, 0.0) ** 2 + max(cap_sd, 0.0) ** 2)


## Generate interior mesh for cylindrical tunnel (TunnelShape interface)
func generate_interior_mesh(terrain_height_query: Callable) -> MeshData:
	var mesh_data := MeshData.new()
	var basis := _create_tunnel_basis()
	var right := basis.x
	var up := basis.y
	var ring_count := length_segments + 1
	var verts_per_ring := radial_segments
	
	# Track which rings actually got created
	var created_rings: Array[bool] = []
	created_rings.resize(ring_count)
	
	for ring_idx in range(ring_count):
		var t := float(ring_idx) / float(length_segments)
		var ring_center := origin + direction * (t * length)
		
		# Check if this ring is underground
		var terrain_height: float = terrain_height_query.call(Vector2(ring_center.x, ring_center.z))
		var is_underground := ring_center.y < terrain_height
		
		created_rings[ring_idx] = is_underground
		
		if not is_underground:
			continue
		
		for seg_idx in range(radial_segments):
			var angle := (float(seg_idx) / float(radial_segments)) * TAU
			var cos_angle := cos(angle)
			var sin_angle := sin(angle)
			var offset := right * cos_angle * radius + up * sin_angle * radius
			var vertex_pos := ring_center + offset
			var uv := Vector2(float(seg_idx) / float(radial_segments), t)
			mesh_data.vertices.append(vertex_pos)
			mesh_data.uvs.append(uv)
	
	# Generate indices only between consecutive underground rings
	var vertex_ring_index := 0
	for ring_idx in range(ring_count - 1):
		if not created_rings[ring_idx] or not created_rings[ring_idx + 1]:
			continue
			
		var ring_base := vertex_ring_index * verts_per_ring
		var next_ring_base := (vertex_ring_index + 1) * verts_per_ring
		
		for seg_idx in range(radial_segments):
			var next_seg := (seg_idx + 1) % radial_segments
			var v0 := ring_base + seg_idx
			var v1 := ring_base + next_seg
			var v2 := next_ring_base + seg_idx
			var v3 := next_ring_base + next_seg
			
			# First triangle
			mesh_data.indices.append(v0)
			mesh_data.indices.append(v2)
			mesh_data.indices.append(v1)
			
			# Second triangle
			mesh_data.indices.append(v1)
			mesh_data.indices.append(v2)
			mesh_data.indices.append(v3)
		
		vertex_ring_index += 1
	return mesh_data

## Get collision shape for cylindrical tunnel (TunnelShape interface)
func get_collision_shape() -> Shape3D:
	# For Phase 1, return a simple CapsuleShape3D
	# Phase 2 will implement proper ConcavePolygonShape3D from mesh
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = length
	return capsule

## Get debug mesh representation as a cylinder (CSGVolume interface)
func get_debug_mesh() -> Array:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 16
	mesh.rings = 1
	var up := Vector3.UP
	var basis := Basis()
	if abs(direction.dot(up)) < 0.999:
		var rotation_axis := up.cross(direction).normalized()
		var rotation_angle := up.angle_to(direction)
		basis = Basis(rotation_axis, rotation_angle)
	else:
		if direction.dot(up) < 0:
			basis = Basis(Vector3.RIGHT, PI)
	var center_pos := origin + direction * (length * 0.5)
	var transform := Transform3D(basis, center_pos)
	return [mesh, transform]

## Get tunnel origin (TunnelShape interface)
func get_origin() -> Vector3:
	return origin

## Get tunnel direction (TunnelShape interface)
func get_direction() -> Vector3:
	return direction

## Get tunnel length (TunnelShape interface)
func get_length() -> float:
	return length

## Get shape type identifier (TunnelShape interface)
func get_shape_type() -> String:
	return "Cylindrical"

## Get shape metadata (TunnelShape interface override)
func get_shape_metadata() -> Dictionary:
	var metadata := super.get_shape_metadata()
	metadata["radius"] = radius
	metadata["radial_segments"] = radial_segments
	metadata["length_segments"] = length_segments
	return metadata

## Create basis vectors for tunnel cross-section
## Used for generating ring vertices perpendicular to tunnel direction
func _create_tunnel_basis() -> Basis:
	var forward := direction
	var right := Vector3.ZERO
	var up := Vector3.ZERO
	# Find perpendicular vectors
	if abs(forward.y) < 0.999:
		# Use world up as reference
		right = Vector3.UP.cross(forward).normalized()
		up = forward.cross(right).normalized()
	else:
		# Tunnel is nearly vertical, use world right as reference
		right = forward.cross(Vector3.RIGHT).normalized()
		up = forward.cross(right).normalized()
	return Basis(right, up, forward)
