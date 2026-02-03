## @brief Volume definition for tunnel/cave carving.
##
## @details Defines a tunnel as a path with varying radius.
## Generates subtraction meshes for CSG operations during chunk generation.
@tool
class_name TunnelVolumeDefinition extends VolumeDefinition

## Cross-section shapes for tunnels
enum CrossSectionType {
	CIRCLE,    ## Circular cross-section
	ARCH,      ## Arch shape (flat bottom)
	RECTANGLE, ## Rectangular/square
	NATURAL    ## Irregular cave-like shape
}

## The path the tunnel follows (centerline)
@export var path: Curve3D = null

## Radius at each point along the path (0-1 maps to path length)
## If null, uses constant base_radius
@export var radius_curve: Curve = null

## Base radius when radius_curve is not set
@export var base_radius: float = 3.0

## Cross-section type
@export var cross_section: CrossSectionType = CrossSectionType.CIRCLE

## Number of radial segments for mesh generation
@export_range(4, 32) var radial_segments: int = 12

## Number of segments along the path length
@export_range(4, 64) var length_segments: int = 16

## Entry point position (for reference)
@export var entry_point: Vector3 = Vector3.ZERO

## Direction the tunnel goes at entry
@export var entry_direction: Vector3 = Vector3.FORWARD

func _init() -> void:
	volume_type = VolumeType.SUBTRACTIVE
	creation_timestamp = Time.get_unix_time_from_system()

## Check if a point is inside the tunnel volume.
func point_is_inside(point: Vector3) -> bool:
	if not path or path.point_count < 2:
		return false
	var closest_offset := path.get_closest_offset(point)
	var closest_point := path.sample_baked(closest_offset)
	var distance := point.distance_to(closest_point)
	var t := closest_offset / path.get_baked_length() if path.get_baked_length() > 0 else 0.0
	var radius := _get_radius_at(t)
	return distance <= radius

## Generate mesh for CSG subtraction.
func generate_mesh(chunk_bounds: AABB, resolution: int) -> MeshData:
	if not path or path.point_count < 2:
		return null
	if not intersects_chunk(chunk_bounds):
		return null
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var path_length := path.get_baked_length()
	if path_length <= 0:
		return null
	var actual_length_segments := maxi(length_segments * resolution / 64, 4)
	var actual_radial_segments := maxi(radial_segments * resolution / 64, 4)
	for i in range(actual_length_segments + 1):
		var t := float(i) / float(actual_length_segments)
		var offset := t * path_length
		var center := path.sample_baked(offset)
		var radius := _get_radius_at(t)
		var forward := _get_path_direction_at(offset, path_length)
		var right := forward.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.01:
			right = forward.cross(Vector3.FORWARD).normalized()
		var up := right.cross(forward).normalized()
		for j in range(actual_radial_segments):
			var angle := float(j) / float(actual_radial_segments) * TAU
			var local_pos := _get_cross_section_point(angle, radius)
			var world_pos := center + right * local_pos.x + up * local_pos.y
			vertices.append(world_pos)
			uvs.append(Vector2(float(j) / float(actual_radial_segments), t))
	for i in range(actual_length_segments):
		for j in range(actual_radial_segments):
			var current := i * actual_radial_segments + j
			var next_j := (j + 1) % actual_radial_segments
			var next_ring := (i + 1) * actual_radial_segments
			indices.append(current)
			indices.append(current + actual_radial_segments)
			indices.append(next_ring + next_j)
			indices.append(current)
			indices.append(next_ring + next_j)
			indices.append(i * actual_radial_segments + next_j)
	_add_end_cap(vertices, indices, uvs, 0, actual_radial_segments, true)
	_add_end_cap(vertices, indices, uvs, actual_length_segments * actual_radial_segments, actual_radial_segments, false)
	var mesh_data := MeshData.new(vertices, indices, uvs)
	return mesh_data

## Update bounds based on path and radius.
func update_bounds() -> void:
	if not path or path.point_count < 2:
		bounds = AABB()
		return
	var min_point := Vector3(INF, INF, INF)
	var max_point := Vector3(-INF, -INF, -INF)
	var max_radius := base_radius
	if radius_curve:
		for i in range(100):
			var t := float(i) / 99.0
			max_radius = maxf(max_radius, radius_curve.sample(t) * base_radius)
	var path_length := path.get_baked_length()
	for i in range(path.point_count * 10):
		var t := float(i) / float(path.point_count * 10 - 1)
		var point := path.sample_baked(t * path_length)
		min_point = min_point.min(point - Vector3.ONE * max_radius)
		max_point = max_point.max(point + Vector3.ONE * max_radius)
	bounds = AABB(min_point, max_point - min_point)

## Get radius at normalized path position.
func _get_radius_at(t: float) -> float:
	if radius_curve:
		return radius_curve.sample(t) * base_radius
	return base_radius

## Get path direction at offset.
func _get_path_direction_at(offset: float, path_length: float) -> Vector3:
	var epsilon := minf(1.0, path_length * 0.01)
	var p1 := path.sample_baked(maxf(0, offset - epsilon))
	var p2 := path.sample_baked(minf(path_length, offset + epsilon))
	return (p2 - p1).normalized()

## Get cross-section point for given angle and radius.
func _get_cross_section_point(angle: float, radius: float) -> Vector2:
	match cross_section:
		CrossSectionType.CIRCLE:
			return Vector2(cos(angle), sin(angle)) * radius
		CrossSectionType.ARCH:
			if angle > PI:
				var x := cos(angle) * radius
				return Vector2(x, -radius * 0.5)
			else:
				return Vector2(cos(angle), sin(angle) * 0.5 + 0.5) * radius
		CrossSectionType.RECTANGLE:
			var x: float = sign(cos(angle)) * radius * 0.8
			var y: float = sign(sin(angle)) * radius * 0.8
			return Vector2(x, y)
		CrossSectionType.NATURAL:
			var variation := 0.7 + 0.3 * sin(angle * 3.0) * cos(angle * 2.0)
			return Vector2(cos(angle), sin(angle)) * radius * variation
		_:
			return Vector2(cos(angle), sin(angle)) * radius

## Add end cap to close the tunnel mesh.
func _add_end_cap(
	vertices: PackedVector3Array, 
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	ring_start: int, 
	radial_segments: int, 
	is_start: bool
) -> void:
	var center := Vector3.ZERO
	for i in range(radial_segments):
		center += vertices[ring_start + i]
	center /= float(radial_segments)
	var center_idx := vertices.size()
	vertices.append(center)
	uvs.append(Vector2(0.5, 0.5))
	for i in range(radial_segments):
		var next_i := (i + 1) % radial_segments
		if is_start:
			indices.append(center_idx)
			indices.append(ring_start + next_i)
			indices.append(ring_start + i)
		else:
			indices.append(center_idx)
			indices.append(ring_start + i)
			indices.append(ring_start + next_i)

## Get memory usage estimate.
func get_memory_usage() -> int:
	var usage := 512
	if path:
		usage += path.point_count * 48 
	if radius_curve:
		usage += 256  
	return usage

