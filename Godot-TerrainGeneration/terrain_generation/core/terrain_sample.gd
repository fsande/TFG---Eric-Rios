## @brief Data container for terrain sampling results.
##
## @details Holds height and normal information for a specific point on terrain.
class_name TerrainSample extends RefCounted

## The height (Y coordinate) at the sampled position
var height: float = 0.0

## The terrain normal at the sampled position
var normal: Vector3 = Vector3.UP

## Whether the sample is valid (within terrain bounds)
var is_valid: bool = false

func _init(p_height: float = 0.0, p_normal: Vector3 = Vector3.UP, p_is_valid: bool = true) -> void:
	height = p_height
	normal = p_normal
	is_valid = p_is_valid

## Create an invalid sample (out of bounds)
static func invalid() -> TerrainSample:
	return TerrainSample.new(0.0, Vector3.UP, false)

