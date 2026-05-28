## @brief Additive volume that generates the interior cylinder mesh for a tunnel.
##
## @details Produces inward-facing normals so the tunnel walls are visible from
## inside. Mesh vertices are in world space; _apply_additive_volume will
## subtract chunk_center before appending to the chunk mesh.
@tool
class_name TunnelTubeVolume extends VolumeDefinition

## World-space start of the tunnel axis.
var start_point: Vector3

## World-space end of the tunnel axis.
var end_point: Vector3

## Tunnel radius.
var radius: float

## Radial segment count.
var radial_segments: int = 12

## Axial segment count.
var length_segments: int = 1

## Surface depth samples from the entrance cliff face, mirrored from TunnelEntranceVolume.
## When set, ring 0 vertices are offset along the tunnel axis to conform to the cliff.
var entry_surface_depths: PackedFloat32Array

func _init() -> void:
	volume_type = VolumeType.ADDITIVE
	creation_timestamp = Time.get_unix_time_from_system()

func point_is_inside(point: Vector3) -> bool:
	var axis := end_point - start_point
	var axis_len_sq := axis.length_squared()
	if axis_len_sq < 1e-9:
		return false
	var t := clampf((point - start_point).dot(axis) / axis_len_sq, 0.0, 1.0)
	var closest := start_point + axis * t
	return point.distance_squared_to(closest) <= radius * radius

func generate_mesh(_chunk_bounds: AABB, _resolution: int) -> MeshData:
	var axis := end_point - start_point
	var tube_length := axis.length()
	if tube_length < 1e-6:
		return null
	var forward := axis / tube_length
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = forward.cross(Vector3.FORWARD).normalized()
	var up := right.cross(forward).normalized()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rings := length_segments + 1
	for i in range(rings):
		var t := float(i) / float(length_segments)
		var ring_center := start_point + forward * (t * tube_length)
		for j in range(radial_segments + 1):
			var angle := float(j) / float(radial_segments) * TAU
			var cos_a := cos(angle)
			var sin_a := sin(angle)
			var outward := right * cos_a + up * sin_a
			var pos := ring_center + outward * radius
			if i == 0 and not entry_surface_depths.is_empty():
				pos += forward * _sample_entry_depth(atan2(sin_a, cos_a))
			vertices.append(pos)
			normals.append(-outward)
			uvs.append(Vector2(float(j) / float(radial_segments), t))
	var verts_per_ring := radial_segments + 1
	for i in range(length_segments):
		for j in range(radial_segments):
			var a := i * verts_per_ring + j
			var b := i * verts_per_ring + j + 1
			var c := (i + 1) * verts_per_ring + j
			var d := (i + 1) * verts_per_ring + j + 1
			indices.append(a); indices.append(c); indices.append(b)
			indices.append(b); indices.append(c); indices.append(d)
	var single_side_count := indices.size()
	for idx in range(0, single_side_count, 3):
		indices.append(indices[idx])
		indices.append(indices[idx + 2])
		indices.append(indices[idx + 1])
	_add_end_cap(vertices, normals, uvs, indices, true)  
	var mesh := MeshData.create(vertices, indices, uvs)
	mesh.cached_normals = normals
	return mesh

func update_bounds() -> void:
	var extents := Vector3.ONE * radius
	var min_p := start_point.min(end_point) - extents
	var max_p := start_point.max(end_point) + extents
	bounds = AABB(min_p, max_p - min_p)

## Interpolates entry_surface_depths at the given angle (radians, atan2 range).
func _sample_entry_depth(angle: float) -> float:
	if entry_surface_depths.is_empty():
		return 0.0
	var n := entry_surface_depths.size()
	var t := fmod(angle + TAU * 2.0, TAU) / TAU * float(n)
	var i0 := int(t) % n
	var i1 := (i0 + 1) % n
	return lerpf(entry_surface_depths[i0], entry_surface_depths[i1], t - floor(t))

## Adds a flat disc cap at one end of the tube.
func _add_end_cap(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	is_end: bool
) -> void:
	var axis := (end_point - start_point).normalized()
	var cap_center := end_point if is_end else start_point
	var cap_normal := axis if is_end else -axis
	var right := axis.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = axis.cross(Vector3.FORWARD).normalized()
	var up := right.cross(axis).normalized()
	var center_idx := vertices.size()
	vertices.append(cap_center)
	normals.append(cap_normal)
	uvs.append(Vector2(0.5, 0.5))
	var rim_start := vertices.size()
	for j in range(radial_segments):
		var angle := float(j) / float(radial_segments) * TAU
		var offset := right * cos(angle) + up * sin(angle)
		vertices.append(cap_center + offset * radius)
		normals.append(cap_normal)
		uvs.append(Vector2(0.5 + cos(angle) * 0.5, 0.5 + sin(angle) * 0.5))
	for j in range(radial_segments):
		var curr := rim_start + j
		var next := rim_start + (j + 1) % radial_segments
		if is_end:
			indices.append(center_idx); indices.append(next); indices.append(curr)
		else:
			indices.append(center_idx); indices.append(curr); indices.append(next)
