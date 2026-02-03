## @brief Executes agents in parallel using worker threads.
##
## @details All agents run simultaneously. Results are collected after all complete.
## Use only for agents that don't have dependencies on each other.
@tool
class_name ParallelModifierStage extends TerrainModifierStage

@export var agents: Array[TerrainModifierAgent] = []
@export var max_threads: int = 4

var _results: Array[TerrainModifierResult] = []
var _mutex: Mutex
var _completed_count: int = 0

func execute(context: TerrainGenerationContext, definition: TerrainDefinition) -> bool:
	_is_executing = true
	stage_started.emit(_get_display_name())
	var start_time := Time.get_ticks_msec()
	var enabled_agents: Array[TerrainModifierAgent] = []
	for agent in agents:
		if agent.enabled:
			enabled_agents.append(agent)
	if enabled_agents.is_empty():
		_is_executing = false
		stage_completed.emit(_get_display_name(), 0.0)
		return true
	_results.clear()
	_results.resize(enabled_agents.size())
	_mutex = Mutex.new()
	_completed_count = 0
	var tasks: Array[int] = []
	for i in range(enabled_agents.size()):
		var task_id := WorkerThreadPool.add_task(
			_execute_agent_threaded.bind(enabled_agents[i], context, i)
		)
		tasks.append(task_id)
	for task_id in tasks:
		WorkerThreadPool.wait_for_task_completion(task_id)
	var all_success := true
	for i in range(_results.size()):
		var result := _results[i]
		if result:
			_apply_result_to_definition(result, definition, enabled_agents[i].get_display_name())
			agent_completed.emit(enabled_agents[i].get_display_name(), result)
			if log_agent_stats:
				print("  Agent '%s': %s" % [enabled_agents[i].get_display_name(), result.get_summary()])
			if not result.success and not continue_on_agent_failure:
				all_success = false
	var elapsed := Time.get_ticks_msec() - start_time
	_is_executing = false
	if all_success:
		stage_completed.emit(_get_display_name(), elapsed)
	else:
		stage_failed.emit(_get_display_name(), "One or more agents failed")
	return all_success

func _execute_agent_threaded(agent: TerrainModifierAgent, context: TerrainGenerationContext, index: int) -> void:
	agent_started.emit(agent.get_display_name())
	var result: TerrainModifierResult
	if not agent.validate(context):
		result = TerrainModifierResult.create_failure("Validation failed")
	else:
		var start_time := Time.get_ticks_msec()
		result = agent.generate(context)
		result.elapsed_time_ms = Time.get_ticks_msec() - start_time
	_mutex.lock()
	_results[index] = result
	_completed_count += 1
	_mutex.unlock()

func validate() -> bool:
	if agents.is_empty():
		push_warning("%s: No agents in stage" % _get_display_name())
		return false
	return true

func get_agents() -> Array[TerrainModifierAgent]:
	return agents

func add_agent(agent: TerrainModifierAgent) -> void:
	agents.append(agent)

