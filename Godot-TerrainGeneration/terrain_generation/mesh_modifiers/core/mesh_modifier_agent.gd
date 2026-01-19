## @brief Base abstract class for all mesh modifier agents.
##
## @details Defines the contract that all agents must follow. Agents are self-contained
## operations that read from and write to a MeshModifierContext. They can modify mesh
## geometry, generate scene nodes, or perform analysis.
@tool
class_name MeshModifierAgent extends Resource

## Emitted during execution to report progress (0.0 to 1.0).
signal progress_updated(progress: float, message: String)

## Whether this agent is active in the pipeline.
@export var enabled: bool = true
## Priority for dependency ordering (higher = earlier).
@export var priority: int = 0
## Human-readable name for the agent.
@export var agent_name: String = ""

## Number of processing tokens this agent consumes.
@export var tokens: int = 25

@export_group("Performance")
## Maximum execution time before abort (30 seconds default).
@export var timeout_ms: int = 30000
## Whether to log detailed performance metrics.
@export var log_performance: bool = true

## Internal state
var _execution_count: int = 0
var _total_execution_time: float = 0.0
var _last_result: MeshModifierResult = null

func _init() ->void:
	if agent_name == "":
		agent_name = get_agent_type()

## Main execution method - MUST be overridden by subclasses.
func execute(_context: MeshModifierContext) -> MeshModifierResult:
	push_error("%s: execute() must be implemented by subclass" % get_agent_type())
	return MeshModifierResult.create_failure("execute() not implemented")

## Get agent type identifier (e.g., "RiverGenerator").
## MUST be overridden by subclasses.
func get_agent_type() -> String:
	return "UnknownAgent"

## Validate prerequisites before execution.
## Override to check required data exists, parameters are valid, etc.
func validate(_context: MeshModifierContext) -> bool:
	return false

## Declare what analysis data this agent requires.
## Example: ["water_flow_data", "terrain_analysis"]
func get_required_data_types() -> Array[String]:
	return []

## Declare what analysis data this agent produces.
## Example: ["rivers", "river_paths"]
func get_produced_data_types() -> Array[String]:
	return []

## Whether agent can run in parallel with others.
## Set to false if agent has race conditions or requires exclusive access.
func supports_parallel_execution() -> bool:
	return true

## Whether agent modifies mesh geometry.
func modifies_mesh() -> bool:
	return false

## Whether agent adds nodes to scene tree.
func generates_scene_nodes() -> bool:
	return false

## Cleanup resources after execution.
func cleanup() -> void:
	pass

## Get agent metadata for introspection.
func get_metadata() -> Dictionary:
	return {
		"agent_type": get_agent_type(),
		"name": _get_display_name(),
		"enabled": enabled,
		"priority": priority,
		"modifies_mesh": modifies_mesh(),
		"generates_scene_nodes": generates_scene_nodes(),
		"supports_parallel": supports_parallel_execution(),
		"required_data": get_required_data_types(),
		"produced_data": get_produced_data_types()
	}

## Internal helper to get display name.
func _get_display_name() -> String:
	if agent_name != "":
		return agent_name
	return get_agent_type()

## Internal helper to check timeout.
func _check_timeout(start_time_ms: int) -> bool:
	if timeout_ms <= 0:
		return false
	return (Time.get_ticks_msec() - start_time_ms) > timeout_ms

## Internal helper to update statistics.
func _update_stats(result: MeshModifierResult) -> void:
	_execution_count += 1
	_total_execution_time += result.elapsed_time_ms
	_last_result = result
