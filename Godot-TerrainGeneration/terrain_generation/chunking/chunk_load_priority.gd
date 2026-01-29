## @brief Helper class for prioritized chunk loading.
##
## @details Stores a chunk reference along with its computed load priority.
## Used for sorting chunks by priority before loading them in the chunk manager.
class_name ChunkLoadPriority

## The chunk to be loaded
var chunk: ChunkMeshData

## Priority value (higher = load first)
var priority: float

func _init(p_chunk: ChunkMeshData, p_priority: float) -> void:
	chunk = p_chunk
	priority = p_priority

