## Type-safe interface for querying terrain height at world positions.
@tool
class_name TerrainHeightQuerier extends RefCounted

func get_height_at(world_xz: Vector2) -> float:
	push_error("TerrainHeightQuerier.get_height_at() must be overridden")
	return 0.0

func is_underground(world_pos: Vector3) -> bool:
	var terrain_height := get_height_at(Vector2(world_pos.x, world_pos.z))
	return world_pos.y < terrain_height

