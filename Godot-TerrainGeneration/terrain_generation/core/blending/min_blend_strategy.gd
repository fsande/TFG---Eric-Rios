class_name MinBlendStrategy extends HeightBlendStrategy

func blend(existing: float, delta: float, _intensity: float) -> float:
	return minf(existing, delta)
