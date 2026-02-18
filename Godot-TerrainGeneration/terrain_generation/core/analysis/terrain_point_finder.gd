## @brief Finds terrain feature points (coastlines, mountains, cliffs).
##
## @details Responsible for locating specific terrain features based on criteria.
## Uses sampling and filtering to find valid positions.
## Follows Single Responsibility Principle - only handles point finding.
class_name TerrainPointFinder extends RefCounted

## How much to oversample when searching for points
const OVERSAMPLE_FACTOR := 6
## Reference to the context for heightmap access
var _context: TerrainGenerationContext

func _init(context: TerrainGenerationContext) -> void:
	_context = context

## Find coastline edge points for river endpoints or other features.
## @param edge_map Coastline edge map (1=edge, 0=other)
## @param count Number of points desired
## @param seed_offset Seed for randomization
## @return Array of world-space Vector2 positions on coastline
func find_coastline_points(edge_map: Image, count: int, seed_offset: int = 0) -> Array[Vector2]:
	if not edge_map:
		push_warning("TerrainPointFinder: Edge map is null")
		return []
	var width := edge_map.get_width()
	var height := edge_map.get_height()
	var edge_pixels: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if edge_map.get_pixel(x, y).r > 0.5:
				edge_pixels.append(Vector2i(x, y))
	if edge_pixels.is_empty():
		push_warning("TerrainPointFinder: No coastline edges found")
		return []
	var rng := _context.create_rng(seed_offset)
	_fisher_yates_shuffle(edge_pixels, rng)
	var result: Array[Vector2] = []
	var actual_count := mini(count, edge_pixels.size())
	for i in range(actual_count):
		var pixel := edge_pixels[i]
		var uv := Vector2(float(pixel.x) / float(width), float(pixel.y) / float(height))
		result.append(_context.uv_to_world(uv))
	return result

## Find points above a height threshold (for river sources, etc.).
## @param min_height_norm Minimum height (normalized 0-1)
## @param count Number of points desired
## @param seed_offset Seed for randomization
## @return Array of world-space Vector2 positions
func find_points_above_height(min_height_norm: float, count: int, seed_offset: int = 0) -> Array[Vector2]:
	var rng := _context.create_rng(seed_offset)
	var points: Array[Vector2] = []
	for _i in range(count * OVERSAMPLE_FACTOR):
		if points.size() >= count:
			break
		var uv := Vector2(rng.randf(), rng.randf())
		var height_norm := _context.sample_height_at_uv(uv)
		if height_norm >= min_height_norm:
			points.append(_context.uv_to_world(uv))
	return points

## Find points below a height threshold (for valley placement, etc.).
## @param max_height_norm Maximum height (normalized 0-1)
## @param count Number of points desired
## @param seed_offset Seed for randomization
## @return Array of world-space Vector2 positions
func find_points_below_height(max_height_norm: float, count: int, seed_offset: int = 0) -> Array[Vector2]:
	var rng := _context.create_rng(seed_offset)
	var points: Array[Vector2] = []
	for _i in range(count * OVERSAMPLE_FACTOR):
		if points.size() >= count:
			break
		var uv := Vector2(rng.randf(), rng.randf())
		var height_norm := _context.sample_height_at_uv(uv)
		if height_norm <= max_height_norm:
			points.append(_context.uv_to_world(uv))
	return points

## Find cliff positions (steep slopes).
## @param min_slope Minimum slope in degrees
## @param sample_count Number of samples to take
## @param seed_offset Seed for randomization
## @return Array of dictionaries with position, normal, and slope
func find_cliff_positions(min_slope: float, sample_count: int = 100, seed_offset: int = 12345) -> Array[Dictionary]:
	var cliffs: Array[Dictionary] = []
	var rng := _context.create_rng(seed_offset)
	for _i in range(sample_count * OVERSAMPLE_FACTOR):
		if cliffs.size() >= sample_count:
			break
		var uv := Vector2(rng.randf(), rng.randf())
		var world_pos := _context.uv_to_world(uv)
		var slope := _context.calculate_slope_at(world_pos)
		if slope >= min_slope:
			var height := _context.get_scaled_height_at(world_pos)
			var normal := _context.calculate_normal_at(world_pos)
			cliffs.append({
				"position": Vector3(world_pos.x, height, world_pos.y),
				"normal": normal,
				"slope": slope
			})
	return cliffs

## Fisher-Yates shuffle algorithm with seeded RNG.
func _fisher_yates_shuffle(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp
