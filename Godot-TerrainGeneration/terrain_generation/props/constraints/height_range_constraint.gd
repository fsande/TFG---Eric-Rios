## HeightRangeConstraint ensures that props are only placed within a specified height range on the terrain.
@tool
class_name HeightRangeConstraint extends PropPlacementConstraint

## Minimum height for prop placement. Props will only be placed if the terrain height is above this value 
@export var min_height: float = -1000.0

## Maximum height for prop placement. Props will only be placed if the terrain height is below this value
@export var max_height: float = 1000.0

func validate(context: PropPlacementContext) -> bool:
	return context.terrain_sample.height >= min_height and context.terrain_sample.height <= max_height
