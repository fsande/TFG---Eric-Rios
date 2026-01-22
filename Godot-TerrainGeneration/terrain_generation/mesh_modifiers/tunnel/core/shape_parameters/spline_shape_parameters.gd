## @brief Type-safe parameters for spline-based curved tunnel shapes.
@tool
class_name SplineShapeParameters extends TunnelShapeParameters

@export var path_curve: Curve3D = null
@export_range(0.5, 50.0, 0.5, "suffix:m") var radius: float = 3.0
@export_range(6, 64, 1) var radial_segments: int = 16
@export_range(5, 200, 1) var path_segments: int = 50
@export var auto_calculate_length: bool = true
@export_range(1.0, 500.0, 1.0, "suffix:m") var manual_length: float = 50.0

func get_shape_type() -> TunnelShapeType.Type:
	return TunnelShapeType.Type.SPLINE

func get_length() -> float:
	if auto_calculate_length and path_curve:
		return path_curve.get_baked_length()
	return manual_length

func is_valid() -> bool:
	if not path_curve:
		return false
	if path_curve.point_count < 2:
		return false
	if radius <= 0.0:
		return false
	if radial_segments < 3:
		return false
	if path_segments < 2:
		return false
	return true

func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not path_curve:
		errors.append("Path curve is required")
	elif path_curve.point_count < 2:
		errors.append("Path curve must have at least 2 points (got %d)" % path_curve.point_count)
	if radius <= 0.0:
		errors.append("Radius must be positive (got %.2f)" % radius)
	if radial_segments < 3:
		errors.append("Radial segments must be at least 3 (got %d)" % radial_segments)
	if path_segments < 2:
		errors.append("Path segments must be at least 2 (got %d)" % path_segments)
	return errors

func duplicate_parameters() -> TunnelShapeParameters:
	var dup := SplineShapeParameters.new()
	dup.path_curve = path_curve
	dup.radius = radius
	dup.radial_segments = radial_segments
	dup.path_segments = path_segments
	dup.auto_calculate_length = auto_calculate_length
	dup.manual_length = manual_length
	return dup

static func transform_curve_to_entry(original_curve: Curve3D, entry_position: Vector3, tunnel_direction: Vector3, surface_normal: Vector3) -> Curve3D:
	var transformed_curve := Curve3D.new()
	var entry_basis := _create_entry_basis(tunnel_direction, -surface_normal)
	var entry_transform := Transform3D(entry_basis, entry_position)
	for i in range(original_curve.point_count):
		var point_pos := original_curve.get_point_position(i)
		var point_in := original_curve.get_point_in(i)
		var point_out := original_curve.get_point_out(i)
		var world_pos := entry_transform * point_pos
		var world_in := entry_basis * point_in
		var world_out := entry_basis * point_out
		transformed_curve.add_point(world_pos, world_in, world_out)
	transformed_curve.bake_interval = original_curve.bake_interval
	return transformed_curve

static func _create_entry_basis(tunnel_direction: Vector3, surface_normal: Vector3) -> Basis:
	var forward := tunnel_direction.normalized()
	var right := surface_normal.cross(forward).normalized()
	if right.length() < 0.01:
		right = Vector3.RIGHT.cross(forward).normalized()
	var up := forward.cross(right).normalized()
	return Basis(right, up, forward)

