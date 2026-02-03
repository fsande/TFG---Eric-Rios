## @brief Base class for terrain modifier pipeline stages.
##
## @details Stages control how agents are executed (sequentially, in parallel, conditionally).
## Subclasses implement specific execution patterns.
@tool @abstract
class_name TerrainModifierStage extends Resource

signal stage_started(stage_name: String)
signal stage_completed(stage_name: String, elapsed_ms: float)
signal stage_failed(stage_name: String, error: String)
signal agent_started(agent_name: String)
signal agent_completed(agent_name: String, result: TerrainModifierResult)

@export var stage_name: String = ""
@export var enabled: bool = true
@export var continue_on_agent_failure: bool = false
@export var log_agent_stats: bool = true

var _is_executing: bool = false

@abstract func execute(_context: TerrainGenerationContext, _definition: TerrainDefinition) -> bool

func validate() -> bool:
	var agents := get_agents()
	if agents.is_empty():
		push_warning("%s: Stage has no agents" % _get_display_name())
		return false
	return true

@abstract func get_agents() -> Array[TerrainModifierAgent]

func is_executing() -> bool:
	return _is_executing

func _execute_agent(agent: TerrainModifierAgent, context: TerrainGenerationContext, definition: TerrainDefinition) -> TerrainModifierResult:
	if not agent.enabled:
		return TerrainModifierResult.create_success(0.0, "Agent disabled")
	agent_started.emit(agent.get_display_name())
	if not agent.validate(context):
		return TerrainModifierResult.create_failure("Validation failed")
	var start_time := Time.get_ticks_msec()
	var result := agent.generate(context)
	result.elapsed_time_ms = Time.get_ticks_msec() - start_time
	_apply_result_to_definition(result, definition, agent.get_display_name())
	agent_completed.emit(agent.get_display_name(), result)
	if log_agent_stats:
		print("  Agent '%s': %s" % [agent.get_display_name(), result.get_summary()])
	return result

func _apply_result_to_definition(result: TerrainModifierResult, definition: TerrainDefinition, agent_name: String) -> void:
	for delta in result.height_deltas:
		delta.source_agent = agent_name
		definition.add_height_delta(delta)
	for volume in result.volumes:
		volume.source_agent = agent_name
		definition.add_volume(volume)
	for rule in result.prop_rules:
		definition.add_prop_rule(rule)

func _get_display_name() -> String:
	if stage_name != "":
		return stage_name
	return get_script().get_global_name() if get_script() else "UnknownStage"

