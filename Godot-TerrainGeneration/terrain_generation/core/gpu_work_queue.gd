## Manages GPU work items that must be executed on the main thread.
## Worker threads can queue GPU operations which will be processed during _process.
@tool
extends Node

signal work_completed(work_id: int, result: Variant)

class GpuWorkItem extends RefCounted:
	var id: int
	var callable: Callable
	var completed: bool = false
	var result: Variant = null
	var semaphore: Semaphore = null
	
	func _init(p_id: int, p_callable: Callable) -> void:
		id = p_id
		callable = p_callable
		semaphore = Semaphore.new()

static var _instance: GpuWorkQueue = null

var _work_queue: Array[GpuWorkItem] = []
var _queue_mutex: Mutex = Mutex.new()
var _next_work_id: int = 0
var _main_thread_id: int = -1

static func get_singleton() -> GpuWorkQueue:
	return _instance

func _enter_tree() -> void:
	_instance = self
	_main_thread_id = OS.get_thread_caller_id()

func _exit_tree() -> void:
	_instance = null

func is_main_thread() -> bool:
	return OS.get_thread_caller_id() == _main_thread_id

func _process(_delta: float) -> void:
	_process_pending_work()

func _process_pending_work() -> void:
	_queue_mutex.lock()
	var items_to_process := _work_queue.duplicate()
	_work_queue.clear()
	_queue_mutex.unlock()
	for item in items_to_process:
		if item.completed:
			continue
		item.result = item.callable.call()
		item.completed = true
		item.semaphore.post()
		work_completed.emit(item.id, item.result)

func queue_gpu_work(callable: Callable) -> GpuWorkItem:
	_queue_mutex.lock()
	var work_id := _next_work_id
	_next_work_id += 1
	var item := GpuWorkItem.new(work_id, callable)
	_work_queue.append(item)
	_queue_mutex.unlock()
	return item

func execute_on_main_thread(callable: Callable) -> Variant:
	if is_main_thread():
		return callable.call()
	var item := queue_gpu_work(callable)
	item.semaphore.wait()
	return item.result

func execute_on_main_thread_async(callable: Callable) -> GpuWorkItem:
	if is_main_thread():
		var item := GpuWorkItem.new(-1, callable)
		item.result = callable.call()
		item.completed = true
		return item
	return queue_gpu_work(callable)

func get_pending_work_count() -> int:
	_queue_mutex.lock()
	var count := _work_queue.size()
	_queue_mutex.unlock()
	return count

