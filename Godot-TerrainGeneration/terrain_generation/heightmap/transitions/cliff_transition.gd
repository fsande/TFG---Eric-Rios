class_name CliffTransition extends TransitionStrategy

var noise := FastNoiseLite.new()
var steepness := 0.8

func _init(seed_value: int):
	noise.seed = seed_value
	noise.frequency = 0.05

func calculate_height(base_height: float, _mask_value: float, blur_value: float, 
	position: Vector2) -> float:
	var noise_mod := noise.get_noise_2d(position.x, position.y) * 0.2
	return lerp(0.0, base_height, pow(blur_value, steepness + noise_mod))
