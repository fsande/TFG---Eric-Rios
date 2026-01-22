## @brief Natural cave-like tunnel shape with procedural noise variation.
@tool
class_name NaturalCaveTunnelShape extends TunnelShape

var origin: Vector3
var direction: Vector3
var base_radius: float
var radius_variation: float
var length: float
var noise: FastNoiseLite
var radial_segments: int = 24
var length_segments: int = 30

func _init(p_origin: Vector3, p_direction: Vector3, p_base_radius: float, p_radius_variation: float, p_length: float, p_noise_seed: int, p_noise_frequency: float) -> void:
	origin = p_origin
	direction = p_direction.normalized()
	base_radius = p_base_radius
	radius_variation = p_radius_variation
	length = p_length
	noise = FastNoiseLite.new()
	noise.seed = p_noise_seed
	noise.frequency = p_noise_frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

func signed_distance(point: Vector3) -> float:
	var to_point := point - origin
	var axis_distance := to_point.dot(direction)
	if axis_distance < 0.0 or axis_distance > length:
		return axis_distance if axis_distance < 0.0 else axis_distance - length
	var t := axis_distance / length
	var radius_at_t := _get_radius_at_position(t)
	var axis_point := origin + direction * axis_distance
	var radial_distance := point.distance_to(axis_point)
	var radial_sd := radial_distance - radius_at_t
	var cap_sd: float = max(-axis_distance, axis_distance - length)
	if radial_sd < 0.0 and cap_sd < 0.0:
		return max(radial_sd, cap_sd)
	else:
		return sqrt(max(radial_sd, 0.0) ** 2 + max(cap_sd, 0.0) ** 2)

func generate_interior_mesh(terrain_querier: TerrainHeightQuerier) -> MeshData:
	var mesh_data := MeshData.new()
	var basis := _create_tunnel_basis()
	var right := basis.x
	var up := basis.y
	var ring_count := length_segments + 1
	var verts_per_ring := radial_segments + 1
	for ring_idx in range(ring_count):
		var t := float(ring_idx) / float(length_segments)
		var ring_center := origin + direction * (t * length)
		var radius_at_t := _get_radius_at_position(t)
		for seg_idx in range(verts_per_ring):
			var actual_seg := seg_idx % radial_segments
			var angle := (float(actual_seg) / float(radial_segments)) * TAU
			var radial_noise := noise.get_noise_2d(t * 10.0, angle * 3.0) * 0.5 + 0.5
			var radial_offset := radius_at_t * (1.0 + radial_noise * 0.2 - 0.1)
			var cos_angle := cos(angle)
			var sin_angle := sin(angle)
			var offset := right * cos_angle * radial_offset + up * sin_angle * radial_offset
			var vertex_pos := ring_center + offset
			var uv := Vector2(float(seg_idx) / float(radial_segments), t)
			mesh_data.vertices.append(vertex_pos)
			mesh_data.uvs.append(uv)
	for ring_idx in range(ring_count - 1):
		var ring_base := ring_idx * verts_per_ring
		var next_ring_base := (ring_idx + 1) * verts_per_ring
		for seg_idx in range(radial_segments):
			var v0 := ring_base + seg_idx
			var v1 := ring_base + seg_idx + 1
			var v2 := next_ring_base + seg_idx
			var v3 := next_ring_base + seg_idx + 1
			mesh_data.indices.append(v0)
			mesh_data.indices.append(v1)
			mesh_data.indices.append(v2)
			mesh_data.indices.append(v1)
			mesh_data.indices.append(v3)
			mesh_data.indices.append(v2)
	return mesh_data

func get_debug_mesh() -> Array:
	var mesh := CylinderMesh.new()
	var avg_radius := base_radius * (1.0 + radius_variation * 0.5)
	mesh.top_radius = avg_radius
	mesh.bottom_radius = avg_radius
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

func get_origin() -> Vector3:
	return origin

func get_direction() -> Vector3:
	return direction

func get_length() -> float:
	return length

func get_shape_type() -> String:
	return "NaturalCave"

func get_shape_metadata() -> Dictionary:
	var metadata := super.get_shape_metadata()
	metadata["base_radius"] = base_radius
	metadata["radius_variation"] = radius_variation
	metadata["radial_segments"] = radial_segments
	metadata["length_segments"] = length_segments
	return metadata

func _get_radius_at_position(t: float) -> float:
	var noise_value := noise.get_noise_1d(t * 10.0)
	var variation := (noise_value * 0.5 + 0.5) * radius_variation
	return base_radius * (1.0 + variation - radius_variation * 0.5)

func _create_tunnel_basis() -> Basis:
	var forward := direction
	var right := Vector3.ZERO
	var up := Vector3.ZERO
	if abs(forward.y) < 0.999:
		right = Vector3.UP.cross(forward).normalized()
		up = forward.cross(right).normalized()
	else:
		right = forward.cross(Vector3.RIGHT).normalized()
		up = forward.cross(right).normalized()
	return Basis(right, up, forward)

