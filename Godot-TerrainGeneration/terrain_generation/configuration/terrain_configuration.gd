## @brief Configuration resource for terrain generation pipeline.
##
## Holds references to heightmap sources, mesh generation parameters, visual
## settings and performance-related options. Signals when configuration changes.
@tool
class_name TerrainConfiguration extends Resource

## Emitted when any configuration value changes.
signal configuration_changed()

@export_group("Heightmap Generation")
## Heightmap source resource used to produce heightmaps.
@export var heightmap_source: HeightmapSource = NoiseHeightmapSource.new():
	set(value):
		if heightmap_source and heightmap_source.heightmap_changed.is_connected(_on_heightmap_changed):
			heightmap_source.heightmap_changed.disconnect(_on_heightmap_changed)
		heightmap_source = value
		if heightmap_source:
			heightmap_source.heightmap_changed.connect(_on_heightmap_changed)
		configuration_changed.emit()

## Size in world units of the terrain to generate (square).
@export var terrain_size: float = 512.0:
	set(value):
		if value <= 0.0:
			push_error("TerrainConfiguration: terrain_size must be positive, got %f" % value)
			return
		terrain_size = value
		if mesh_generator_parameters == null:
			mesh_generator_parameters = MeshGeneratorParameters.new()
		mesh_generator_parameters.mesh_size = Vector2(value, value)
		configuration_changed.emit()

@export var generation_seed: int = 0:
	set(value):
		generation_seed = value
		configuration_changed.emit()

@export_group("MeshModification")
@export var mesh_modification_pipeline: MeshModifierPipeline:
	set(value):
		mesh_modification_pipeline = value
		configuration_changed.emit()

@export_group("Mesh Generation")
## Number of subdivisions for the generated plane mesh.
@export var mesh_generator_parameters: MeshGeneratorParameters = MeshGeneratorParameters.new():
	set(value):
		mesh_generator_parameters = value
		configuration_changed.emit()

@export_group("Visuals")
## Height threshold for snow material application.
@export_range(0.0, 2800.0, 1.0) var snow_line: float = 64.0:
	set(value):
		snow_line = value
		configuration_changed.emit()

## Material used for the terrain surface.
@export var terrain_material: Material:
	set(value):
		terrain_material = value
		configuration_changed.emit()

@export_group("Collision")
## Whether to generate a collision shape for the terrain.
@export var generate_collision: bool = true:
	set(value):
		generate_collision = value
		configuration_changed.emit()

## Collision layers applied to the generated collision shape.
@export var collision_layers: int = 1:
	set(value):
		collision_layers = value
		configuration_changed.emit()

@export_group("Performance")
## Select whether to use CPU or GPU mesh modifier.
@export var mesh_generator_type: MeshGeneratorType = MeshGeneratorType.CPU:
	set(value):
		mesh_generator_type = value
		configuration_changed.emit()

## Select how to process heightmaps relative to the mesh modifier.
@export var heightmap_processor_type: HeightmapProcessorType = HeightmapProcessorType.MATCH_MESH:
	set(value):
		heightmap_processor_type = value
		configuration_changed.emit()

## Toggle caching of generated terrain.
@export var enable_caching: bool = true

## Mesh generator options.
enum MeshGeneratorType {
	CPU,
	GPU
}

## Heightmap processing options.
enum HeightmapProcessorType {
	MATCH_MESH,  # Automatically use same type as mesh modifier
	CPU,
	GPU
}

func _on_heightmap_changed() -> void:
	configuration_changed.emit()

func is_valid() -> bool:
	return heightmap_source != null

func get_generation_size() -> float:
	return terrain_size

func get_mesh_parameters() -> Dictionary:
	return {
		"height_scale": mesh_generator_parameters.height_scale,
		"mesh_size": mesh_generator_parameters.mesh_size,
		"subdivisions": mesh_generator_parameters.subdivisions
	}

func get_effective_processor_type() -> ProcessingContext.ProcessorType:
	match heightmap_processor_type:
		HeightmapProcessorType.CPU:
			return ProcessingContext.ProcessorType.CPU
		HeightmapProcessorType.GPU:
			return ProcessingContext.ProcessorType.GPU
		HeightmapProcessorType.MATCH_MESH:
			return ProcessingContext.ProcessorType.GPU if mesh_generator_type == MeshGeneratorType.GPU else ProcessingContext.ProcessorType.CPU
		_:
			return ProcessingContext.ProcessorType.CPU
