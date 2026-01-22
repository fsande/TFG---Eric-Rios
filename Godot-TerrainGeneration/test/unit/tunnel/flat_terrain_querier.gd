## Test implementation of TerrainHeightQuerier that returns a constant height.
class_name FlatTerrainQuerier extends TerrainHeightQuerier

var _height: float

func _init(height: float = 10) -> void:
	_height = height

func get_height_at(_world_xz: Vector2) -> float:
	return _height

