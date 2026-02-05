## @brief Abstract strategy for chunk mesh generation.
##
## @details Defines the interface for generating chunk meshes from TerrainDefinition.
## Implementations can use CPU or GPU processing while maintaining a consistent API.
## Follows the Strategy pattern for interchangeable generation algorithms.
@tool
class_name ChunkGenerationStrategy extends RefCounted

enum ProcessorType {
	CPU,
	GPU,
	HYBRID
}

func get_processor_type() -> ProcessorType:
	return ProcessorType.CPU

func generate_chunk(
	_terrain_definition: TerrainDefinition,
	_chunk_coord: Vector2i,
	_chunk_size: Vector2,
	_lod_level: int,
	_base_resolution: int
) -> ChunkMeshData:
	push_error("ChunkGenerationStrategy.generate_chunk() must be overridden")
	return null

func supports_async() -> bool:
	return false

func dispose() -> void:
	pass

func calculate_resolution_for_lod(base_resolution: int, lod_level: int) -> int:
	var min_resolution := 4
	var divisor := 1 << lod_level
	return maxi(int(float(base_resolution) / float(divisor)), min_resolution)

func calculate_chunk_bounds(
	terrain_definition: TerrainDefinition,
	chunk_coord: Vector2i,
	chunk_size: Vector2
) -> AABB:
	var terrain_size := terrain_definition.terrain_size
	var half_terrain := terrain_size / 2.0
	var chunk_origin := Vector3(
		chunk_coord.x * chunk_size.x - half_terrain.x,
		0,
		chunk_coord.y * chunk_size.y - half_terrain.y
	)
	var height_range := terrain_definition.height_scale * 2.0
	return AABB(
		Vector3(chunk_origin.x, -height_range, chunk_origin.z),
		Vector3(chunk_size.x, height_range * 2.0, chunk_size.y)
	)

