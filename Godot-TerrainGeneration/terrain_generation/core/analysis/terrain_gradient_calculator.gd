## @brief Calculates terrain gradients and directional information.
##
## @details Responsible for computing terrain gradients, uphill/downhill directions,
## and related terrain analysis. Uses finite difference methods.
## Follows Single Responsibility Principle - only handles gradient calculations.
class_name TerrainGradientCalculator extends RefCounted

const THRESHOLD_FLATNESS := 0.000001  

## Reference to the context for heightmap access
var _context: TerrainGenerationContext

func _init(context: TerrainGenerationContext) -> void:
	_context = context

## Calculate 2D gradient (XZ plane) at a world position.
## Returns vector pointing in direction of steepest ascent.
## @param world_pos World position (XZ)
## @return Vector2 gradient in XZ plane (not normalized)
func calculate_gradient_at(world_pos: Vector2) -> Vector2:
	if not _context.reference_heightmap:
		return Vector2.ZERO
	var epsilon := _context.terrain_size.x / float(_context.reference_heightmap.get_width())
	var h_center := _context.sample_height_at(world_pos)
	var h_right := _context.sample_height_at(world_pos + Vector2(epsilon, 0))
	var h_forward := _context.sample_height_at(world_pos + Vector2(0, epsilon))
	var dx := (h_right - h_center) / epsilon
	var dz := (h_forward - h_center) / epsilon
	return Vector2(dx, dz)

## Get downhill direction (negative gradient, normalized).
## @param world_pos World position (XZ)
## @return Normalized Vector2 pointing downhill, or ZERO if flat
func calculate_downhill_direction(world_pos: Vector2, threshold := THRESHOLD_FLATNESS) -> Vector2:
	var gradient := calculate_gradient_at(world_pos)
	if gradient.length_squared() < threshold:
		return Vector2.ZERO 
	return -gradient.normalized()

## Get uphill direction (positive gradient, normalized).
## @param world_pos World position (XZ)
## @return Normalized Vector2 pointing uphill, or ZERO if flat
func calculate_uphill_direction(world_pos: Vector2, threshold := THRESHOLD_FLATNESS) -> Vector2:
	var gradient := calculate_gradient_at(world_pos)
	if gradient.length_squared() < threshold:
		return Vector2.ZERO
	return gradient.normalized()

## Calculate gradient magnitude (steepness) at a position.
## @param world_pos World position (XZ)
## @return Gradient magnitude (higher = steeper)
func calculate_gradient_magnitude(world_pos: Vector2) -> float:
	var gradient := calculate_gradient_at(world_pos)
	return gradient.length()

## Check if terrain is flat at a position.
## @param world_pos World position (XZ)
## @param threshold Flatness threshold (default 0.01)
## @return True if gradient magnitude is below threshold
func is_flat_at(world_pos: Vector2, threshold: float = 0.01) -> bool:
	return calculate_gradient_magnitude(world_pos) < threshold

