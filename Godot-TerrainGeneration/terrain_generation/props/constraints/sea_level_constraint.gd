@tool
class_name SeaLevelConstraint extends PropPlacementConstraint

## @brief Constraint that checks if terrain height is above or below sea level.

## This constraint allows you to specify whether props should be placed above or below the sea level defined in the context.
@export var above_sea_level: bool = true

func validate(context: PropPlacementContext) -> bool:
	if above_sea_level:
		return context.terrain_sample.height > context.sea_level
	else:
		return context.terrain_sample.height < context.sea_level
