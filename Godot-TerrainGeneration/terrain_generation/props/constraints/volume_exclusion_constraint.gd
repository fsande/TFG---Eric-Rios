## Constraint that prevents props from being placed within a certain volume.
@tool
class_name VolumeExclusionConstraint extends PropPlacementConstraint

func validate(context: PropPlacementContext) -> bool:
	var world_pos := Vector3(context.position_2d.x, context.terrain_sample.height, context.position_2d.y)
	for volume in context.volumes:
		if volume.volume_type == VolumeDefinition.VolumeType.SUBTRACTIVE and volume.point_is_inside(world_pos):
			return false
	return true
