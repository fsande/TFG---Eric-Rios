## @brief Represents a tunnel entry point on terrain.
##
## @details Stores position, direction, and metadata for a potential tunnel location.
@tool
class_name TunnelEntryPoint extends RefCounted

## World position of the tunnel entrance
var position: Vector3

## Surface normal at the cliff face
var surface_normal: Vector3

## Computed tunnel direction (horizontal, into the cliff)
var tunnel_direction: Vector3

## Slope angle in radians
var slope_angle: float

## UV coordinates on heightmap (0-1 range)
var uv: Vector2

## Pixel coordinates on heightmap
var pixel_x: int
var pixel_y: int

## Construct an entry point
func _init(p_position: Vector3, p_surface_normal: Vector3, p_slope_angle: float, p_uv: Vector2 = Vector2.ZERO, p_pixel_x: int = 0, p_pixel_y: int = 0) -> void:
	position = p_position
	surface_normal = p_surface_normal
	slope_angle = p_slope_angle
	uv = p_uv
	pixel_x = p_pixel_x
	pixel_y = p_pixel_y
	tunnel_direction = Vector3(surface_normal.x, surface_normal.y / 2, surface_normal.z).normalized()

## Check if tunnel direction is valid (not too vertical)
func has_valid_direction() -> bool:
	return tunnel_direction.length() >= 0.1

## Check if tunnel would be within bounds
func is_within_bounds(tunnel_length: float, terrain_size: Vector2) -> bool:
	var tunnel_end := position + tunnel_direction * tunnel_length
	return abs(tunnel_end.x) <= terrain_size.x * 0.4 and abs(tunnel_end.z) <= terrain_size.y * 0.4
  
