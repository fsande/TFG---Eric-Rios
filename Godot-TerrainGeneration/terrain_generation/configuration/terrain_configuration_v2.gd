## @brief Configuration resource for terrain generation pipeline.
##
## Holds references to heightmap sources, mesh generation parameters, visual
## settings and performance-related options. Signals when configuration changes.
@tool
class_name TerrainConfigurationV2 extends Resource

signal configuration_changed()
signal load_strategy_changed()

@export_group("Terrain Source")
@export var heightmap_source: HeightmapSource = NoiseHeightmapSource.new():
	set(value):
		heightmap_source = value
		heightmap_source.heightmap_changed.connect(configuration_changed.emit)
		configuration_changed.emit()

@export var terrain_size: Vector2 = Vector2(256, 256):
	set(value):
		terrain_size = value
		configuration_changed.emit()

@export var height_scale: float = 64.0:
	set(value):
		height_scale = value
		configuration_changed.emit()
@export var generation_seed: int = 0:
	set(value):
		generation_seed = value
		configuration_changed.emit()

@export_group("Pipeline Stages)")
@export var modifier_stages: Array[TerrainModifierStage] = []

@export_group("Props")
## Prop placement rules to apply to the terrain
@export var prop_placement_rules: Array[PropPlacementRule] = []

@export_group("Chunking")
@export var chunk_size: Vector2 = Vector2(64, 64)
@export var base_chunk_resolution: int = 64
@export var cache_size_mb: float = 200.0
@export var load_strategy: ChunkLoadStrategyV2 = GridLoadStrategyV2.new():
	set(value):
		load_strategy = value
		load_strategy_changed.emit()

@export_group("Async Loading")
@export var use_async_loading: bool = true
@export_range(1, 64) var max_concurrent_chunk_requests: int = 4
@export_range(1.0, 10.0, 0.5, "suffix:ms") var chunk_instantiation_budget_ms: float = 5.0

@export_group("GPU Acceleration")
@export var use_gpu_heightmap: bool = false
@export var use_gpu_mesh_generation: bool = false

@export_group("LOD")
@export var enable_lod: bool = true
@export var lod_distances: Array[float] = [50.0, 100.0, 200.0, 400.0]
@export_range(0.0, 0.5) var lod_hysteresis: float = 0.1

@export_group("Visuals")
@export var terrain_material: Material

@export_group("Collision")
@export var generate_collision: bool = true
@export_flags_3d_physics var collision_layers: int = 1

@export_group("Settings")
@export var auto_generate: bool = true
@export var show_debug_info: bool = false
@export var track_camera: bool = true
@export var update_interval: float = 0.2
