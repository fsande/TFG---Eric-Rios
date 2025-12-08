## @brief Condition that checks if specific analysis data exists in context.
##
## @details Common condition for checking if required data was produced by previous agents.
@tool
class_name DataExistsCondition extends AgentCondition

## The data key to check for in analysis_data.
@export var data_key: String = ""

## Evaluate if data exists in context.
func evaluate(context: MeshModifierContext) -> bool:
	if data_key == "":
		push_warning("DataExistsCondition: No data_key specified")
		return _apply_invert(false)
	
	var exists := context.has_analysis_data(data_key)
	return _apply_invert(exists)

## Get description.
func get_description() -> String:
	if condition_name != "":
		return condition_name
	return "Data '%s' exists" % data_key

