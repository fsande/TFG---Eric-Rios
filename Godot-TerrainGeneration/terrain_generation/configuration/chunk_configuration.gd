## @brief Configuration resource for terrain chunking and LOD settings.
##
## @details Defines chunk size, loading strategies, LOD parameters,
## and collision settings for chunked terrain rendering.
class_name ChunkConfiguration extends Resource

## Size of each chunk in world units (XZ plane)
@export var chunk_size: Vector2 = Vector2(100.0, 100.0)

## Enable the chunking system
@export var enable_chunking: bool = false

## Chunk loading strategy configuration (determines which strategy is used)
@export var load_strategy_config: ChunkLoadStrategyConfiguration = GridLoadStrategyConfiguration.new():
	set(value):
		load_strategy_config = value
		if load_strategy_config == null:
			load_strategy_config = GridLoadStrategyConfiguration.new()

@export_group("LOD Settings")
## Enable Godot's automatic LOD generation per chunk
@export var enable_lod: bool = true

## Normal merge angle for LOD generation (degrees)
@export_range(0.0, 180.0) var lod_normal_merge_angle: float = 60.0

## Normal split angle for LOD generation (degrees)
@export_range(0.0, 90.0) var lod_normal_split_angle: float = 25.0

@export_group("Collision")
## Generate collision for chunks within this distance
@export var collision_distance: float = 100.0

## Use simplified collision for distant chunks
@export var use_simplified_collision: bool = true

@export_group("Performance")
## Maximum chunks to load per frame
@export_range(1, 10) var max_chunks_load_per_frame: int = 2

## Maximum chunks to unload per frame
@export_range(1, 20) var max_chunks_unload_per_frame: int = 4

## Chunk visibility update frequency (Hz)
@export_range(1.0, 60.0) var update_frequency: float = 10.0

## Validate configuration settings
func is_valid() -> bool:
	if chunk_size.x <= 0.0 or chunk_size.y <= 0.0:
		return false
	if load_strategy_config and not load_strategy_config.is_valid():
		return false
	return true

