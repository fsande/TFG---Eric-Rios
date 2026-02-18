## @brief Complete terrain definition stored as a resource.
##
## @details Contains all resolution-independent data needed to generate
## terrain chunks on demand: heightmap source, height deltas, volumes, and prop rules.
## This is the output of Phase 1 generation and input for Phase 2 chunk generation.
@tool
class_name TerrainDefinition extends Resource

## Base terrain settings
@export_group("Base Terrain")

## The heightmap source for base terrain shape
@export var heightmap_source: HeightmapSource = null

## Total terrain size in world units
@export var terrain_size: Vector2 = Vector2(1024, 1024)

## Height scale applied to heightmap values
@export var height_scale: float = 64.0

## Generation seed
@export var generation_seed: int = 0

## Sea level for water plane and underwater props
@export var sea_level: float = 0.0

## Layer 1: Height Modifications
@export_group("Height Deltas")

## Array of height delta maps to apply
@export var height_delta_maps: Array[HeightDeltaMap] = []

## Layer 2: Volume Modifications
@export_group("Volumes")

## Array of volume definitions (tunnels, caves, overhangs)
@export var volume_definitions: Array[VolumeDefinition] = []

## Layer 3: Prop Placement
@export_group("Props")

## Array of prop placement rules
@export var prop_placement_rules: Array[PropPlacementRule] = []

## Metadata
@export_group("Metadata")

## When this definition was generated
@export var generation_timestamp: int = 0

## Version for compatibility checking
@export var version: int = 1

## Source configuration name (for reference)
@export var source_config_name: String = ""

## Cached base heightmap (generated on first access)
var _cached_base_heightmap: Image = null
var _cached_heightmap_size: float = 0.0

## Shared processing context for GPU operations
var _shared_processing_context: ProcessingContext = null

## Set shared processing context for GPU operations.
func set_shared_processing_context(ctx: ProcessingContext) -> void:
	_shared_processing_context = ctx

## Get shared processing context.
func get_shared_processing_context() -> ProcessingContext:
	return _shared_processing_context

## Create a new TerrainDefinition with basic settings.
static func create(
	p_heightmap_source: HeightmapSource,
	p_terrain_size: Vector2,
	p_height_scale: float,
	p_seed: int = 0
) -> TerrainDefinition:
	var definition := TerrainDefinition.new()
	definition.heightmap_source = p_heightmap_source
	definition.terrain_size = p_terrain_size
	definition.height_scale = p_height_scale
	definition.generation_seed = p_seed
	definition.generation_timestamp = Time.get_unix_time_from_system()
	return definition

## Add a height delta map.
func add_height_delta(delta: HeightDeltaMap) -> void:
	if delta:
		height_delta_maps.append(delta)

## Add a volume definition.
func add_volume(volume: VolumeDefinition) -> void:
	if volume:
		volume_definitions.append(volume)

## Add a prop placement rule.
func add_prop_rule(rule: PropPlacementRule) -> void:
	if rule:
		prop_placement_rules.append(rule)

## Get all volumes affecting a chunk.
## @param chunk_bounds Chunk AABB
## @param lod_level Current LOD level
## @return Array of applicable volumes
func get_volumes_for_chunk(chunk_bounds: AABB, lod_level: int = 0) -> Array[VolumeDefinition]:
	var result: Array[VolumeDefinition] = []
	for volume in volume_definitions:
		if volume.intersects_chunk(chunk_bounds) and volume.should_apply_at_lod(lod_level):
			result.append(volume)
	result.sort_custom(func(a, b): return a.priority < b.priority)
	return result

## Get all height deltas affecting a chunk.
## @param chunk_bounds Chunk AABB
## @return Array of applicable deltas
func get_deltas_for_chunk(chunk_bounds: AABB) -> Array[HeightDeltaMap]:
	var result: Array[HeightDeltaMap] = []
	for delta in height_delta_maps:
		if delta.intersects(chunk_bounds):
			result.append(delta)
	result.sort_custom(func(a, b): return a.priority < b.priority)
	return result

