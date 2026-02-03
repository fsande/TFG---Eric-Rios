## @brief Context provided to terrain modifier agents during generation.
##
## @details Contains all information agents need to generate their modifications,
## including terrain parameters, reference heightmap, and utility functions.
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
	var py := int(uv.y * (reference_heightmap.get_height() - 1))
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
## @param min_slope Minimum slope in degrees
## @param sample_count Number of samples to take
## @return Array of cliff positions with normals
func find_cliff_positions(min_slope: float, sample_count: int = 100) -> Array[Dictionary]:
	var cliffs: Array[Dictionary] = []
	var rng := create_rng(12345)
	for i in range(sample_count * 3):  # Oversample
		if cliffs.size() >= sample_count:
			break
		var uv := Vector2(rng.randf(), rng.randf())
		var world_pos := uv_to_world(uv)
		var slope := calculate_slope_at(world_pos)
		if slope >= min_slope:
			var height := get_scaled_height_at(world_pos)
			var normal := calculate_normal_at(world_pos)
			cliffs.append({
				"position": Vector3(world_pos.x, height, world_pos.y),
				"normal": normal,
				"slope": slope
			})
	return cliffs


## Dispose of any resources.
func dispose() -> void:
	if processing_context:
		processing_context.dispose()
		processing_context = null
	reference_heightmap = null

