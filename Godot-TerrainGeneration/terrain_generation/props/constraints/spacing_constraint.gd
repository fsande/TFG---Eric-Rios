## Constraint that ensures a minimum distance between props.
@tool
class_name SpacingConstraint extends PropPlacementConstraint

## Minimum distance that must be maintained between props. Props will only be placed if they are at least this distance away from existing props.
@export var min_distance: float = 1.0

func validate(context: PropPlacementContext) -> bool:
	for existing_placement in context.existing_placements:
		var distance := Vector2(existing_placement.position.x, existing_placement.position.z).distance_to(context.position_2d)
		if distance < min_distance:
			return false
	return true
