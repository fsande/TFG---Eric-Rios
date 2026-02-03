## @brief Volume definition for overhangs and additive geometry.
##
## @details Defines geometry that protrudes from the terrain surface,
## such as cliff overhangs, rock formations, or arches.
@tool
class_name OverhangVolumeDefinition extends VolumeDefinition

## The world position where the overhang attaches to terrain
@export var attachment_point: Vector3 = Vector3.ZERO

## Direction the overhang extends (normalized)
@export var overhang_direction: Vector3 = Vector3(-1, 0.2, 0).normalized()

## How far the overhang extends
@export var extent: float = 5.0

## Width of the overhang perpendicular to direction
@export var width: float = 8.0

## Thickness of the overhang
@export var thickness: float = 2.0

## Profile curve for the overhang shape (optional)
## X axis = distance along extent (0-1), Y axis = thickness multiplier
@export var profile_curve: Curve = null

## Segments for mesh generation
@export_range(2, 16) var length_segments: int = 6
@export_range(2, 16) var width_segments: int = 4

## Noise variation for natural look
@export var noise_strength: float = 0.2
@export var noise_seed: int = 0

func _init() -> void:
	volume_type = VolumeType.ADDITIVE
	creation_timestamp = Time.get_unix_time_from_system()

## Check if a point is inside the overhang volume.
func point_is_inside(point: Vector3) -> bool:
	var local := _world_to_local(point)
	if local.x < 0 or local.x > extent:
		return false
	if abs(local.z) > width / 2.0:
		return false
	var t := local.x / extent
	var local_thickness := _get_thickness_at(t)
	return abs(local.y) <= local_thickness / 2.0

