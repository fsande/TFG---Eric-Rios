## @brief Composite condition that combines multiple conditions with AND, OR, NOT.
@tool
class_name CompositeCondition extends TerrainCondition

enum Operator { AND, OR }

@export var operator: Operator = Operator.AND
@export var conditions: Array[TerrainCondition] = []

func evaluate(context: TerrainGenerationContext) -> bool:
	if conditions.is_empty():
		return _apply_invert(true)
	var result: bool
	if operator == Operator.AND:
		result = true
		for condition in conditions:
			if not condition.evaluate(context):
				result = false
				break
	else:
		result = false
		for condition in conditions:
			if condition.evaluate(context):
				result = true
				break
	return _apply_invert(result)

func get_description() -> String:
	if condition_name != "":
		return condition_name
	var op_str := "AND" if operator == Operator.AND else "OR"
	var parts: Array[String] = []
	for condition in conditions:
		parts.append(condition.stringify())
	return "(%s)" % (" %s " % op_str).join(parts)

