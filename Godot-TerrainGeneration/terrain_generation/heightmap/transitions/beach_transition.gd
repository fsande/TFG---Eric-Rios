class_name BeachTransition extends TransitionStrategy

var noise := FastNoiseLite.new()
var smoothness := 3.0

func _init(seed_value: int):
	noise.seed = seed_value + 100
	noise.frequency = 0.08

func calculate_height(base_height: float, mask_value: float, blur_value: float, 
	position: Vector2) -> float:
	var noise_mod := noise.get_noise_2d(position.x, position.y) * 0.1
	return lerp(0.0, base_height * 0.7, 
		pow(blur_value, smoothness)) + noise_mod * mask_value