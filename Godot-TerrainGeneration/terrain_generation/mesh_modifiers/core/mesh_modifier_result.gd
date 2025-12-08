## @brief Result container for mesh modifier agent operations.
##
## @details Contains execution status, timing, and metadata about what the agent
## accomplished. Used for pipeline tracking and error handling.
class_name MeshModifierResult extends RefCounted

## Whether the agent execution succeeded.
var success: bool
## Elapsed execution time in milliseconds.
var elapsed_time_ms: float
## Human-readable message describing what was done.
var message: String
## Additional metadata about the operation.
var metadata: Dictionary

## Construct a result with execution status and metrics.
func _init(p_success: bool, p_time: float = 0.0, p_message: String = "", p_metadata: Dictionary = {}) -> void:
	success = p_success
	elapsed_time_ms = p_time
	message = p_message
	metadata = p_metadata

## Get statistics dictionary for logging/tracking.
func get_stats() -> Dictionary:
	return {
		"success": success,
		"elapsed_ms": elapsed_time_ms,
		"message": message,
		"metadata": metadata
	}

## Formatted string representation.
func get_formatted_string() -> String:
	var status := "[SUCCESS]" if success else "[FAILURE]"
	return "%s %s (%.2fms)" % [status, message, elapsed_time_ms]

## Check if successful.
func is_success() -> bool:
	return success

## Check if failed.
func is_failure() -> bool:
	return not success

## Create a successful result.
static func create_success(time_ms: float, p_message: String = "", p_metadata: Dictionary = {}) -> MeshModifierResult:
	return MeshModifierResult.new(true, time_ms, p_message, p_metadata)

## Create a failed result.
static func create_failure(p_message: String = "", time_ms: float = -1.0, p_metadata: Dictionary = {}) -> MeshModifierResult:
	return MeshModifierResult.new(false, time_ms, p_message, p_metadata)

## Create a timeout failure result.
static func create_timeout(time_ms: float, agent_name: String) -> MeshModifierResult:
	return MeshModifierResult.new(false, time_ms, "Agent '%s' timed out" % agent_name, {"timeout": true})

## Create a validation failure result.
static func create_validation_failure(agent_name: String, reason: String) -> MeshModifierResult:
	return MeshModifierResult.new(false, 0.0, "Agent '%s' validation failed: %s" % [agent_name, reason], {"validation_error": true})
