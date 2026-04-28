## @brief Volume definition for overhangs and additive geometry.
##
## @details Defines geometry that protrudes from the terrain surface,
## such as cliff overhangs, rock formations, or arches.
## The back of the slab is embedded `cliff_embed_depth` units into the
## cliff face so no seam is ever visible at the terrain junction.
@tool
class_name OverhangVolumeDefinition extends VolumeDefinition

## The world position where the overhang attaches to terrain surface
var attachment_point: Vector3 = Vector3.ZERO

## Direction the overhang extends outward (normalized, usually near-horizontal)
var overhang_direction: Vector3 = Vector3(-1, 0, 0).normalized()

## How far the overhang extends past the attachment point
var extent: float = 5.0

## Width of the overhang perpendicular to direction
var width: float = 8.0

## Thickness of the overhang slab
var thickness: float = 2.0

## How far the back of the slab is buried into the cliff face.
## This hides the seam between the overhang and terrain mesh.
var cliff_embed_depth: float = 3.0

## Profile curve for the overhang shape (optional).
## X axis = distance along extent (0-1), Y axis = thickness multiplier.
@export var profile_curve: Curve = null

## Segments for mesh generation
@export_range(2, 16) var length_segments: int = 6
@export_range(2, 16) var width_segments: int = 4

## Noise variation for natural look.
## Applied as low-frequency domain warping so the whole slab bulges
## organically rather than individual vertices jittering independently.
@export var noise_strength: float = 0.2
@export var noise_seed: int = 0

## Frequency of the low-frequency blob noise (lower = bigger blobs).
@export var noise_frequency: float = 0.15

## Secondary high-frequency detail noise layered on top (0 = disabled).
@export var detail_noise_strength: float = 0.05

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

## Side length of the base cube that is rounded into a blob.
@export var blob_cube_size: float = 12

## How much to round the cube edges/corners (0 = sharp cube, 1 ≈ near‑sphere).
@export_range(0.0, 1.0) var blob_rounding: float = 0.5

## Number of subdivisions along each axis (quad mesh density).
@export_range(4, 32) var cube_subdivisions: int = 16

func generate_mesh(chunk_bounds: AABB, resolution: int) -> MeshData:
	if not intersects_chunk(chunk_bounds):
		return null
	var vertices: PackedVector3Array
	var indices: PackedInt32Array
	var uvs: PackedVector2Array
	var segs: int = max(2, cube_subdivisions)
	var radius := blob_cube_size * 0.5
	var face_dirs: Array[Vector3] = [
		Vector3( 1, 0, 0),
		Vector3(-1, 0, 0),
		Vector3( 0, 0, 1),
		Vector3( 0, 0, -1),
		Vector3( 0, 1, 0),
		Vector3( 0, -1, 0)
	]
	var tex_ups: Array[Vector3] = [
		Vector3( 0, 1, 0),
		Vector3( 0, 1, 0),
		Vector3( 0, 1, 0),
		Vector3( 0, 1, 0),
		Vector3( 0, 0, -1),
		Vector3( 0, 0, 1)
	]
	for face in 6:
		var normal := face_dirs[face]
		var tex_up := tex_ups[face]
		var u_axis := tex_up.cross(normal).normalized()
		var v_axis := normal.cross(u_axis).normalized()
		var face_start := vertices.size()
		for j in segs + 1:
			var v := float(j) / segs * 2.0 - 1.0
			for k in segs + 1:
				var u := float(k) / segs * 2.0 - 1.0
				# Point on cube (range -1..1)
				var p := normal + u_axis * u + v_axis * v
				# --- QUAD SPHERE PROJECTION ---
				var x2 = p.x * p.x
				var y2 = p.y * p.y
				var z2 = p.z * p.z
				var sphere := Vector3(
					p.x * sqrt(1.0 - (y2 + z2) * 0.5 + (y2 * z2) / 3.0),
					p.y * sqrt(1.0 - (z2 + x2) * 0.5 + (z2 * x2) / 3.0),
					p.z * sqrt(1.0 - (x2 + y2) * 0.5 + (x2 * y2) / 3.0)
				)
				var final_pos := sphere * radius + attachment_point
				vertices.append(final_pos)
				var uv_u := float(k) / float(segs)
				var uv_v := 1.0 - float(j) / float(segs)
				uvs.append(Vector2(uv_u, uv_v))
		for j in segs:
			for k in segs:
				var v0 := face_start + j * (segs + 1) + k
				var v1 := v0 + 1
				var v2 := v0 + segs + 1
				var v3 := v2 + 1
				indices.append(v0); indices.append(v2); indices.append(v1)
				indices.append(v1); indices.append(v2); indices.append(v3)
	return MeshData.new(vertices, indices, uvs)
	
## Update bounds to accurately enclose the full embedded+visible slab.
func update_bounds() -> void:
	var radius := blob_cube_size * 0.5
	var pad := Vector3.ONE * radius
	bounds = AABB(attachment_point - pad, pad * 2.0)

## Get thickness at normalized position along visible extent (0=attach, 1=tip).
func _get_thickness_at(t: float) -> float:
	if profile_curve:
		return profile_curve.sample(t) * thickness
	return thickness * (1.0 - t * 0.4)

## Transform a world point into local overhang space.
## X = along forward, Y = along up, Z = along right.
func _world_to_local(point: Vector3) -> Vector3:
	var forward := overhang_direction.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var rel := point - attachment_point
	return Vector3(rel.dot(forward), rel.dot(up), rel.dot(right))
