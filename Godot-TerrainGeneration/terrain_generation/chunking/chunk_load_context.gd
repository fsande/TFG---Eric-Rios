## @brief Context data passed to chunk load strategies.
##
## @details Provides type-safe access to runtime information needed
## by chunk loading strategies to make loading/unloading decisions.
class_name ChunkLoadContext extends RefCounted

## Currently loaded chunks (chunk_coord -> MeshInstance3D)
var loaded_chunks: Dictionary

## Time budget for this frame in seconds
var frame_time: float

func _init(p_loaded_chunks: Dictionary, p_frame_time: float) -> void:
	loaded_chunks = p_loaded_chunks
	frame_time = p_frame_time

