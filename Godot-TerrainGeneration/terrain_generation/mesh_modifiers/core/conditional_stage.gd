## @brief Executes different agents based on runtime conditions.
##
## @details Enables branching logic in pipelines. Evaluates condition and executes
## the appropriate agent list.
@tool
class_name ConditionalStage extends PipelineStage

## Condition to evaluate.
@export var condition: AgentCondition
## Agents to execute if condition is true.
@export var agents_if_true: Array[MeshModifierAgent] = []
## Agents to execute if condition is false.
@export var agents_if_false: Array[MeshModifierAgent] = []
## How to execute selected agents.
@export_enum("Sequential", "Parallel") var execution_mode: int = 0  # 0 = Sequential, 1 = Parallel

## Execute conditional stage.
func execute(context: MeshModifierContext) -> bool:
	_is_executing = true
	stage_started.emit(_get_display_name())
	
	var start_time := Time.get_ticks_msec()
	
	# Evaluate condition
	if not condition:
		push_error("%s: No condition specified" % _get_display_name())
		_is_executing = false
		stage_failed.emit(_get_display_name(), "No condition specified")
		return false
	
	var condition_result := condition.evaluate(context)
	var selected_agents := agents_if_true if condition_result else agents_if_false
	
	if log_agent_stats:
		print("Condition '%s' evaluated to: %s" % [condition.stingify(), condition_result])
	
	# Execute selected agents
	var success := false
	if execution_mode == 0:  # Sequential
		success = _execute_agents_sequential(selected_agents, context)
	else:  # Parallel
		success = _execute_agents_parallel(selected_agents, context)
	
	var elapsed := Time.get_ticks_msec() - start_time
	_is_executing = false
	
	if success:
		stage_completed.emit(_get_display_name(), elapsed)
	else:
		stage_failed.emit(_get_display_name(), "Agent execution failed")
	
	return success

## Validate stage configuration.
func validate() -> bool:
	if not condition:
		push_error("%s: No condition specified" % _get_display_name())
		return false
	
	if agents_if_true.is_empty() and agents_if_false.is_empty():
		push_warning("%s: Both agent lists are empty" % _get_display_name())
		return false
	
	return true

## Get all agents (both branches).
func get_agents() -> Array[MeshModifierAgent]:
	var all_agents: Array[MeshModifierAgent] = []
	all_agents.append_array(agents_if_true)
	all_agents.append_array(agents_if_false)
	return all_agents

## Internal: Execute agents sequentially.
func _execute_agents_sequential(agent_list: Array[MeshModifierAgent], context: MeshModifierContext) -> bool:
	for agent in agent_list:
		if not agent.enabled:
			continue
		
		var result := _execute_agent(agent, context)
		context.add_execution_stat(agent._get_display_name(), result.elapsed_time_ms, result.is_failure())
		
		if result.is_failure() and not continue_on_agent_failure:
			return false
	
	return true

## Internal: Execute agents in parallel.
func _execute_agents_parallel(agent_list: Array[MeshModifierAgent], context: MeshModifierContext) -> bool:
	# For now, fallback to sequential (parallel implementation requires thread safety)
	push_warning("%s: Parallel execution not yet implemented, using sequential" % _get_display_name())
	return _execute_agents_sequential(agent_list, context)
