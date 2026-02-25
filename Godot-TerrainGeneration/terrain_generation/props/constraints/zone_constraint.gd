## @brief Constraint that accepts or rejects prop placement based on zone tags.
##
## @details Checks whether the candidate position falls inside a zone
## identified by a tag on a HeightDeltaMap (e.g. &"river", &"mountain").
## By default rejects placement inside the zone; set allow_inside = true
## to invert (only allow placement inside the zone).
@tool
class_name ZoneConstraint extends PropPlacementConstraint

## The zone tag to check (e.g. &"river").
@export var zone_tag: StringName = &""

## If true, the constraint ALLOWS placement only INSIDE the zone.
## If false (default), the constraint REJECTS placement inside the zone.
@export var allow_inside: bool = false

func validate(context: PropPlacementContext) -> bool:
	if zone_tag == &"" or not context.terrain_definition:
		return true
	var inside := context.terrain_definition.is_in_zone(context.position_2d, zone_tag)
	return inside if allow_inside else not inside

