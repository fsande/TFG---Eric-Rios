## @brief Executes agents one after another in sequence.
##
## @details Each agent sees the results of previous agents. Execution stops
## on first failure unless continue_on_agent_failure is enabled.
@tool
class_name SequentialStage extends PipelineStage

## Ordered list of agents to execute.
@export var agents: Array[MeshModifierAgent] = []
## Whether to sort agents by priority before execution.
@export var respect_agent_priority: bool = false

## Execute all agents sequentially.
func execute(context: MeshModifierContext) -> bool:
	_is_executing = true
	stage_started.emit(_get_display_name())
	
	var start_time := Time.get_ticks_msec()
	var sorted_agents := agents.duplicate()
	
	# Sort by priority if requested
	if respect_agent_priority:
		sorted_agents.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Execute each agent
	for agent in sorted_agents:
		if not agent.enabled:
			continue
		
		var result := _execute_agent(agent, context)
		context.add_execution_stat(agent._get_display_name(), result.elapsed_time_ms, result.is_success())
		if result.is_failure():
			if not continue_on_agent_failure:
				_is_executing = false
				var error_msg := "Agent '%s' failed: %s" % [agent._get_display_name(), result.message]
				stage_failed.emit(_get_display_name(), error_msg)
				return false
			else:
				push_warning("Agent '%s' failed but continuing: %s" % [agent._get_display_name(), result.message])
	
	var elapsed := Time.get_ticks_msec() - start_time
	_is_executing = false
	stage_completed.emit(_get_display_name(), elapsed)
	return true

## Validate stage has at least one enabled agent.
func validate() -> bool:
	if agents.is_empty():
		push_warning("%s: No agents in stage" % _get_display_name())
		return false
	
	var has_enabled := false
	for agent in agents:
		if agent.enabled:
			has_enabled = true
			break
	
	if not has_enabled:
		push_warning("%s: No enabled agents in stage" % _get_display_name())
		return false
	
	return true

## Get all agents in this stage.
func get_agents() -> Array[MeshModifierAgent]:
	return agents

## Add agent to end of sequence.
func add_agent(agent: MeshModifierAgent) -> void:
	agents.append(agent)

## Insert agent at specific position.
func insert_agent(index: int, agent: MeshModifierAgent) -> void:
	if index >= 0 and index <= agents.size():
		agents.insert(index, agent)

## Remove agent by index.
func remove_agent(index: int) -> void:
	if index >= 0 and index < agents.size():
		agents.remove_at(index)

## Clear all agents.
func clear_agents() -> void:
	agents.clear()
