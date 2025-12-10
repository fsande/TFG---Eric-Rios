## @brief Cylindrical volume for CSG operations.
##
## @details Represents a finite cylinder with a center, direction, radius, and length.
## Used for tunnel boring operations.
@tool
class_name CylinderVolume extends CSGVolume

## Center point of the cylinder base
var origin: Vector3

## Direction vector of the cylinder axis (normalized)
var direction: Vector3

## Radius of the cylinder
var radius: float

## Length of the cylinder along its axis
var length: float

## Construct a cylinder volume
func _init(p_origin: Vector3, p_direction: Vector3, p_radius: float, p_length: float) -> void:
	origin = p_origin
	direction = p_direction.normalized()
	radius = p_radius
	length = p_length

## Returns signed distance from point to cylinder surface
func signed_distance(point: Vector3) -> float:
	var to_point := point - origin
	var axial_dist := to_point.dot(direction)
	var axis_point: Vector3 = origin + direction * clamp(axial_dist, 0.0, length)
	var radial_vec := point - axis_point
	var radial_dist := radial_vec.length()
	if axial_dist < 0.0:
		return sqrt(radial_dist * radial_dist + axial_dist * axial_dist)
	elif axial_dist > length:
		var overshoot := axial_dist - length
		return sqrt(radial_dist * radial_dist + overshoot * overshoot)
	else:
		return radial_dist - radius

## Get debug mesh representation as a cylinder
func get_debug_mesh() -> Array:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 16
	mesh.rings = 1
	var up := Vector3.UP
	var basis := Basis()
	if abs(direction.dot(up)) < 0.999:
		var rotation_axis := up.cross(direction).normalized()
		var rotation_angle := up.angle_to(direction)
		basis = Basis(rotation_axis, rotation_angle)
	else:
		if direction.dot(up) < 0:
			basis = Basis(Vector3.RIGHT, PI)
	var center_pos := origin + direction * (length * 0.5)
	var transform := Transform3D(basis, center_pos)
	return [mesh, transform]
