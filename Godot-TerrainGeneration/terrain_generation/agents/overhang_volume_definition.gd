## @brief Volume definition for overhangs and additive geometry.
@tool
class_name OverhangVolumeDefinition extends VolumeDefinition

var attachment_point: Vector3 = Vector3.ZERO
var overhang_direction: Vector3 = Vector3(-1, 0, 0).normalized()
var extent: float = 5.0
var width: float = 8.0
var thickness: float = 2.0
var cliff_embed_depth: float = 3.0
var profile_curve: Curve = null
var length_segments: int = 6
var width_segments: int = 4
var noise_strength: float = 0.2
var noise_seed: int = 0
var noise_frequency: float = 0.15
var detail_noise_strength: float = 0.05

func _init() -> void:
	volume_type = VolumeType.ADDITIVE
	creation_timestamp = Time.get_unix_time_from_system()

func point_is_inside(point: Vector3) -> bool:
	var local := _world_to_local(point)
	if local.x < -cliff_embed_depth or local.x > extent:
		return false
	if abs(local.z) > width * 0.5:
		return false
	var t := clampf(local.x / extent, 0.0, 1.0)
	return abs(local.y) <= _get_thickness_at(t) * 0.5

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
	var total_length := extent + cliff_embed_depth
	var embed_origin := attachment_point - forward * cliff_embed_depth
	var rng := RandomNumberGenerator.new()
	var slab_pos := func(i: int, j: int, on_top: bool) -> Vector3:
		var t_total := float(i) / float(actual_length_segs)
		var dist_from_attach := t_total * total_length - cliff_embed_depth
		var t_profile := clampf(dist_from_attach / extent, 0.0, 1.0)
		var half_thick := _get_thickness_at(t_profile) * 0.5
		var s := float(j) / float(actual_width_segs) - 0.5
		var sign := 1.0 if on_top else -1.0
		var pos := (embed_origin
			+ forward * (t_total * total_length)
			+ right * (s * width)
			+ up * (half_thick * sign))
		if noise_strength > 0.0 and dist_from_attach > 0.0:
			var noise_rng := RandomNumberGenerator.new()
			noise_rng.seed = noise_seed ^ (i * 1000 + j)
			pos += Vector3(
				noise_rng.randf_range(-1.0, 1.0),
				noise_rng.randf_range(-1.0, 1.0),
				noise_rng.randf_range(-1.0, 1.0)
			) * noise_strength * (1.0 - t_profile * 0.5)
		return pos
	var top_start := 0
	rng.seed = noise_seed
	for i in range(actual_length_segs + 1):
		var t_total := float(i) / float(actual_length_segs)
		var dist_from_attach := t_total * total_length - cliff_embed_depth
		var t_profile := clampf(dist_from_attach / extent, 0.0, 1.0)
		var half_thick := _get_thickness_at(t_profile) * 0.5
		for j in range(actual_width_segs + 1):
			var s := float(j) / float(actual_width_segs) - 0.5
			var s_norm := float(j) / float(actual_width_segs)
			var world_pos := (embed_origin
				+ forward * (t_total * total_length)
				+ right * (s * width)
				+ up * half_thick)
			if noise_strength > 0.0 and dist_from_attach > 0.0:
				world_pos += Vector3(
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0)
				) * noise_strength * (1.0 - t_profile * 0.5)
			vertices.append(world_pos)
			uvs.append(Vector2(t_total, s_norm))
	var bottom_start := vertices.size()
	rng.seed = noise_seed
	for i in range(actual_length_segs + 1):
		var t_total := float(i) / float(actual_length_segs)
		var dist_from_attach := t_total * total_length - cliff_embed_depth
		var t_profile := clampf(dist_from_attach / extent, 0.0, 1.0)
		var half_thick := _get_thickness_at(t_profile) * 0.5
		for j in range(actual_width_segs + 1):
			var s := float(j) / float(actual_width_segs) - 0.5
			var s_norm := float(j) / float(actual_width_segs)
			var world_pos := (embed_origin
				+ forward * (t_total * total_length)
				+ right * (s * width)
				- up * half_thick)
			if noise_strength > 0.0 and dist_from_attach > 0.0:
				world_pos += Vector3(
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0)
				) * noise_strength * (1.0 - t_profile * 0.5)
			vertices.append(world_pos)
			uvs.append(Vector2(t_total, s_norm))
	for i in range(actual_length_segs):
		for j in range(actual_width_segs):
			var v0 := top_start + i * (actual_width_segs + 1) + j
			var v1 := v0 + 1
			var v2 := v0 + actual_width_segs + 1
			var v3 := v2 + 1
			indices.append(v0); indices.append(v2); indices.append(v1)
			indices.append(v1); indices.append(v2); indices.append(v3)
	for i in range(actual_length_segs):
		for j in range(actual_width_segs):
			var v0 := bottom_start + i * (actual_width_segs + 1) + j
			var v1 := v0 + 1
			var v2 := v0 + actual_width_segs + 1
			var v3 := v2 + 1
			indices.append(v0); indices.append(v1); indices.append(v2)
			indices.append(v1); indices.append(v3); indices.append(v2)
	_add_caps_and_edges(
		vertices, indices, uvs,
		actual_length_segs, actual_width_segs,
		total_length, cliff_embed_depth,
		slab_pos
	)

	return MeshData.create(vertices, indices, uvs)


