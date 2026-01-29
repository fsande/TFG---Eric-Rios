## @brief Configuration resource for terrain chunking and LOD settings.
##
## @details Defines chunk size, loading strategies, LOD parameters,
## and collision settings for chunked terrain rendering.
@tool
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
## Enable LOD generation per chunk
@export var enable_lod: bool = true

## Number of LOD levels to generate (1 = no LOD)
@export_range(1, 5) var lod_level_count: int = 3

## Distance thresholds for LOD transitions (in world units)
@export var lod_distances: Array[float] = [100.0, 200.0, 400.0, 800.0]

## Mesh reduction ratios per LOD level (1.0 = full detail, 0.1 = 10% triangles)
@export var lod_reduction_ratios: Array[float] = [1.0, 0.5, 0.25, 0.1]

## LOD generation strategy configuration (determines which algorithm is used)
@export var lod_generation_strategy_config: LODGenerationStrategyConfiguration = GridDecimationLODStrategyConfiguration.new():
	set(value):
		lod_generation_strategy_config = value
		if lod_generation_strategy_config == null:
			lod_generation_strategy_config = GridDecimationLODStrategyConfiguration.new()

## Enable smooth LOD transitions (cross-fade or geomorphing)
@export var smooth_lod_transitions: bool = false

## LOD transition duration in seconds
@export_range(0.0, 2.0) var lod_transition_time: float = 0.3

## LOD hysteresis factor to prevent oscillation (1.0 = no hysteresis, 1.1 = 10% hysteresis)
@export_range(1.0, 2.0) var lod_hysteresis_factor: float = 1.1

## Memory budget for LOD meshes (MB)
@export_range(50, 1000) var lod_memory_budget_mb: int = 200

@export_group("Collision")
## Generate collision for chunks within this distance
@export var collision_distance: float = 100.0

## Use simplified collision for distant chunks
@export var use_simplified_collision: bool = true

## Validate configuration settings
func is_valid() -> bool:
	if chunk_size.x <= 0.0 or chunk_size.y <= 0.0:
		return false
	if load_strategy_config and not load_strategy_config.is_valid():
		return false
	return true

func get_strategy() -> ChunkLoadStrategy:
	if load_strategy_config:
		return load_strategy_config.get_strategy()
	return null

func get_lod_strategy() -> LODGenerationStrategy:
	if lod_generation_strategy_config:
		return lod_generation_strategy_config.get_strategy()
	return null

