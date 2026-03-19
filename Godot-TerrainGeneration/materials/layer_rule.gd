@tool
class_name LayerRule extends HeightLayer

## Slope range this layer is active in (0 = flat, 1 = vertical cliff)
@export_range(0.0, 1.0) var slope_min: float = 0.0
@export_range(0.0, 1.0) var slope_max: float = 1.0

@export_range(0.0, 1.0) var noise_influence: float = 0.3
@export var noise_scale: float = 4.0
