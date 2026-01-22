## @brief Spline-based curved tunnel shape following a Curve3D path.
@tool
class_name SplineTunnelShape extends TunnelShape

var path_curve: Curve3D
var radius: float
var radial_segments: int = 16
var path_segments: int = 50
var _baked_points: PackedVector3Array
var _baked_up_vectors: PackedVector3Array

func _init(p_path_curve: Curve3D, p_radius: float) -> void:
	path_curve = p_path_curve
	radius = p_radius
	_bake_path()

func _bake_path() -> void:
	if not path_curve or path_curve.point_count < 2:
		return
	_baked_points = path_curve.get_baked_points()
	_baked_up_vectors.resize(_baked_points.size())
	for i in range(_baked_points.size()):
		var t := float(i) / float(_baked_points.size() - 1)
		var tangent := path_curve.sample_baked_up_vector(t * path_curve.get_baked_length())
		_baked_up_vectors[i] = tangent if tangent.length() > 0.01 else Vector3.UP

func signed_distance(point: Vector3) -> float:
	if not path_curve or _baked_points.size() < 2:
		return 999999.0
	var min_dist := INF
	for i in range(_baked_points.size()):
		var spline_point := _baked_points[i]
		var dist_to_axis := point.distance_to(spline_point)
		var sd := dist_to_axis - radius
		min_dist = min(min_dist, sd)
	return min_dist

func generate_interior_mesh(terrain_querier: TerrainHeightQuerier) -> MeshData:
	var mesh_data := MeshData.new()
	if not path_curve or path_curve.point_count < 2:
		push_error("SplineTunnelShape: Invalid path curve")
		return mesh_data
	var curve_length := path_curve.get_baked_length()
	var segment_count := path_segments
	var verts_per_ring := radial_segments + 1
	for seg_idx in range(segment_count + 1):
		var t := float(seg_idx) / float(segment_count)
		var distance := t * curve_length
		var position := path_curve.sample_baked(distance)
		var tangent := _get_tangent_at(distance, curve_length)
		var basis := _create_basis_at_point(tangent)
		var right := basis.x
		var up := basis.y
		for circ_idx in range(verts_per_ring):
			var actual_seg := circ_idx % radial_segments
			var angle := (float(actual_seg) / float(radial_segments)) * TAU
			var cos_angle := cos(angle)
			var sin_angle := sin(angle)
			var offset := right * cos_angle * radius + up * sin_angle * radius
			var vertex_pos := position + offset
			var uv := Vector2(float(circ_idx) / float(radial_segments), t)
			mesh_data.vertices.append(vertex_pos)
			mesh_data.uvs.append(uv)
	for seg_idx in range(segment_count):
		var ring_base := seg_idx * verts_per_ring
		var next_ring_base := (seg_idx + 1) * verts_per_ring
		for circ_idx in range(radial_segments):
			var v0 := ring_base + circ_idx
			var v1 := ring_base + circ_idx + 1
			var v2 := next_ring_base + circ_idx
			var v3 := next_ring_base + circ_idx + 1
			mesh_data.indices.append(v0)
			mesh_data.indices.append(v1)
			mesh_data.indices.append(v2)
			mesh_data.indices.append(v1)
			mesh_data.indices.append(v3)
			mesh_data.indices.append(v2)
	return mesh_data

func get_debug_mesh() -> Array:
	if not path_curve or path_curve.point_count < 2:
		return [CylinderMesh.new(), Transform3D.IDENTITY]
	var path := Path3D.new()
	path.curve = path_curve
	var tube_mesh := TubeTrailMesh.new()
	tube_mesh.radius = radius
	tube_mesh.radial_steps = 8
	tube_mesh.section_length = 0.2
	tube_mesh.sections = int(path_curve.get_baked_length() / 0.2)
	return [tube_mesh, Transform3D.IDENTITY]

func get_origin() -> Vector3:
	if path_curve and path_curve.point_count > 0:
		return path_curve.get_point_position(0)
	return Vector3.ZERO

func get_direction() -> Vector3:
	if path_curve and path_curve.point_count > 1:
		var start := path_curve.get_point_position(0)
		var next := path_curve.get_point_position(1)
		return (next - start).normalized()
	return Vector3.FORWARD

func get_length() -> float:
	if path_curve:
		return path_curve.get_baked_length()
	return 0.0

func get_shape_type() -> String:
	return "Spline"

func get_shape_metadata() -> Dictionary:
	var metadata := super.get_shape_metadata()
	metadata["radius"] = radius
	metadata["radial_segments"] = radial_segments
	metadata["path_segments"] = path_segments
	metadata["curve_points"] = path_curve.point_count if path_curve else 0
	return metadata

func _get_tangent_at(distance: float, curve_length: float) -> Vector3:
	var epsilon := 0.01
	var d1: float = clamp(distance - epsilon, 0.0, curve_length)
	var d2: float = clamp(distance + epsilon, 0.0, curve_length)
	var p1 := path_curve.sample_baked(d1)
	var p2 := path_curve.sample_baked(d2)
	var tangent := (p2 - p1).normalized()
	return tangent if tangent.length() > 0.01 else Vector3.FORWARD

func _create_basis_at_point(tangent: Vector3) -> Basis:
	var forward := tangent.normalized()
	var right := Vector3.ZERO
	var up := Vector3.ZERO
	if abs(forward.y) < 0.999:
		right = Vector3.UP.cross(forward).normalized()
		up = forward.cross(right).normalized()
	else:
		right = forward.cross(Vector3.RIGHT).normalized()
		up = forward.cross(right).normalized()
	return Basis(right, up, forward)

