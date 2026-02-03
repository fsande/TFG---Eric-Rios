class_name ReplaceBlendStrategy extends HeightBlendStrategy

const THRESHOLD := 0.001

func blend(existing: float, delta: float, _intensity: float) -> float:
	return delta if abs(delta) > THRESHOLD else existing
