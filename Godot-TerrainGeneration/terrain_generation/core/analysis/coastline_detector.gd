## @brief Detects and analyzes coastlines from heightmaps.
##
## @details Responsible for generating binary coastline maps and detecting
## coastline edges using configurable edge detection strategies.
class_name CoastlineDetector extends RefCounted

## Edge detection strategy to use
var edge_detection_strategy: EdgeDetectionStrategy

## Cached binary coastline map (0=land, 1=water)
var _cached_binary_map: Image = null

## Cached coastline edge map (1=edge, 0=other)
var _cached_edge_map: Image = null

func _init(p_edge_detection_strategy: EdgeDetectionStrategy = null) -> void:
	edge_detection_strategy = p_edge_detection_strategy
	if not edge_detection_strategy:
		edge_detection_strategy = SobelEdgeDetectionStrategy.new()

## Generate binary coastline map (0=land, 1=water).
## @param heightmap Reference heightmap
## @param sea_level_normalized Sea level in normalized (0-1) range
## @return Binary image where pixels below sea level are 1.0, above are 0.0
func generate_binary_map(heightmap: Image, sea_level_normalized: float) -> Image:
	if not heightmap:
		push_error("CoastlineDetector: Heightmap is null")
		return null
	_cached_binary_map = ImageBinarizer.binarize_image(heightmap, sea_level_normalized)
	return _cached_binary_map

## Get or generate binary coastline map.
## @param heightmap Reference heightmap
## @param sea_level_normalized Sea level in normalized range
## @return Cached or newly generated binary map
func get_or_generate_binary_map(heightmap: Image, sea_level_normalized: float) -> Image:
	if _cached_binary_map == null:
		_cached_binary_map = generate_binary_map(heightmap, sea_level_normalized)
	return _cached_binary_map

## Detect edges in binary coastline map.
## @param binary_map Binary coastline map
## @param processing_context Optional processing context for GPU
## @return Edge map where coastline edges are 1.0
func detect_edges(binary_map: Image, processing_context: ProcessingContext = null) -> Image:
	if not binary_map:
		push_error("CoastlineDetector: Binary map is null")
		return null
	
	_cached_edge_map = edge_detection_strategy.detect_edges(binary_map, processing_context)
	return _cached_edge_map

## Get or detect coastline edges.
## @param binary_map Binary coastline map
## @param processing_context Optional processing context
## @return Cached or newly detected edge map
func get_or_detect_edges(binary_map: Image, processing_context: ProcessingContext = null) -> Image:
	if _cached_edge_map == null:
		_cached_edge_map = detect_edges(binary_map, processing_context)
	return _cached_edge_map

## Set edge detection strategy and invalidate cache.
## @param strategy New edge detection strategy
func set_edge_detection_strategy(strategy: EdgeDetectionStrategy) -> void:
	edge_detection_strategy = strategy
	_cached_edge_map = null

## Clear all cached data.
func clear_cache() -> void:
	_cached_binary_map = null
	_cached_edge_map = null