## Get all prop rules for a chunk at given LOD.
## @param lod_level Current LOD level
## @return Array of applicable prop rules
func get_prop_rules_for_lod(lod_level: int) -> Array[PropPlacementRule]:
	var result: Array[PropPlacementRule] = []
	for rule in prop_placement_rules:
		if rule.should_apply_at_lod(lod_level):
			result.append(rule)
	result.sort_custom(func(a, b): return a.priority > b.priority)
	return result

## Generate or get cached base heightmap at specified resolution.
## @param resolution Resolution to generate at
## @return Heightmap image
func get_base_heightmap(resolution: int = 1024) -> Image:
	if _cached_base_heightmap and _cached_heightmap_size == resolution:
		return _cached_base_heightmap
	if not heightmap_source:
		push_error("TerrainDefinition: No heightmap source")
		return null
	var context: ProcessingContext
	var owns_context := false
	if _shared_processing_context:
		context = _shared_processing_context
	else:
		context = ProcessingContext.new(
			terrain_size.x,
			ProcessingContext.ProcessorType.CPU,
			ProcessingContext.ProcessorType.CPU,
			generation_seed
		)
		owns_context = true
	_cached_base_heightmap = heightmap_source.generate(context)
	_cached_heightmap_size = resolution
	if owns_context:
		context.dispose()
	return _cached_base_heightmap

## Sample composed height at a world position.
## @param world_pos World position (XZ)
## @return Height value including all deltas
func sample_height_at(world_pos: Vector2) -> float:
	var base_heightmap := get_base_heightmap()
	if not base_heightmap:
		return 0.0
	var height := HeightmapSampler.sample_height_at(base_heightmap, world_pos, terrain_size.x)
	height *= height_scale
	for delta in height_delta_maps:
		var delta_value := delta.sample_at(world_pos)
		if abs(delta_value) >= 0.0001:
			height = delta.apply_blend(height, delta_value)
	return height

## Check if a point is inside any subtractive volume.
## @param point World position
## @return True if inside a subtractive volume (tunnel, cave)
func is_inside_volume(point: Vector3) -> bool:
	for volume in volume_definitions:
		if volume.volume_type == VolumeDefinition.VolumeType.SUBTRACTIVE:
			if volume.point_is_inside(point):
				return true
	return false

## Get terrain bounds as AABB.
func get_terrain_bounds() -> AABB:
	var half_size := terrain_size / 2.0
	return AABB(
		Vector3(-half_size.x, 0, -half_size.y),
		Vector3(terrain_size.x, height_scale * 2, terrain_size.y)
	)

## Get total memory usage estimate.
func get_memory_usage() -> int:
	var usage := 1024
	if _cached_base_heightmap:
		usage += _cached_base_heightmap.get_width() * _cached_base_heightmap.get_height() * 4
	for delta in height_delta_maps:
		usage += delta.get_memory_usage()
	for volume in volume_definitions:
		usage += volume.get_memory_usage()
	return usage


## Clear cached data to free memory.
func clear_cache() -> void:
	_cached_base_heightmap = null
	_cached_heightmap_size = 0.0

## Validate the terrain definition.
func is_valid() -> bool:
	if not heightmap_source:
		push_error("TerrainDefinition: No heightmap source")
		return false
	if terrain_size.x <= 0 or terrain_size.y <= 0:
		push_error("TerrainDefinition: Invalid terrain size")
		return false
	if height_scale <= 0:
		push_error("TerrainDefinition: Invalid height scale")
		return false
	return true

## Get summary string for debugging.
func get_summary() -> String:
	return "TerrainDefinition: %dx%d, %d deltas, %d volumes, %d prop rules" % [
		int(terrain_size.x),
		int(terrain_size.y),
		height_delta_maps.size(),
		volume_definitions.size(),
		prop_placement_rules.size()
	]
