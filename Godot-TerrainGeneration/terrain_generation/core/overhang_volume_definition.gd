## @brief Volume definition for overhangs and additive geometry.
##
## @details Defines geometry that protrudes from the terrain surface,
## such as cliff overhangs, rock formations, or arches.
## The back of the slab is embedded `cliff_embed_depth` units into the
## cliff face so no seam is ever visible at the terrain junction.
@tool
class_name OverhangVolumeDefinition extends VolumeDefinition

## The world position where the overhang attaches to terrain surface
@export var attachment_point: Vector3 = Vector3.ZERO

## Direction the overhang extends outward (normalized, usually near-horizontal)
@export var overhang_direction: Vector3 = Vector3(-1, 0, 0).normalized()

## How far the overhang extends past the attachment point
@export var extent: float = 5.0

## Width of the overhang perpendicular to direction
@export var width: float = 8.0

## Thickness of the overhang slab
@export var thickness: float = 2.0

## How far the back of the slab is buried into the cliff face.
## This hides the seam between the overhang and terrain mesh.
@export var cliff_embed_depth: float = 3.0

## Profile curve for the overhang shape (optional).
## X axis = distance along extent (0-1), Y axis = thickness multiplier.
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
	if local.x < -cliff_embed_depth or local.x > extent:
		return false
	if abs(local.z) > width * 0.5:
		return false
	var t := clampf(local.x / extent, 0.0, 1.0)
	return abs(local.y) <= _get_thickness_at(t) * 0.5

## Generate mesh for the overhang.
## The slab starts cliff_embed_depth behind attachment_point (buried in terrain)
## and extends `extent` units forward. The buried section ensures no seam.
func generate_mesh(chunk_bounds: AABB, resolution: int) -> MeshData:
	if not intersects_chunk(chunk_bounds):
		return null

	var vertices := PackedVector3Array()
	var indices  := PackedInt32Array()
	var uvs      := PackedVector2Array()

	# Build orthonormal basis from overhang direction
	var forward := overhang_direction.normalized()
	var right   := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()

	var actual_length_segs := maxi(length_segments * resolution / 32, 2)
	var actual_width_segs  := maxi(width_segments  * resolution / 32, 2)
	var total_length       := extent + cliff_embed_depth

	# embed_origin is the buried back of the slab
	var embed_origin := attachment_point - forward * cliff_embed_depth

	# --- Top surface ---
	var top_start := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	for i in range(actual_length_segs + 1):
		var t_total        := float(i) / float(actual_length_segs)
		var dist_from_attach := t_total * total_length - cliff_embed_depth
		var t_profile      := clampf(dist_from_attach / extent, 0.0, 1.0)
		var half_thick     := _get_thickness_at(t_profile) * 0.5
		for j in range(actual_width_segs + 1):
			var s         := float(j) / float(actual_width_segs) - 0.5
			var world_pos := (embed_origin
				+ forward * (t_total * total_length)
				+ right   * (s * width)
				+ up      * half_thick)
			# Apply noise only to the visible (non-embedded) section
			if noise_strength > 0.0 and dist_from_attach > 0.0:
				world_pos += Vector3(
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0)
				) * noise_strength * (1.0 - t_profile * 0.5)
			vertices.append(world_pos)
			uvs.append(Vector2(t_profile, s + 0.5))

	# --- Bottom surface (reset RNG so top/bottom noise are symmetric) ---
	var bottom_start := vertices.size()
	rng.seed = noise_seed
	for i in range(actual_length_segs + 1):
		var t_total          := float(i) / float(actual_length_segs)
		var dist_from_attach := t_total * total_length - cliff_embed_depth
		var t_profile        := clampf(dist_from_attach / extent, 0.0, 1.0)
		var half_thick       := _get_thickness_at(t_profile) * 0.5
		for j in range(actual_width_segs + 1):
			var s         := float(j) / float(actual_width_segs) - 0.5
			var world_pos := (embed_origin
				+ forward * (t_total * total_length)
				+ right   * (s * width)
				- up      * half_thick)
			if noise_strength > 0.0 and dist_from_attach > 0.0:
				world_pos += Vector3(
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0)
				) * noise_strength * (1.0 - t_profile * 0.5)
			vertices.append(world_pos)
			uvs.append(Vector2(t_profile, s + 0.5))

	# --- Top face (CCW from above = normals point up) ---
	for i in range(actual_length_segs):
		for j in range(actual_width_segs):
			var v0 := top_start + i * (actual_width_segs + 1) + j
			var v1 := v0 + 1
			var v2 := v0 + actual_width_segs + 1
			var v3 := v2 + 1
			indices.append(v0); indices.append(v2); indices.append(v1)
			indices.append(v1); indices.append(v2); indices.append(v3)

	# --- Bottom face (flipped winding = normals point down) ---
	for i in range(actual_length_segs):
		for j in range(actual_width_segs):
			var v0 := bottom_start + i * (actual_width_segs + 1) + j
			var v1 := v0 + 1
			var v2 := v0 + actual_width_segs + 1
			var v3 := v2 + 1
			indices.append(v0); indices.append(v1); indices.append(v2)
			indices.append(v1); indices.append(v3); indices.append(v2)

	# Left edge, right edge, and tip cap. Back face is intentionally open
	# (it is buried inside the terrain mesh).
	_add_side_edges(vertices, indices, uvs,
		top_start, bottom_start, actual_length_segs, actual_width_segs)

	return MeshData.new(vertices, indices, uvs)

