## @brief Base class for terrain modifier agents in the new architecture.
##
## @details Agents generate resolution-independent terrain modifications:
## - Height deltas (2D height changes)
## - Volumes (3D topology changes)
## - Prop rules (object placement)
@tool @abstract
class_name TerrainModifierAgent extends Resource

## Type of modification this agent produces
enum ModifierType {
	HEIGHT_DELTA,       
	VOLUME_SUBTRACTIVE, 
	VOLUME_ADDITIVE,    
	PROP_PLACEMENT,     
	COMPOSITE           ## Produces multiple types
}

## Emitted during generation to report progress
signal progress_updated(progress: float, message: String)

## Whether this agent is enabled
@export var enabled: bool = true

## Human-readable name for the agent
@export var agent_name: String = ""

## Priority for ordering (higher = executed later)
@export var priority: int = 0

## Tokens for resource budgeting
@export var tokens: int = 25

## Get the type of modification this agent produces.
## Must be overridden by subclasses.
func get_modifier_type() -> ModifierType:
	push_error("TerrainModifierAgent.get_modifier_type() must be overridden")
	return ModifierType.HEIGHT_DELTA

## Get agent type identifier string.
func get_agent_type() -> String:
	return "BaseAgent"

## Get display name.
func get_display_name() -> String:
	if agent_name != "":
		return agent_name
	return get_agent_type()

## Validate agent configuration.
## @param context Generation context
## @return True if agent is properly configured
func validate(_context: TerrainGenerationContext) -> bool:
	return enabled

## Generate modifications. Called by TerrainDefinitionGenerator.
## @param context Generation context with terrain info
## @return TerrainModifierResult with generated data
func generate(_context: TerrainGenerationContext) -> TerrainModifierResult:
	push_error("TerrainModifierAgent.generate() must be overridden")
	return TerrainModifierResult.create_failure("Not implemented")

## Get metadata about this agent.
func get_metadata() -> Dictionary:
	return {
		"agent_type": get_agent_type(),
		"name": get_display_name(),
		"enabled": enabled,
		"priority": priority,
		"modifier_type": ModifierType.keys()[get_modifier_type()]
	}

