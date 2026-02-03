## @brief Type-safe container for chunk generation request data.
class_name ChunkRequest extends RefCounted

enum RequestState {
	PENDING,
	IN_PROGRESS,
	COMPLETED,
	CANCELLED,
	FAILED
}

var coord: Vector2i
var chunk_size: Vector2
var lod_level: int
var priority: float
var state: RequestState
var task_id: int
var request_time_ms: int

func _init(
	p_coord: Vector2i,
	p_chunk_size: Vector2,
	p_lod_level: int,
	p_priority: float = 0.0
) -> void:
	coord = p_coord
	chunk_size = p_chunk_size
	lod_level = p_lod_level
	priority = p_priority
	state = RequestState.PENDING
	task_id = -1
	request_time_ms = Time.get_ticks_msec()

func get_key() -> String:
	return "%d,%d,%d" % [coord.x, coord.y, lod_level]

func mark_in_progress(p_task_id: int) -> void:
	state = RequestState.IN_PROGRESS
	task_id = p_task_id

func mark_completed() -> void:
	state = RequestState.COMPLETED

func mark_cancelled() -> void:
	state = RequestState.CANCELLED

func mark_failed() -> void:
	state = RequestState.FAILED

func is_pending() -> bool:
	return state == RequestState.PENDING

func is_in_progress() -> bool:
	return state == RequestState.IN_PROGRESS

func is_active() -> bool:
	return state == RequestState.PENDING or state == RequestState.IN_PROGRESS

func get_elapsed_ms() -> int:
	return Time.get_ticks_msec() - request_time_ms

static func compare_priority(a: ChunkRequest, b: ChunkRequest) -> bool:
	return a.priority < b.priority

