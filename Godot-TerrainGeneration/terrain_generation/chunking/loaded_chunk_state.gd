## @brief Type-safe container for loaded chunk state.
class_name LoadedChunkState extends RefCounted

var lod: int
var chunk: ChunkMeshData

func _init(p_lod: int, p_chunk: ChunkMeshData) -> void:
	lod = p_lod
	chunk = p_chunk

