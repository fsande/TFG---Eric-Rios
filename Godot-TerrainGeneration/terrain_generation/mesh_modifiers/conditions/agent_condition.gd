## @brief Base class for conditions used in ConditionalStage.
##
## @details Enables runtime branching logic based on context state.
@tool
class_name AgentCondition extends Resource

## Human-readable condition name.
@export var condition_name: String = ""
## Whether to invert condition result.
@export var invert: bool = false

## Evaluate condition with given context - MUST be overridden.
func evaluate(context: MeshModifierContext) -> bool:
	push_error("%s: evaluate() must be implemented by subclass" % _get_display_name())
	return false

## Get human-readable description of condition.
func get_description() -> String:
	if condition_name != "":
		return condition_name
	return get_class()

## String representation.
func stingify() -> String:
	var desc := get_description()
	return ("NOT " + desc) if invert else desc

## Internal: Apply invert flag to result.
func _apply_invert(result: bool) -> bool:
	return not result if invert else result

## Internal: Get display name.
func _get_display_name() -> String:
	return get_description()
