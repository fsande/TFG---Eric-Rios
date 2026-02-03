class_name AdditiveBlendStrategy extends HeightBlendStrategy

func blend(existing: float, delta: float, _intensity: float) -> float:
	return existing + delta