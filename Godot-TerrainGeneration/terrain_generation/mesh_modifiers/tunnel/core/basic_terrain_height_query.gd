## Queries terrain height at world positions using MeshModifierContext.
@tool
class_name BasicTerrainHeightQuery extends RefCounted

var _context: MeshModifierContext

func _init(context: MeshModifierContext) -> void:
	_context = context

func get_height_at(world_xz: Vector2) -> float:
	var vertex_idx := _context.find_nearest_vertex(world_xz)
	if vertex_idx < 0:
		push_warning("BasicTerrainHeightQuery: Invalid position (%0.2f, %0.2f)" % [world_xz.x, world_xz.y])
		return 0.0
	return _context.get_vertex_position(vertex_idx).y

func is_underground(world_pos: Vector3) -> bool:
	var terrain_height := get_height_at(Vector2(world_pos.x, world_pos.z))
	return world_pos.y < terrain_height

func get_height_safe(world_xz: Vector2, fallback: float = 0.0) -> float:
	var height := get_height_at(world_xz)
	return height if is_finite(height) else fallback

func to_callable() -> Callable:
	return get_height_at

