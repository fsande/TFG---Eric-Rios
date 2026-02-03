## @brief Samples heightmap sources at arbitrary bounds and resolution.
##
## @details Provides resolution-independent heightmap sampling, allowing
## chunks to be generated at any LOD level from the same source.
## Supports bilinear interpolation for high-quality sampling.
class_name HeightmapSampler extends RefCounted

## Sample a heightmap source at specific bounds and resolution.
## @param source The HeightmapSource to sample from
## @param bounds World-space bounds to sample (only XZ used, Y ignored)
## @param resolution Target resolution (width x height in pixels)
## @param terrain_size Total terrain size for context
## @param seed Generation seed
## @param shared_context Optional shared ProcessingContext
## @return Image in FORMAT_RF with sampled heights
static func sample_region(
	source: HeightmapSource,
	bounds: AABB,
	resolution: Vector2i,
	terrain_size: float,
	generation_seed: int = 0,
	shared_context: ProcessingContext = null
) -> Image:
	if not source:
		push_error("HeightmapSampler: No source provided")
		return null
	var context: ProcessingContext
	var owns_context := false
	if shared_context:
		context = shared_context
	else:
		context = ProcessingContext.new(
			terrain_size,
			ProcessingContext.ProcessorType.CPU,
			ProcessingContext.ProcessorType.CPU,
			generation_seed
		)
		owns_context = true
	var full_heightmap := source.generate(context)
	if owns_context:
		context.dispose()
	if not full_heightmap:
		push_error("HeightmapSampler: Failed to generate heightmap from source")
		return null
	return _sample_region_from_image(full_heightmap, bounds, resolution, terrain_size)

## Sample a region from an existing heightmap image.
## @param heightmap Source heightmap image
## @param bounds World-space bounds to sample
## @param resolution Target output resolution
## @param terrain_size Total terrain size
## @return Sampled region as Image
static func _sample_region_from_image(
	heightmap: Image,
	bounds: AABB,
	resolution: Vector2i,
	terrain_size: float
) -> Image:
	var result := Image.create(resolution.x, resolution.y, false, Image.FORMAT_RF)
	var half_size := terrain_size / 2.0
	var uv_min := Vector2(
		(bounds.position.x + half_size) / terrain_size,
		(bounds.position.z + half_size) / terrain_size
	)
	var uv_max := Vector2(
		(bounds.position.x + bounds.size.x + half_size) / terrain_size,
		(bounds.position.z + bounds.size.z + half_size) / terrain_size
	)
	for y in range(resolution.y):
		for x in range(resolution.x):
			var u := lerpf(uv_min.x, uv_max.x, float(x) / float(resolution.x - 1)) if resolution.x > 1 else uv_min.x
			var v := lerpf(uv_min.y, uv_max.y, float(y) / float(resolution.y - 1)) if resolution.y > 1 else uv_min.y
			var height := _sample_bilinear(heightmap, u, v)
			result.set_pixel(x, y, Color(height, 0, 0, 1))
	return result

## Bilinear interpolation sampling from heightmap.
## @param heightmap Source image
## @param u Horizontal coordinate (0-1)
## @param v Vertical coordinate (0-1)
## @return Interpolated height value
static func _sample_bilinear(heightmap: Image, u: float, v: float) -> float:
	var width := heightmap.get_width()
	var height := heightmap.get_height()
	u = clampf(u, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	var px := u * (width - 1)
	var py := v * (height - 1)
	var x0 := int(floor(px))
	var y0 := int(floor(py))
	var x1 := mini(x0 + 1, width - 1)
	var y1 := mini(y0 + 1, height - 1)
	var fx := px - x0
	var fy := py - y0
	var h00 := heightmap.get_pixel(x0, y0).r
	var h10 := heightmap.get_pixel(x1, y0).r
	var h01 := heightmap.get_pixel(x0, y1).r
	var h11 := heightmap.get_pixel(x1, y1).r
	var h0 := lerpf(h00, h10, fx)
	var h1 := lerpf(h01, h11, fx)
	return lerpf(h0, h1, fy)

## Sample height at a specific world position.
## @param heightmap Source heightmap image
## @param world_pos World position (XZ used)
## @param terrain_size Total terrain size
## @return Height value at position
static func sample_height_at(heightmap: Image, world_pos: Vector2, terrain_size: float) -> float:
	var half_size := terrain_size / 2.0
	var u := (world_pos.x + half_size) / terrain_size
	var v := (world_pos.y + half_size) / terrain_size
	return _sample_bilinear(heightmap, u, v)

## Calculate appropriate resolution for a chunk at given LOD level.
## @param _chunk_size Size of chunk in world units (reserved for future use)
## @param base_resolution Base resolution at LOD 0
## @param lod_level Current LOD level (0 = highest detail)
## @return Resolution to use for this LOD
static func calculate_lod_resolution(_chunk_size: Vector2, base_resolution: int, lod_level: int) -> Vector2i:
	var divisor := 1 << lod_level  # 2^lod_level
	var res := maxi(int(float(base_resolution) / float(divisor)), 2)  # Minimum 2x2
	return Vector2i(res, res)