## Generate mesh for the overhang.
func generate_mesh(chunk_bounds: AABB, resolution: int) -> MeshData:
	if not intersects_chunk(chunk_bounds):
		return null
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var forward := overhang_direction.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var actual_length_segs := maxi(length_segments * resolution / 32, 2)
	var actual_width_segs := maxi(width_segments * resolution / 32, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	var top_start := 0
	for i in range(actual_length_segs + 1):
		var t := float(i) / float(actual_length_segs)
		var local_thickness := _get_thickness_at(t)
		for j in range(actual_width_segs + 1):
			var s := float(j) / float(actual_width_segs) - 0.5
			var local_pos := forward * (t * extent) + right * (s * width)
			local_pos.y = local_thickness / 2.0
			if noise_strength > 0:
				local_pos += Vector3(
					rng.randf_range(-1, 1),
					rng.randf_range(-1, 1),
					rng.randf_range(-1, 1)
				) * noise_strength * (1.0 - t * 0.5) 
			var world_pos := attachment_point + local_pos.x * forward + local_pos.y * up + local_pos.z * right
			vertices.append(world_pos)
			uvs.append(Vector2(t, s + 0.5))
	var bottom_start := vertices.size()
	for i in range(actual_length_segs + 1):
		var t := float(i) / float(actual_length_segs)
		var local_thickness := _get_thickness_at(t)
		for j in range(actual_width_segs + 1):
			var s := float(j) / float(actual_width_segs) - 0.5
			var local_pos := forward * (t * extent) + right * (s * width)
			local_pos.y = -local_thickness / 2.0
			if noise_strength > 0:
				local_pos += Vector3(
					rng.randf_range(-1, 1),
					rng.randf_range(-1, 1),
					rng.randf_range(-1, 1)
				) * noise_strength * (1.0 - t * 0.5)
			var world_pos := attachment_point + local_pos.x * forward + local_pos.y * up + local_pos.z * right
			vertices.append(world_pos)
			uvs.append(Vector2(t, s + 0.5))
	for i in range(actual_length_segs):
		for j in range(actual_width_segs):
			var v0 := top_start + i * (actual_width_segs + 1) + j
			var v1 := v0 + 1
			var v2 := v0 + actual_width_segs + 1
			var v3 := v2 + 1
			indices.append(v0)
			indices.append(v2)
			indices.append(v1)
			indices.append(v1)
			indices.append(v2)
			indices.append(v3)
	for i in range(actual_length_segs):
		for j in range(actual_width_segs):
			var v0 := bottom_start + i * (actual_width_segs + 1) + j
			var v1 := v0 + 1
			var v2 := v0 + actual_width_segs + 1
			var v3 := v2 + 1
			indices.append(v0)
			indices.append(v1)
			indices.append(v2)
			indices.append(v1)
			indices.append(v3)
			indices.append(v2)
	_add_side_edges(vertices, indices, uvs, top_start, bottom_start, actual_length_segs, actual_width_segs)
	var mesh_data := MeshData.new(vertices, indices, uvs)
	return mesh_data


## Update bounds based on parameters.
func update_bounds() -> void:
	var forward := overhang_direction.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var corners: Array[Vector3] = []
	corners.append(attachment_point)
	corners.append(attachment_point + forward * extent)
	corners.append(attachment_point + right * width / 2.0)
	corners.append(attachment_point - right * width / 2.0)
	corners.append(attachment_point + forward * extent + right * width / 2.0)
	corners.append(attachment_point + forward * extent - right * width / 2.0)
	var min_point := Vector3(INF, INF, INF)
	var max_point := Vector3(-INF, -INF, -INF)
	for corner in corners:
		min_point = min_point.min(corner - Vector3(0, thickness, 0))
		max_point = max_point.max(corner + Vector3(0, thickness, 0))
	var padding := Vector3(noise_strength, noise_strength, noise_strength) * 2
	bounds = AABB(min_point - padding, max_point - min_point + padding * 2)

## Get thickness at normalized position along extent.
func _get_thickness_at(t: float) -> float:
	if profile_curve:
		return profile_curve.sample(t) * thickness
	return thickness * (1.0 - t * 0.3)


## Transform world point to local overhang space.
func _world_to_local(point: Vector3) -> Vector3:
	var forward := overhang_direction.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var relative := point - attachment_point
	return Vector3(
		relative.dot(forward),
		relative.dot(up),
		relative.dot(right)
	)

## Add side edge geometry.
func _add_side_edges(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	top_start: int,
	bottom_start: int,
	length_segs: int,
	width_segs: int
) -> void:
	for i in range(length_segs):
		var top_v0 := top_start + i * (width_segs + 1)
		var top_v1 := top_start + (i + 1) * (width_segs + 1)
		var bot_v0 := bottom_start + i * (width_segs + 1)
		var bot_v1 := bottom_start + (i + 1) * (width_segs + 1)
		indices.append(top_v0)
		indices.append(bot_v0)
		indices.append(top_v1)
		indices.append(top_v1)
		indices.append(bot_v0)
		indices.append(bot_v1)
	for i in range(length_segs):
		var top_v0 := top_start + i * (width_segs + 1) + width_segs
		var top_v1 := top_start + (i + 1) * (width_segs + 1) + width_segs
		var bot_v0 := bottom_start + i * (width_segs + 1) + width_segs
		var bot_v1 := bottom_start + (i + 1) * (width_segs + 1) + width_segs
		indices.append(top_v0)
		indices.append(top_v1)
		indices.append(bot_v0)
		indices.append(top_v1)
		indices.append(bot_v1)
		indices.append(bot_v0)
	for j in range(width_segs):
		var top_v0 := top_start + length_segs * (width_segs + 1) + j
		var top_v1 := top_v0 + 1
		var bot_v0 := bottom_start + length_segs * (width_segs + 1) + j
		var bot_v1 := bot_v0 + 1
		indices.append(top_v0)
		indices.append(top_v1)
		indices.append(bot_v0)
		indices.append(top_v1)
		indices.append(bot_v1)
		indices.append(bot_v0)

## Get memory usage estimate.
func get_memory_usage() -> int:
	var usage := 512
	if profile_curve:
		usage += 256
	return usage