func update_bounds() -> void:
	var forward := overhang_direction.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var embed_origin := attachment_point - forward * cliff_embed_depth
	var tip := attachment_point + forward * extent
	var half_w := width * 0.5
	var half_t := thickness * 0.5
	var min_pt := Vector3(INF, INF, INF)
	var max_pt := Vector3(-INF, -INF, -INF)
	for base in [embed_origin, tip]:
		for r in [-half_w, half_w]:
			for u in [-half_t, half_t]:
				var corner: Vector3 = base + right * r + up * u
				min_pt = min_pt.min(corner)
				max_pt = max_pt.max(corner)

	var pad := Vector3.ONE * (noise_strength * 2.0 + 1.0)
	bounds = AABB(min_pt - pad, (max_pt - min_pt) + pad * 2.0)


func _get_thickness_at(t: float) -> float:
	if profile_curve:
		return profile_curve.sample(t) * thickness
	return thickness * (1.0 - t * 0.3)


func _world_to_local(point: Vector3) -> Vector3:
	var forward := overhang_direction.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var rel := point - attachment_point
	return Vector3(rel.dot(forward), rel.dot(up), rel.dot(right))


func _add_caps_and_edges(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	length_segs: int,
	width_segs: int,
	total_length: float,
	embed_depth: float,
	slab_pos: Callable
) -> void:
	var root_seg := 0
	for i in range(length_segs + 1):
		var dist := float(i) / float(length_segs) * total_length - embed_depth
		if dist >= 0.0:
			root_seg = i
			break
	var left_start := vertices.size()
	for i in range(length_segs + 1):
		var t := float(i) / float(length_segs)
		vertices.append(slab_pos.call(i, 0, true))
		uvs.append(Vector2(t, 0.0))
		vertices.append(slab_pos.call(i, 0, false))
		uvs.append(Vector2(t, 1.0))
	for i in range(length_segs):
		var b := left_start + i * 2
		var tv0 := b; var bv0 := b + 1
		var tv1 := b + 2; var bv1 := b + 3
		indices.append(tv0); indices.append(bv0); indices.append(tv1)
		indices.append(bv0); indices.append(bv1); indices.append(tv1)
	var right_start := vertices.size()
	for i in range(length_segs + 1):
		var t := float(i) / float(length_segs)
		vertices.append(slab_pos.call(i, width_segs, true))
		uvs.append(Vector2(t, 0.0))
		vertices.append(slab_pos.call(i, width_segs, false))
		uvs.append(Vector2(t, 1.0))
	for i in range(length_segs):
		var b := right_start + i * 2
		var tv0 := b; var bv0 := b + 1
		var tv1 := b + 2; var bv1 := b + 3
		indices.append(tv0); indices.append(tv1); indices.append(bv0)
		indices.append(bv0); indices.append(tv1); indices.append(bv1)
	var tip_start := vertices.size()
	for j in range(width_segs + 1):
		var s := float(j) / float(width_segs)
		vertices.append(slab_pos.call(length_segs, j, true))
		uvs.append(Vector2(s, 0.0))
		vertices.append(slab_pos.call(length_segs, j, false))
		uvs.append(Vector2(s, 1.0))
	for j in range(width_segs):
		var b := tip_start + j * 2
		var tv0 := b; var bv0 := b + 1
		var tv1 := b + 2; var bv1 := b + 3
		indices.append(tv0); indices.append(bv0); indices.append(tv1)
		indices.append(bv0); indices.append(bv1); indices.append(tv1)
	var root_start := vertices.size()
	for j in range(width_segs + 1):
		var s := float(j) / float(width_segs)
		vertices.append(slab_pos.call(root_seg, j, true))
		uvs.append(Vector2(s, 0.0))
		vertices.append(slab_pos.call(root_seg, j, false))
		uvs.append(Vector2(s, 1.0))
	for j in range(width_segs):
		var b := root_start + j * 2
		var tv0 := b; var bv0 := b + 1
		var tv1 := b + 2; var bv1 := b + 3
		indices.append(tv0); indices.append(tv1); indices.append(bv0)
		indices.append(bv0); indices.append(tv1); indices.append(bv1)


func get_memory_usage() -> int:
	var usage := 512
	if profile_curve:
		usage += 256
	return usage