## Update bounds to accurately enclose the full embedded+visible slab.
func update_bounds() -> void:
	var forward := overhang_direction.normalized()
	var right   := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()

	var embed_origin := attachment_point - forward * cliff_embed_depth
	var tip          := attachment_point + forward * extent
	var half_w       := width     * 0.5
	var half_t       := thickness * 0.5

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

## Get thickness at normalized position along visible extent (0=attach, 1=tip).
func _get_thickness_at(t: float) -> float:
	if profile_curve:
		return profile_curve.sample(t) * thickness
	# Default: taper to 70% at the tip
	return thickness * (1.0 - t * 0.3)

## Transform a world point into local overhang space.
## X = along forward, Y = along up, Z = along right.
func _world_to_local(point: Vector3) -> Vector3:
	var forward := overhang_direction.normalized()
	var right   := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up      := right.cross(forward).normalized()
	var rel     := point - attachment_point
	return Vector3(rel.dot(forward), rel.dot(up), rel.dot(right))

## Close the left edge, right edge, and tip of the slab.
## The back face (buried end) is deliberately left open.
func _add_side_edges(
	vertices:     PackedVector3Array,
	indices:      PackedInt32Array,
	uvs:          PackedVector2Array,
	top_start:    int,
	bottom_start: int,
	length_segs:  int,
	width_segs:   int
) -> void:
	# Left edge (j = 0)
	for i in range(length_segs):
		var tv0 := top_start    + i * (width_segs + 1)
		var tv1 := top_start    + (i + 1) * (width_segs + 1)
		var bv0 := bottom_start + i * (width_segs + 1)
		var bv1 := bottom_start + (i + 1) * (width_segs + 1)
		indices.append(tv0); indices.append(bv0); indices.append(tv1)
		indices.append(tv1); indices.append(bv0); indices.append(bv1)

	# Right edge (j = width_segs)
	for i in range(length_segs):
		var tv0 := top_start    + i * (width_segs + 1) + width_segs
		var tv1 := top_start    + (i + 1) * (width_segs + 1) + width_segs
		var bv0 := bottom_start + i * (width_segs + 1) + width_segs
		var bv1 := bottom_start + (i + 1) * (width_segs + 1) + width_segs
		indices.append(tv0); indices.append(tv1); indices.append(bv0)
		indices.append(tv1); indices.append(bv1); indices.append(bv0)

	# Tip cap (i = length_segs, the far visible end)
	for j in range(width_segs):
		var tv0 := top_start    + length_segs * (width_segs + 1) + j
		var tv1 := tv0 + 1
		var bv0 := bottom_start + length_segs * (width_segs + 1) + j
		var bv1 := bv0 + 1
		indices.append(tv0); indices.append(tv1); indices.append(bv0)
		indices.append(tv1); indices.append(bv1); indices.append(bv0)

## Get memory usage estimate.
func get_memory_usage() -> int:
	var usage := 512
	if profile_curve:
		usage += 256
	return usage
