## @brief Volume definition for tunnel/cave carving.
##
## @details Defines a tunnel as a path with varying radius.
## ADDITIVE: generates the visible interior tube mesh added during chunk generation.
@tool
class_name TunnelVolumeDefinition extends VolumeDefinition

## Cross-section shapes for tunnels.
enum CrossSectionType {
	CIRCLE,
	ARCH,
	RECTANGLE,
	NATURAL
}

## The path the tunnel follows (centerline).
var path: Curve3D = null

## Radius multiplier curve along normalized path length (0-1).
## If null, uses constant base_radius.
var radius_curve: Curve = null

## Base radius when radius_curve is not set.
var base_radius: float = 3.0

var cross_section: CrossSectionType = CrossSectionType.CIRCLE
var radial_segments: int = 12
var length_segments: int = 16
var entry_point: Vector3 = Vector3.ZERO
var entry_direction: Vector3 = Vector3.FORWARD

func _init() -> void:
	volume_type = VolumeType.ADDITIVE
	creation_timestamp = Time.get_unix_time_from_system()

## Check if a point is inside the tunnel volume (cross-section aware).
func point_is_inside(point: Vector3) -> bool:
	if not path or path.point_count < 2:
		return false
	var baked_length := path.get_baked_length()
	if baked_length <= 0.0:
		return false
	var closest_offset := path.get_closest_offset(point)
	var closest_point := path.sample_baked(closest_offset)
	var t := closest_offset / baked_length
	var radius := _get_radius_at(t)
	var forward := _get_path_direction_at(closest_offset, baked_length)
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = forward.cross(Vector3.FORWARD).normalized()
	var up := right.cross(forward).normalized()
	var local := point - closest_point
	var local_2d := Vector2(local.dot(right), local.dot(up))
	return _point_in_cross_section(local_2d, radius)

## Generate the additive tube mesh for this chunk.
func generate_mesh(chunk_bounds: AABB, resolution: int) -> MeshData:
	if not path or path.point_count < 2:
		return null
	if not intersects_chunk(chunk_bounds):
		return null
	var path_length := path.get_baked_length()
	if path_length <= 0.0:
		return null
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var actual_length_segs := maxi(length_segments * resolution / 64, 4)
	var actual_radial_segs := maxi(radial_segments * resolution / 64, 4)
	for i in range(actual_length_segs + 1):
		var t := float(i) / float(actual_length_segs)
		var offset := t * path_length
		var center := path.sample_baked(offset)
		var radius := _get_radius_at(t)
		var forward := _get_path_direction_at(offset, path_length)
		var right := forward.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.01:
			right = forward.cross(Vector3.FORWARD).normalized()
		var up := right.cross(forward).normalized()
		for j in range(actual_radial_segs):
			var angle := float(j) / float(actual_radial_segs) * TAU
			var local_pos := _get_cross_section_point(angle, radius)
			vertices.append(center + right * local_pos.x + up * local_pos.y)
			uvs.append(Vector2(float(j) / float(actual_radial_segs), t))
	for i in range(actual_length_segs):
		for j in range(actual_radial_segs):
			var current := i * actual_radial_segs + j
			var next_j := (j + 1) % actual_radial_segs
			var next_ring_offset := (i + 1) * actual_radial_segs
			indices.append(current)
			indices.append(current + actual_radial_segs)
			indices.append(next_ring_offset + next_j)
			indices.append(current)
			indices.append(next_ring_offset + next_j)
			indices.append(i * actual_radial_segs + next_j)
	_add_end_cap(vertices, indices, uvs, 0, actual_radial_segs, true)
	_add_end_cap(vertices, indices, uvs, actual_length_segs * actual_radial_segs, actual_radial_segs, false)
	return MeshData.create(vertices, indices, uvs)

func update_bounds() -> void:
	if not path or path.point_count < 2:
		bounds = AABB()
		return
	var min_point := Vector3(INF, INF, INF)
	var max_point := Vector3(-INF, -INF, -INF)
	var max_radius := base_radius
	if radius_curve:
		for i in range(100):
			max_radius = maxf(max_radius, radius_curve.sample(float(i) / 99.0) * base_radius)
	var path_length := path.get_baked_length()
	var sample_count := path.point_count * 10
	for i in range(sample_count):
		var t := float(i) / float(sample_count - 1)
		var point := path.sample_baked(t * path_length)
		min_point = min_point.min(point - Vector3.ONE * max_radius)
		max_point = max_point.max(point + Vector3.ONE * max_radius)
	bounds = AABB(min_point, max_point - min_point)

func get_memory_usage() -> int:
	var usage := 512
	if path:
		usage += path.point_count * 48
	if radius_curve:
		usage += 256
	return usage

func _get_radius_at(t: float) -> float:
	if radius_curve:
		return radius_curve.sample(t) * base_radius
	return base_radius

func _get_path_direction_at(offset: float, path_length: float) -> Vector3:
	var epsilon := minf(1.0, path_length * 0.01)
	var p1 := path.sample_baked(maxf(0.0, offset - epsilon))
	var p2 := path.sample_baked(minf(path_length, offset + epsilon))
	return (p2 - p1).normalized()

func _point_in_cross_section(local: Vector2, radius: float) -> bool:
	var r_sq := radius * radius
	match cross_section:
		CrossSectionType.CIRCLE:
			return local.length_squared() <= r_sq
		CrossSectionType.ARCH:
			return local.y >= -radius * 0.5 and local.length_squared() <= r_sq
		CrossSectionType.RECTANGLE:
			var half := radius * 0.8
			return abs(local.x) <= half and abs(local.y) <= half
		CrossSectionType.NATURAL:
			var variation := 0.7 + 0.3 * sin(atan2(local.y, local.x) * 3.0)
			return local.length_squared() <= (radius * variation) * (radius * variation)
		_:
			return local.length_squared() <= r_sq

func _get_cross_section_point(angle: float, radius: float) -> Vector2:
	match cross_section:
		CrossSectionType.CIRCLE:
			return Vector2(cos(angle), sin(angle)) * radius
		CrossSectionType.ARCH:
			if angle > PI:
				return Vector2(cos(angle) * radius, -radius * 0.5)
			return Vector2(cos(angle), sin(angle) * 0.5 + 0.5) * radius
		CrossSectionType.RECTANGLE:
			return Vector2(sign(cos(angle)) * radius * 0.8, sign(sin(angle)) * radius * 0.8)
		CrossSectionType.NATURAL:
			var variation := 0.7 + 0.3 * sin(angle * 3.0) * cos(angle * 2.0)
			return Vector2(cos(angle), sin(angle)) * radius * variation
		_:
			return Vector2(cos(angle), sin(angle)) * radius

func _add_end_cap(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	ring_start: int,
	num_radial_segs: int,
	is_start: bool
) -> void:
	var cap_center := Vector3.ZERO
	for i in range(num_radial_segs):
		cap_center += vertices[ring_start + i]
	cap_center /= float(num_radial_segs)
	var center_idx := vertices.size()
	vertices.append(cap_center)
	uvs.append(Vector2(0.5, 0.5))
	for i in range(num_radial_segs):
		var next_i := (i + 1) % num_radial_segs
		if is_start:
			indices.append(center_idx)
			indices.append(ring_start + next_i)
			indices.append(ring_start + i)
		else:
			indices.append(center_idx)
			indices.append(ring_start + i)
			indices.append(ring_start + next_i)
