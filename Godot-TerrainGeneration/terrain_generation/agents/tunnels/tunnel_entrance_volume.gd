## @brief Subtractive volume that carves a tunnel mouth through a cliff face.
##
## @details A cylinder whose front face conforms to the terrain surface rather
## than being a flat disc. entry_surface_depths stores per-angle signed depths
## (negative = cliff bulges past the nominal center) baked by TunnelBoringAgent.
@tool
class_name TunnelEntranceVolume extends VolumeDefinition

## World-space center of the nominal entrance face.
var center: Vector3

## Unit vector pointing into the terrain (away from the cliff face).
var inward_direction: Vector3

## Carve cylinder radius.
var carve_radius: float

## How deep into the cliff the cylinder extends past the deepest surface depth.
var carve_depth: float

## Number of angular samples used to represent the terrain-conforming front face.
@export var entry_depth_samples: int = 16

## Signed axial depth of the terrain surface at each angular sample.
## Negative means the cliff extends in front of center; positive means it recedes.
## Populated by TunnelBoringAgent before the volume is used.
var entry_surface_depths: PackedFloat32Array

func _init() -> void:
	volume_type = VolumeType.SUBTRACTIVE
	creation_timestamp = Time.get_unix_time_from_system()

func point_is_inside(point: Vector3) -> bool:
	var to_point := point - center
	var along := to_point.dot(inward_direction)
	if along > carve_depth:
		return false
	var lateral := to_point - inward_direction * along
	if lateral.length_squared() > carve_radius * carve_radius:
		return false
	var right := inward_direction.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = inward_direction.cross(Vector3.FORWARD).normalized()
	var up := right.cross(inward_direction).normalized()
	var angle := atan2(lateral.dot(up), lateral.dot(right))
	return along >= _sample_surface_depth(angle) - 1

func update_bounds() -> void:
	var radial_extents := Vector3.ONE * carve_radius
	var min_depth := 0.0
	for d in entry_surface_depths:
		min_depth = minf(min_depth, d)
	var back_extents := inward_direction.abs() * absf(min_depth)
	var fwd_extents := inward_direction.abs() * carve_depth
	var origin := center - radial_extents - back_extents
	var size := (radial_extents + back_extents + fwd_extents) * 2.0
	bounds = AABB(origin, size)

## Interpolates entry_surface_depths at the given angle (radians, atan2 range).
func _sample_surface_depth(angle: float) -> float:
	if entry_surface_depths.is_empty():
		return 0.0
	var n := entry_surface_depths.size()
	var t := fmod(angle + TAU * 2.0, TAU) / TAU * float(n)
	var i0 := int(t) % n
	var i1 := (i0 + 1) % n
	return lerpf(entry_surface_depths[i0], entry_surface_depths[i1], t - floor(t))
