class_name ResolvedLayerRule

var rule: LayerRule
var height_min: float
var height_max: float
func get_slope_min() -> float: return rule.slope_min
func get_slope_max() -> float: return rule.slope_max
func get_noise_influence() -> float: return rule.noise_influence
func get_noise_scale() -> float: return rule.noise_scale
