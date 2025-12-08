## A class to hold slope data for terrain generation.
class_name SlopeData extends RefCounted
var normal: Vector3
var angle: float

func _init(p_normal: Vector3 = Vector3.UP, p_angle: float = 0.0):
	normal = p_normal
	angle = p_angle