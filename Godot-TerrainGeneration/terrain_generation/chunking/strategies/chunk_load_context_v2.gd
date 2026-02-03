class_name ChunkLoadContextV2 extends RefCounted

var terrain_size: Vector2
var chunk_size: Vector2
var loaded_chunks: Dictionary[Vector2i, LoadedChunkState]
var lod_distances: PackedFloat32Array
var max_lod_level: int
var terrain_position: Vector3

func _init(
	p_terrain_size: Vector2,
	p_chunk_size: Vector2,
	p_loaded_chunks: Dictionary[Vector2i, LoadedChunkState],
	p_lod_distances: PackedFloat32Array,
	p_max_lod_level: int,
	p_terrain_position: Vector3 = Vector3.ZERO
) -> void:
	terrain_size = p_terrain_size
	chunk_size = p_chunk_size
	loaded_chunks = p_loaded_chunks
	lod_distances = p_lod_distances
	max_lod_level = p_max_lod_level
	terrain_position = p_terrain_position
