## @brief Context provided to terrain modifier agents during generation.
##
## @details Contains all information agents need to generate their modifications,
## including terrain parameters, reference heightmap, and utility functions.
## Delegates specialized analysis to focused helper classes (SRP).
class_name TerrainGenerationContext extends RefCounted

## Terrain size in world units
var terrain_size: Vector2

## Height scale for the terrain
var height_scale: float

## Generation seed
var generation_seed: int

## Reference heightmap (for terrain analysis)
var reference_heightmap: Image = null

## Reference resolution for generating deltas
var reference_resolution: Vector2i = Vector2i(256, 256)

## The terrain definition being built
var terrain_definition: TerrainDefinition = null

## Processing context (for GPU access if needed)
var processing_context: ProcessingContext = null

## Helper classes for terrain analysis
var _coastline_detector: CoastlineDetector = null
var _point_finder: TerrainPointFinder = null
var _gradient_calculator: TerrainGradientCalculator = null

## Initialize context with terrain parameters.
func _init(
	p_terrain_size: Vector2,
	p_height_scale: float,
	p_seed: int,
	p_reference_heightmap: Image = null
) -> void:
	terrain_size = p_terrain_size
	height_scale = p_height_scale
	generation_seed = p_seed
	reference_heightmap = p_reference_heightmap
	_coastline_detector = CoastlineDetector.new()
	_point_finder = TerrainPointFinder.new(self)
	_gradient_calculator = TerrainGradientCalculator.new(self)

## Get terrain bounds as AABB.
func get_terrain_bounds() -> AABB:
	var half_size := terrain_size / 2.0
	return AABB(
		Vector3(-half_size.x, 0, -half_size.y),
		Vector3(terrain_size.x, height_scale * 2, terrain_size.y)
	)

## Sample height at a world position from reference heightmap.
## @param world_pos World position (XZ)
## @return Height value (0-1 range, not scaled)
func sample_height_at(world_pos: Vector2) -> float:
	if not reference_heightmap:
		return 0.0
	return HeightmapSampler.sample_height_at(reference_heightmap, world_pos, terrain_size.x)

## Sample height at UV coordinates from reference heightmap.
## @param uv UV coordinates (0-1 range)
## @return Height value (0-1 range)
func sample_height_at_uv(uv: Vector2) -> float:
	if not reference_heightmap:
		return 0.0
	var px := int(uv.x * (reference_heightmap.get_width() - 1))
	var py := int(uv.y * (reference_heightmap.get_width() - 1))
	px = clampi(px, 0, reference_heightmap.get_width() - 1)
	py = clampi(py, 0, reference_heightmap.get_height() - 1)
	return reference_heightmap.get_pixel(px, py).r

## Get scaled height at world position.
func get_scaled_height_at(world_pos: Vector2) -> float:
	return sample_height_at(world_pos) * height_scale

## Calculate terrain normal at a world position.
## @param world_pos World position (XZ)
## @return Normal vector
func calculate_normal_at(world_pos: Vector2) -> Vector3:
	if not reference_heightmap:
		return Vector3.UP
	var epsilon := terrain_size.x / float(reference_heightmap.get_width())
	var h_center := get_scaled_height_at(world_pos)
	var h_right := get_scaled_height_at(world_pos + Vector2(epsilon, 0))
	var h_forward := get_scaled_height_at(world_pos + Vector2(0, epsilon))
	var tangent := Vector3(epsilon, h_right - h_center, 0)
	var bitangent := Vector3(0, h_forward - h_center, epsilon)
	return bitangent.cross(tangent).normalized()

## Calculate slope at a world position in degrees.
func calculate_slope_at(world_pos: Vector2) -> float:
	var normal := calculate_normal_at(world_pos)
	return rad_to_deg(acos(normal.dot(Vector3.UP)))

## Convert world XZ position to UV coordinates.
func world_to_uv(world_pos: Vector2) -> Vector2:
	var half_size := terrain_size / 2.0
	return Vector2(
		(world_pos.x + half_size.x) / terrain_size.x,
		(world_pos.y + half_size.y) / terrain_size.y
	)

