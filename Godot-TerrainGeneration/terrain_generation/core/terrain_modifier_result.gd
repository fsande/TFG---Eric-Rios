## @brief Result from a terrain modifier agent's generate() call.
##
## @details Contains the generated modifications (deltas, volumes, prop rules)
## along with status and timing information.
class_name TerrainModifierResult extends RefCounted

## Whether generation was successful
var success: bool = false

## Error message if failed
var error_message: String = ""

## Execution time in milliseconds
var elapsed_time_ms: float = 0.0

## Generated height delta maps
var height_deltas: Array[HeightDeltaMap] = []

## Generated volume definitions
var volumes: Array[VolumeDefinition] = []

## Generated prop placement rules
var prop_rules: Array[PropPlacementRule] = []

## Additional metadata
var metadata: Dictionary = {}

## Create a successful result.
static func create_success(
	p_elapsed_time_ms: float = 0.0,
	p_message: String = "",
	p_metadata: Dictionary = {}
) -> TerrainModifierResult:
	var result := TerrainModifierResult.new()
	result.success = true
	result.elapsed_time_ms = p_elapsed_time_ms
	result.error_message = p_message
	result.metadata = p_metadata
	return result

## Create a failed result.
static func create_failure(
	p_error: String,
	p_elapsed_time_ms: float = 0.0
) -> TerrainModifierResult:
	var result := TerrainModifierResult.new()
	result.success = false
	result.error_message = p_error
	result.elapsed_time_ms = p_elapsed_time_ms
	return result

## Add a height delta to the result.
func add_height_delta(delta: HeightDeltaMap) -> void:
	if delta:
		height_deltas.append(delta)

## Add a volume to the result.
func add_volume(volume: VolumeDefinition) -> void:
	if volume:
		volumes.append(volume)

## Add a prop rule to the result.
func add_prop_rule(rule: PropPlacementRule) -> void:
	if rule:
		prop_rules.append(rule)

## Check if result has any generated content.
func has_content() -> bool:
	return not height_deltas.is_empty() or not volumes.is_empty() or not prop_rules.is_empty()

## Get summary string.
func get_summary() -> String:
	if not success:
		return "Failed: %s" % error_message
	var parts: Array[String] = []
	if not height_deltas.is_empty():
		parts.append("%d height delta(s)" % height_deltas.size())
	if not volumes.is_empty():
		parts.append("%d volume(s)" % volumes.size())
	if not prop_rules.is_empty():
		parts.append("%d prop rule(s)" % prop_rules.size())
	if parts.is_empty():
		return "Success (no output)"
	return "Success: %s in %.1f ms" % [", ".join(parts), elapsed_time_ms]

