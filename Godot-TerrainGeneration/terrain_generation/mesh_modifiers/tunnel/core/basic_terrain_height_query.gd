## Queries terrain height at world positions using MeshModifierContext.
@tool
class_name BasicTerrainHeightQuery extends TerrainHeightQuerier

var _context: MeshModifierContext

func _init(context: MeshModifierContext) -> void:
	_context = context

func get_height_at(world_xz: Vector2) -> float:
	var vertex_idx := _context.find_nearest_vertex(world_xz)
	if vertex_idx < 0:
		push_warning("BasicTerrainHeightQuery: Invalid position (%0.2f, %0.2f)" % [world_xz.x, world_xz.y])
		return 0.0
	return _context.get_vertex_position(vertex_idx).y
