## @brief Rule for placing props/objects on terrain chunks.
##
## @details Defines how props should be distributed on terrain,
## including density, constraints, and variation parameters.
@tool
class_name PropPlacementRule extends Resource

## The scene to instantiate for this prop
@export var prop_scene: PackedScene = null

## Base density (props per square world unit)
@export_range(0.0, 1.0, 0.001) var density: float = 0.01

## Optional density map texture (multiplies base density)
## White = full density, Black = no props
@export var density_map: Texture2D = null

## Placement constraints
@export_group("Constraints")

## Minimum terrain slope in degrees (0 = flat)
@export_range(0.0, 90.0) var min_slope: float = 0.0

## Maximum terrain slope in degrees
@export_range(0.0, 90.0) var max_slope: float = 45.0

## Minimum terrain height
@export var min_height: float = -1000.0

## Maximum terrain height
@export var max_height: float = 1000.0

## Minimum distance between props of this type
@export var min_spacing: float = 1.0

## Whether to avoid placing props inside volumes (tunnels, caves)
@export var exclude_from_volumes: bool = true

## Variation parameters
@export_group("Variation")

## Scale range (min, max)
@export var scale_range: Vector2 = Vector2(0.8, 1.2)

## Whether to randomize Y rotation
@export var random_rotation: bool = true

## Whether to align prop to terrain normal
@export var align_to_normal: bool = true

## Maximum tilt when aligning to normal (degrees)
@export_range(0.0, 90.0) var max_tilt: float = 30.0

## Sink props into ground by this amount
@export var ground_offset: float = 0.0

## LOD settings
@export_group("LOD")

## Maximum LOD level to spawn props (0 = only highest detail)
@export_range(0, 5) var max_lod_level: int = 2

## Distance at which to use billboard impostor (0 = no billboard)
@export var billboard_distance: float = 0.0

## Metadata
@export_group("Metadata")

## Unique identifier for this rule
@export var rule_id: String = ""

## Priority (higher = placed first, can block lower priority)
@export var priority: int = 0

## Seed offset for variation
@export var seed_offset: int = 0

## Generate prop placements for a chunk.
## @param chunk_bounds World-space bounds of the chunk
## @param terrain_sampler Function to sample terrain height/normal at position
## @param volumes Array of VolumeDefinitions to check for exclusion
## @param seed Base seed for randomization
## @return Array of PropPlacement instances
func get_placements_for_chunk(
	chunk_bounds: AABB,
	terrain_sampler: Callable,
	volumes: Array[VolumeDefinition],
	seed: int
) -> Array[PropPlacement]:
	var placements: Array[PropPlacement] = []
	if not prop_scene:
		return placements
	if density <= 0:
		return placements
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + seed_offset + hash(rule_id)
	var chunk_area := chunk_bounds.size.x * chunk_bounds.size.z
	var base_count := int(chunk_area * density)
	var attempts := base_count * 3
	for i in range(attempts):
		if placements.size() >= base_count * 2:
			break
		var x := rng.randf_range(chunk_bounds.position.x, chunk_bounds.position.x + chunk_bounds.size.x)
		var z := rng.randf_range(chunk_bounds.position.z, chunk_bounds.position.z + chunk_bounds.size.z)
		var pos_2d := Vector2(x, z)
		if density_map:
			var uv := _world_to_density_uv(pos_2d, chunk_bounds)
			var density_sample := _sample_density_map(uv)
			if rng.randf() > density_sample:
				continue
		var terrain_info: Dictionary = terrain_sampler.call(pos_2d)
		if terrain_info.is_empty():
			continue
		var height: float = terrain_info.get("height", 0.0)
		var normal: Vector3 = terrain_info.get("normal", Vector3.UP)
		if height < min_height or height > max_height:
			continue
		var slope := rad_to_deg(acos(normal.dot(Vector3.UP)))
		if slope < min_slope or slope > max_slope:
			continue
		if exclude_from_volumes:
			var world_pos := Vector3(x, height, z)
			var inside_volume := false
			for volume in volumes:
				if volume.volume_type == VolumeDefinition.VolumeType.SUBTRACTIVE:
					if volume.point_is_inside(world_pos):
						inside_volume = true
						break
			if inside_volume:
				continue
		var too_close := false
		for existing in placements:
			var dist := Vector2(existing.position.x, existing.position.z).distance_to(pos_2d)
			if dist < min_spacing:
				too_close = true
				break
		if too_close:
			continue
		var placement := PropPlacement.new()
		placement.position = Vector3(x, height + ground_offset, z)
		placement.prop_scene = prop_scene
		placement.rule_id = rule_id
		if align_to_normal and max_tilt > 0:
			var tilt_angle := minf(slope, max_tilt)
			var tilt_axis := Vector3.UP.cross(normal).normalized()
			if tilt_axis.length_squared() > 0.01:
				placement.rotation = Vector3(
					tilt_axis.x * deg_to_rad(tilt_angle),
					rng.randf() * TAU if random_rotation else 0.0,
					tilt_axis.z * deg_to_rad(tilt_angle)
				)
			else:
				placement.rotation = Vector3(0, rng.randf() * TAU if random_rotation else 0.0, 0)
		else:
			placement.rotation = Vector3(0, rng.randf() * TAU if random_rotation else 0.0, 0)
		var scale_value := rng.randf_range(scale_range.x, scale_range.y)
		placement.scale = Vector3.ONE * scale_value
		placements.append(placement)
	return placements

## Check if this rule should apply at given LOD level.
func should_apply_at_lod(lod_level: int) -> bool:
	return lod_level <= max_lod_level

## Convert world position to density map UV.
func _world_to_density_uv(world_pos: Vector2, chunk_bounds: AABB) -> Vector2:
	var u := (world_pos.x - chunk_bounds.position.x) / chunk_bounds.size.x
	var v := (world_pos.y - chunk_bounds.position.z) / chunk_bounds.size.z
	return Vector2(clampf(u, 0, 1), clampf(v, 0, 1))

## Sample density map at UV coordinates.
func _sample_density_map(uv: Vector2) -> float:
	if not density_map:
		return 1.0
	var image := density_map.get_image()
	if not image:
		return 1.0
	var px := int(uv.x * (image.get_width() - 1))
	var py := int(uv.y * (image.get_height() - 1))
	return image.get_pixel(px, py).r
