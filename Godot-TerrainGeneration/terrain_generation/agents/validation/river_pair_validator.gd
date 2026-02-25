## @brief Interface for validating river point pairs.
##
## @details Strategy pattern for checking if a coast-mountain pair is valid
## for river generation. Allows swapping between heuristic and exact methods.
## Follows Open/Closed Principle - open for extension (new validators),
## closed for modification (interface stable).
@tool
class_name RiverPairValidator extends Resource

## Check if a coast-mountain pair is likely to produce a valid river.
## @param coast_point Coastline starting point
## @param mountain_point Mountain target point
## @param context Terrain generation context
## @return True if pair is valid, false otherwise
func is_pair_valid(
	coast_point: Vector2,
	mountain_point: Vector2,
	context: TerrainGenerationContext
) -> bool:
	push_error("RiverPairValidator.is_pair_valid() must be overridden")
	return false

## Get the name of this validation strategy.
func get_strategy_name() -> String:
	return "Unknown"
