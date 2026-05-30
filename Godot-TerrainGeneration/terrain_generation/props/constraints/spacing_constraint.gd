## @brief Constraint that ensures a minimum distance between props.
@tool
class_name SpacingConstraint extends PropPlacementConstraint

## Minimum distance that must be maintained between props.
@export var min_distance: float = 1.0

var _grid: Dictionary = {}
var _min_distance_squared: float = 1.0

func reset() -> void:
	_grid.clear()
	_min_distance_squared = min_distance * min_distance

func seed_from_neighbours(neighbour_placements: Array[ChunkFeatureInstance]) -> void:
	for placement in neighbour_placements:
		_register(Vector2(placement.position.x, placement.position.z))

func validate(placement_context: PropPlacementContext) -> bool:
	var cell := _to_cell(placement_context.position_2d)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var neighbour_cell := Vector2i(cell.x + dx, cell.y + dy)
			if not _grid.has(neighbour_cell):
				continue
			for existing_pos in _grid[neighbour_cell]:
				if placement_context.position_2d.distance_squared_to(existing_pos) < _min_distance_squared:
					return false
	return true

func on_placement_accepted(position: Vector2) -> void:
	_register(position)

func _register(position: Vector2) -> void:
	var cell := _to_cell(position)
	if not _grid.has(cell):
		_grid[cell] = []
	_grid[cell].append(position)

func _to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / min_distance), floori(position.y / min_distance))
