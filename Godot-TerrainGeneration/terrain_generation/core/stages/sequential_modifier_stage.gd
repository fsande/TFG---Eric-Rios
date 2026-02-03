## @brief Executes agents one after another in sequence.
##
## @details Each agent sees the results of previous agents. Execution stops
## on first failure unless continue_on_agent_failure is enabled.
@tool
class_name SequentialModifierStage extends TerrainModifierStage

@export var agents: Array[TerrainModifierAgent] = []
@export var respect_agent_priority: bool = false

func execute(context: TerrainGenerationContext, definition: TerrainDefinition) -> bool:
	_is_executing = true
	stage_started.emit(_get_display_name())
	var start_time := Time.get_ticks_msec()
	var sorted_agents := agents.duplicate()
	if respect_agent_priority:
		sorted_agents.sort_custom(func(a, b): return a.priority > b.priority)
	for agent in sorted_agents:
		if not agent.enabled:
			continue
		var result := _execute_agent(agent, context, definition)
		if not result.success:
			if not continue_on_agent_failure:
				_is_executing = false
				var error_msg := "Agent '%s' failed: %s" % [agent.get_display_name(), result.error_message]
				stage_failed.emit(_get_display_name(), error_msg)
				return false
			else:
				push_warning("Agent '%s' failed but continuing: %s" % [agent.get_display_name(), result.error_message])
	var elapsed := Time.get_ticks_msec() - start_time
	_is_executing = false
	stage_completed.emit(_get_display_name(), elapsed)
	return true

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

func get_agents() -> Array[TerrainModifierAgent]:
	return agents

func add_agent(agent: TerrainModifierAgent) -> void:
	agents.append(agent)

func insert_agent(index: int, agent: TerrainModifierAgent) -> void:
	if index >= 0 and index <= agents.size():
		agents.insert(index, agent)

func remove_agent(index: int) -> void:
	if index >= 0 and index < agents.size():
		agents.remove_at(index)

