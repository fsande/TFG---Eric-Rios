# Small typed data class for path points to replace Dictionary usage
class_name MountainPoint
## World coordinates of the point
var position: Vector2
var direction: Vector2
var width_mult: float
var length_mult: float
var token_index: int

func _init(pos := Vector2(), dir := Vector2(), 
			width_m: float = 1.0, length_m: float = 1.0, 
			idx := 0) -> void:
	position = pos
	direction = dir
	width_mult = width_m
	length_mult = length_m
	token_index = idx
