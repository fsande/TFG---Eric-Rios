## @brief Base class for all prop placement constraints.
@tool
@abstract class_name PropPlacementConstraint extends Resource

@abstract func validate(context: PropPlacementContext) -> bool

## Called after a candidate is fully accepted by all constraints.
## Override to update stateful structures like spatial grids.
func on_placement_accepted(position: Vector2) -> void:
	pass

## Called before a new build_for_chunk run. Override to reset per-chunk state.
func reset() -> void:
	pass

## Called after reset() to seed stateful structures with placements from neighbouring chunks.
func seed_from_neighbours(neighbour_placements: Array[ChunkFeatureInstance]) -> void:
	pass
