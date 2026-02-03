## @brief Executes different agents based on runtime conditions.
##
## @details Enables branching logic in pipelines. Evaluates condition and executes
## the appropriate agent list.
@tool
class_name ConditionalModifierStage extends TerrainModifierStage

@export var condition: TerrainCondition
@export var agents_if_true: Array[TerrainModifierAgent] = []
@export var agents_if_false: Array[TerrainModifierAgent] = []
@export_enum("Sequential", "Parallel") var execution_mode: int = 0

func execute(context: TerrainGenerationContext, definition: TerrainDefinition) -> bool:
	_is_executing = true
	stage_started.emit(_get_display_name())
	var start_time := Time.get_ticks_msec()
	if not condition:
		push_error("%s: No condition specified" % _get_display_name())
		_is_executing = false
		stage_failed.emit(_get_display_name(), "No condition specified")
		return false
	var condition_result := condition.evaluate(context)
	var selected_agents := agents_if_true if condition_result else agents_if_false
	if log_agent_stats:
		print("  Condition '%s' evaluated to: %s" % [condition.stringify(), condition_result])
	var success := false
	if execution_mode == 0:
		success = _execute_agents_sequential(selected_agents, context, definition)
	else:
		success = _execute_agents_parallel(selected_agents, context, definition)
	var elapsed := Time.get_ticks_msec() - start_time
	_is_executing = false
	if success:
		stage_completed.emit(_get_display_name(), elapsed)
	else:
		stage_failed.emit(_get_display_name(), "Agent execution failed")
	return success

func validate() -> bool:
	if not condition:
		push_error("%s: No condition specified" % _get_display_name())
		return false
	if agents_if_true.is_empty() and agents_if_false.is_empty():
		push_warning("%s: Both agent lists are empty" % _get_display_name())
		return false
	return true

func get_agents() -> Array[TerrainModifierAgent]:
	var all_agents: Array[TerrainModifierAgent] = []
	all_agents.append_array(agents_if_true)
	all_agents.append_array(agents_if_false)
	return all_agents

func _execute_agents_sequential(agent_list: Array[TerrainModifierAgent], context: TerrainGenerationContext, definition: TerrainDefinition) -> bool:
	for agent in agent_list:
		if not agent.enabled:
			continue
		var result := _execute_agent(agent, context, definition)
		if not result.success and not continue_on_agent_failure:
			return false
	return true

func _execute_agents_parallel(agent_list: Array[TerrainModifierAgent], context: TerrainGenerationContext, definition: TerrainDefinition) -> bool:
	var parallel_stage := ParallelModifierStage.new()
	parallel_stage.agents = agent_list
	parallel_stage.continue_on_agent_failure = continue_on_agent_failure
	parallel_stage.log_agent_stats = log_agent_stats
	return parallel_stage.execute(context, definition)

