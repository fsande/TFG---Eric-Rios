## @brief Abstract base class for different stage execution strategies.
##
## @details Stages control how agents are executed (sequentially, in parallel, conditionally).
## Subclasses implement specific execution patterns.
@tool
class_name PipelineStage extends Resource

## Emitted when stage begins.
signal stage_started(stage_name: String)
## Emitted when stage completes.
signal stage_completed(stage_name: String, elapsed_ms: float)
## Emitted when stage fails.
signal stage_failed(stage_name: String, error: String)
## Emitted when each agent starts.
signal agent_started(agent_name: String)
## Emitted when each agent completes.
signal agent_completed(agent_name: String, result: MeshModifierResult)

## Human-readable stage name.
@export var stage_name: String = ""
## Whether this stage is active.
@export var enabled: bool = true
## Whether to continue if an agent fails.
@export var continue_on_agent_failure: bool = false
## Whether to log individual agent statistics.
@export var log_agent_stats: bool = true

## Internal state
var _is_executing: bool = false

## Execute this stage - MUST be overridden by subclasses.
func execute(context: MeshModifierContext) -> bool:
	push_error("%s: execute() must be implemented by subclass" % _get_display_name())
	return false

## Validate stage configuration.
func validate() -> bool:
	var agents := get_agents()
	if agents.is_empty():
		push_warning("%s: Stage has no agents" % _get_display_name())
		return false
	return true

## Get all agents in this stage - should be overridden.
func get_agents() -> Array[MeshModifierAgent]:
	return []

## Check if stage is currently running.
func is_executing() -> bool:
	return _is_executing

## Internal helper to execute single agent with error handling.
func _execute_agent(agent: MeshModifierAgent, context: MeshModifierContext) -> MeshModifierResult:
	if not agent.enabled:
		return MeshModifierResult.create_success(0.0, "Agent disabled")
	agent_started.emit(agent._get_display_name())
	context.current_agent_name = agent._get_display_name()
	if not agent.validate(context):
		var result := MeshModifierResult.create_validation_failure(agent._get_display_name(), "Validation failed")
		agent.validation_failed.emit("Validation failed")
		return result
	var start_time := Time.get_ticks_msec()
	var result := agent.execute(context)
	if agent._check_timeout(start_time):
		result = MeshModifierResult.create_timeout(Time.get_ticks_msec() - start_time, agent._get_display_name())
	agent._update_stats(result)
	if result.is_success():
		agent.execution_completed.emit(result)
	else:
		agent.execution_failed.emit(result.message)
	agent_completed.emit(agent._get_display_name(), result)
	if log_agent_stats:
		print("  Agent '%s': %s" % [agent._get_display_name(), result.get_formatted_string()])
	return result

## Internal helper to get display name.
func _get_display_name() -> String:
	if stage_name != "":
		return stage_name
	return get_class()