## Convert UV coordinates to world XZ position.
func uv_to_world(uv: Vector2) -> Vector2:
	var half_size := terrain_size / 2.0
	return Vector2(
		uv.x * terrain_size.x - half_size.x,
		uv.y * terrain_size.y - half_size.y
	)

## Create a random number generator with consistent seeding.
func create_rng(offset: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = generation_seed + offset
	return rng

## Find cliff positions (steep slopes) for tunnel/cave placement.
## Delegates to TerrainPointFinder.
## @param min_slope Minimum slope in degrees
## @param sample_count Number of samples to take
## @return Array of cliff positions with normals
func find_cliff_positions(min_slope: float, sample_count: int = 100) -> Array[Dictionary]:
	return _point_finder.find_cliff_positions(min_slope, sample_count)

## Get or generate binary coastline map (0=land, 1=water).
## Delegates to CoastlineDetector.
## @return Image where pixels below sea level are 1.0, above are 0.0
func get_coastline_binary_map() -> Image:
	if not reference_heightmap or not terrain_definition:
		push_warning("TerrainGenerationContext: Cannot generate coastline without heightmap and terrain definition")
		return null
	var sea_level_normalized := terrain_definition.sea_level / height_scale
	return _coastline_detector.get_or_generate_binary_map(reference_heightmap, sea_level_normalized)

## Get or generate coastline edge map using edge detection.
## Delegates to CoastlineDetector.
## @return Image where coastline edge pixels are 1.0, others are 0.0
func get_coastline_edge_map() -> Image:
	var binary := get_coastline_binary_map()
	if not binary:
		return null
	return _coastline_detector.get_or_detect_edges(binary, processing_context)

## Set edge detection strategy (default is Sobel CPU).
## Delegates to CoastlineDetector.
## @param strategy Edge detection strategy to use
func set_edge_detection_strategy(strategy: EdgeDetectionStrategy) -> void:
	_coastline_detector.set_edge_detection_strategy(strategy)

## Find coastline edge points for river endpoints or other features.
## Delegates to TerrainPointFinder.
## @param count Number of points desired
## @param seed_offset Seed for randomization
## @return Array of world-space Vector2 positions on coastline
func find_coastline_points(count: int, seed_offset: int = 0) -> Array[Vector2]:
	var edge_map := get_coastline_edge_map()
	if not edge_map:
		return []
	return _point_finder.find_coastline_points(edge_map, count, seed_offset)

## Find points above a height threshold (for river sources, etc.).
## Delegates to TerrainPointFinder.
## @param min_height_norm Minimum height (normalized 0-1)
## @param count Number of points desired
## @param seed_offset Seed for randomization
## @return Array of world-space Vector2 positions
func find_points_above_height(min_height_norm: float, count: int, seed_offset: int = 0) -> Array[Vector2]:
	return _point_finder.find_points_above_height(min_height_norm, count, seed_offset)

## Calculate 2D gradient (XZ plane) at a world position.
## Delegates to TerrainGradientCalculator.
## @param world_pos World position (XZ)
## @return Vector2 gradient in XZ plane (not normalized)
func calculate_gradient_at(world_pos: Vector2) -> Vector2:
	return _gradient_calculator.calculate_gradient_at(world_pos)

## Get downhill direction (negative gradient, normalized).
## Delegates to TerrainGradientCalculator.
## @param world_pos World position (XZ)
## @return Normalized Vector2 pointing downhill, or ZERO if flat
func calculate_downhill_direction(world_pos: Vector2) -> Vector2:
	return _gradient_calculator.calculate_downhill_direction(world_pos)

## Get uphill direction (positive gradient, normalized).
## Delegates to TerrainGradientCalculator.
## @param world_pos World position (XZ)
## @return Normalized Vector2 pointing uphill, or ZERO if flat
func calculate_uphill_direction(world_pos: Vector2) -> Vector2:
	return _gradient_calculator.calculate_uphill_direction(world_pos)

## Dispose of any resources.
func dispose() -> void:
	if processing_context:
		processing_context.dispose()
		processing_context = null
	reference_heightmap = null
	if _coastline_detector:
		_coastline_detector.clear_cache()
		_coastline_detector = null
	_point_finder = null
	_gradient_calculator = null

