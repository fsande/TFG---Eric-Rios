## @brief Subtractive volume that carves a tunnel mouth through a cliff face.
##
## @details A short disc-shaped extrusion along the entrance normal.
## Slightly oversized relative to the tunnel radius so that cliff-face
## triangles are fully enclosed and removed by _apply_subtractive_volume.
@tool
class_name TunnelEntranceVolume extends VolumeDefinition

## Center of the entrance opening (world space).
var center: Vector3

## Unit vector pointing into the terrain from the entrance face.
var inward_direction: Vector3

## Carve radius — set slightly larger than the tube radius.
var carve_radius: float

## How deep into the cliff the carve extends.
var carve_depth: float = 3.0

## Cross-section shape, should match the paired TunnelVolumeDefinition.
var cross_section: TunnelVolumeDefinition.CrossSectionType = TunnelVolumeDefinition.CrossSectionType.CIRCLE

func _init() -> void:
	volume_type = VolumeType.SUBTRACTIVE
	creation_timestamp = Time.get_unix_time_from_system()

func point_is_inside(point: Vector3) -> bool:
	var to_point := point - center
	var along_inward := to_point.dot(inward_direction)
	if along_inward < -carve_depth * 0.5 or along_inward > carve_depth:
		return false
	var lateral := to_point - inward_direction * along_inward
	var right := inward_direction.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = inward_direction.cross(Vector3.FORWARD).normalized()
	var up := right.cross(inward_direction).normalized()
	var local_2d := Vector2(lateral.dot(right), lateral.dot(up))
	return _point_in_cross_section(local_2d)

func update_bounds() -> void:
	var radial_extents := Vector3.ONE * carve_radius
	var depth_extents := inward_direction.abs() * carve_depth
	var extents := radial_extents + depth_extents
	bounds = AABB(center - extents, extents * 2.0)

func _point_in_cross_section(local: Vector2) -> bool:
	var r_sq := carve_radius * carve_radius
	match cross_section:
		TunnelVolumeDefinition.CrossSectionType.CIRCLE:
			return local.length_squared() <= r_sq
		TunnelVolumeDefinition.CrossSectionType.ARCH:
			return local.y >= -carve_radius * 0.5 and local.length_squared() <= r_sq
		TunnelVolumeDefinition.CrossSectionType.RECTANGLE:
			var half := carve_radius * 0.8
			return abs(local.x) <= half and abs(local.y) <= half
		TunnelVolumeDefinition.CrossSectionType.NATURAL:
			var variation := 0.7 + 0.3 * sin(atan2(local.y, local.x) * 3.0)
			return local.length_squared() <= (carve_radius * variation) * (carve_radius * variation)
		_:
			return local.length_squared() <= r_sq
