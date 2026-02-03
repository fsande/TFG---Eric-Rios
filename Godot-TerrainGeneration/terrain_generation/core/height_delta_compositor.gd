## @brief Composes base heightmap with multiple height delta maps.
##
## @details Handles the composition of height fields at any resolution,
## combining the base heightmap with all applicable delta maps.
class_name HeightDeltaCompositor extends RefCounted

const EPSILON: float = 0.0001

## Compose a height field from base heightmap and delta maps for a region.
## @param base_heightmap The base heightmap image (full terrain)
## @param delta_maps Array of HeightDeltaMaps to apply
## @param bounds World-space bounds to compose
## @param resolution Output resolution
## @param terrain_size Total terrain size
## @return Composed heightmap image (FORMAT_RF)
static func compose_region(
	base_heightmap: Image,
	delta_maps: Array[HeightDeltaMap],
	bounds: AABB,
	resolution: Vector2i,
	terrain_size: float
) -> Image:
	var result := HeightmapSampler._sample_region_from_image(
		base_heightmap, bounds, resolution, terrain_size
	)
	if delta_maps.is_empty():
		return result
	var sorted_deltas := delta_maps.duplicate()
	sorted_deltas.sort_custom(func(a, b): return a.priority < b.priority)
	for delta_map in sorted_deltas:
		if not delta_map.intersects(bounds):
			continue
		_apply_delta_to_region(result, delta_map, bounds, resolution)
	return result

## Apply a single delta map to a height region.
static func _apply_delta_to_region(
	height_image: Image,
	delta_map: HeightDeltaMap,
	bounds: AABB,
	resolution: Vector2i
) -> void:
	for y in range(resolution.y):
		for x in range(resolution.x):
			var u := float(x) / float(resolution.x - 1) if resolution.x > 1 else 0.5
			var v := float(y) / float(resolution.y - 1) if resolution.y > 1 else 0.5
			var world_x := lerpf(bounds.position.x, bounds.position.x + bounds.size.x, u)
			var world_z := lerpf(bounds.position.z, bounds.position.z + bounds.size.z, v)
			var delta_value := delta_map.sample_at(Vector2(world_x, world_z))
			if abs(delta_value) < EPSILON:
				continue
			var current_height := height_image.get_pixel(x, y).r
			var new_height := delta_map.apply_blend(current_height, delta_value)
			height_image.set_pixel(x, y, Color(new_height, 0, 0, 1))

## Compose height at a single world position.
## @param base_heightmap The base heightmap image
## @param delta_maps Array of HeightDeltaMaps
## @param world_pos World position (XZ)
## @param terrain_size Total terrain size
## @return Composed height value
static func compose_at(
	base_heightmap: Image,
	delta_maps: Array[HeightDeltaMap],
	world_pos: Vector2,
	terrain_size: float
) -> float:
	var height := HeightmapSampler.sample_height_at(base_heightmap, world_pos, terrain_size)
	if delta_maps.is_empty():
		return height
	var sorted_deltas := delta_maps.duplicate()
	sorted_deltas.sort_custom(func(a, b): return a.priority < b.priority)
	for delta_map: HeightDeltaMap in sorted_deltas:
		var delta_value := delta_map.sample_at(world_pos)
		if abs(delta_value) >= 0.0001:
			height = delta_map.apply_blend(height, delta_value)
	return height

## Get all delta maps that affect a given bounds.
## @param delta_maps All available delta maps
## @param bounds Region to check
## @return Filtered array of intersecting delta maps
static func get_deltas_for_region(
	delta_maps: Array[HeightDeltaMap],
	bounds: AABB
) -> Array[HeightDeltaMap]:
	var result: Array[HeightDeltaMap] = []
	for delta in delta_maps:
		if delta.intersects(bounds):
			result.append(delta)
	return result
