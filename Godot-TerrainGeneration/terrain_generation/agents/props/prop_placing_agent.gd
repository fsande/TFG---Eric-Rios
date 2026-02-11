@tool
class_name PropPlacingAgent extends TerrainModifierAgent

@export var rule: PropPlacementRule = PropPlacementRule.new()

## Get the type of modification this agent produces.
func get_modifier_type() -> ModifierType:
	return ModifierType.PROP_PLACEMENT

## Get agent type identifier string.
func get_agent_type() -> String:
	return "PropPlacingAgent"
