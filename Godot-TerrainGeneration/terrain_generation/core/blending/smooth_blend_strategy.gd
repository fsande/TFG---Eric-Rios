class_name SmoothBlendStrategy extends HeightBlendStrategy

func blend(existing: float, delta: float, intensity: float) -> float:
	var blend_factor := clampf(abs(delta), 0.0, 1.0)
	return lerpf(existing, existing + delta, blend_factor)
