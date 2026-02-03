## @brief Type-safe container for chunk data ready for instantiation.
class_name ChunkReadyData extends RefCounted

var coord: Vector2i
var lod: int
var chunk: ChunkMeshData
var priority: float

func _init(p_coord: Vector2i, p_lod: int, p_chunk: ChunkMeshData, p_priority: float = 0.0) -> void:
	coord = p_coord
	lod = p_lod
	chunk = p_chunk
	priority = p_priority

static func compare_priority(a: ChunkReadyData, b: ChunkReadyData) -> bool:
	return a.priority < b.priority

