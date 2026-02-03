## @brief Resolution-independent height modification storage.
##
## @details Stores height modifications as a delta texture that can be
## sampled at any resolution. Used by height-modifying agents to store
## their effects in a resolution-independent way.
@tool
class_name HeightDeltaMap extends Resource

## The delta texture storing height offsets (FORMAT_RF)
## Values are height offsets in world units
@export var delta_texture: Image = null

## World-space bounds where this delta applies
@export var world_bounds: AABB = AABB()

## Optional custom blend strategy (overrides blend_mode if set)
@export var blend_strategy: HeightBlendStrategy = AdditiveBlendStrategy.new()

## Priority for ordering multiple deltas (higher = applied later)
@export var priority: int = 0

## Intensity multiplier for the delta effect
@export var intensity: float = 1.0

## Optional falloff at edges (0 = hard edge, 1 = full falloff)
@export_range(0.0, 1.0) var edge_falloff: float = 0.0

## Metadata about what created this delta
@export var source_agent: String = ""
@export var creation_timestamp: int = 0

## Create a new HeightDeltaMap with specified dimensions.
## @param width Width in pixels
## @param height Height in pixels
## @param bounds World-space bounds
## @return New HeightDeltaMap instance
static func create(width: int, height: int, bounds: AABB) -> HeightDeltaMap:
	var delta := HeightDeltaMap.new()
	delta.delta_texture = Image.create(width, height, false, Image.FORMAT_RF)
	delta.delta_texture.fill(Color(0, 0, 0, 1))
	delta.world_bounds = bounds
	delta.creation_timestamp = int(Time.get_unix_time_from_system())
	return delta

## Sample the delta value at a world position.
## @param world_pos World position (XZ plane)
## @return Delta height value at position, or 0 if outside bounds
func sample_at(world_pos: Vector2) -> float:
	if not delta_texture:
		return 0.0
	if not _is_in_bounds_xz(world_pos):
		return 0.0
	var uv := _world_to_uv(world_pos)
	var raw_value := _sample_bilinear(uv)
	if edge_falloff > 0.0:
		var falloff_factor := _calculate_edge_falloff(uv)
		raw_value *= falloff_factor
	return raw_value * intensity

## Sample delta values for an entire region at specified resolution.
## @param bounds Region bounds to sample
## @param resolution Output resolution
## @return Image with sampled delta values
func sample_region(bounds: AABB, resolution: Vector2i) -> Image:
	var result := Image.create(resolution.x, resolution.y, false, Image.FORMAT_RF)
	if not delta_texture:
		return result
	for y in range(resolution.y):
		for x in range(resolution.x):
			var u := float(x) / float(resolution.x - 1) if resolution.x > 1 else 0.5
			var v := float(y) / float(resolution.y - 1) if resolution.y > 1 else 0.5
			var world_x := lerpf(bounds.position.x, bounds.position.x + bounds.size.x, u)
			var world_z := lerpf(bounds.position.z, bounds.position.z + bounds.size.z, v)
			var delta_value := sample_at(Vector2(world_x, world_z))
			result.set_pixel(x, y, Color(delta_value, 0, 0, 1))
	return result

## Set delta value at a world position.
## @param world_pos World position (XZ plane)
## @param value Delta height value to set
func set_at(world_pos: Vector2, value: float) -> void:
	if not delta_texture:
		return
	if not _is_in_bounds_xz(world_pos):
		return
	var uv := _world_to_uv(world_pos)
	var px := int(uv.x * (delta_texture.get_width() - 1))
	var py := int(uv.y * (delta_texture.get_height() - 1))
	px = clampi(px, 0, delta_texture.get_width() - 1)
	py = clampi(py, 0, delta_texture.get_height() - 1)
	delta_texture.set_pixel(px, py, Color(value, 0, 0, 1))

## Add to delta value at a world position.
## @param world_pos World position (XZ plane)
## @param value Delta value to add
func add_at(world_pos: Vector2, value: float) -> void:
	if not delta_texture:
		return
	if not _is_in_bounds_xz(world_pos):
		return
	var current := sample_at(world_pos)
	set_at(world_pos, current + value)

## Set delta value at UV coordinates.
## @param uv UV coordinates (0-1 range)
## @param value Delta height value
func set_at_uv(uv: Vector2, value: float) -> void:
	if not delta_texture:
		return
	var px := int(uv.x * (delta_texture.get_width() - 1))
	var py := int(uv.y * (delta_texture.get_height() - 1))
	px = clampi(px, 0, delta_texture.get_width() - 1)
	py = clampi(py, 0, delta_texture.get_height() - 1)
	delta_texture.set_pixel(px, py, Color(value, 0, 0, 1))

## Check if this delta map intersects with given bounds.
## @param bounds Bounds to check
## @return True if there's any intersection
func intersects(bounds: AABB) -> bool:
	return world_bounds.intersects(bounds)

## Apply this delta to a height value using the configured blend mode or strategy.
## @param existing_height Current height value
## @param delta_value Delta value to apply
## @return Blended height value
func apply_blend(existing_height: float, delta_value: float) -> float:
	return blend_strategy.blend(existing_height, delta_value, intensity)

## Get memory usage estimate in bytes.
func get_memory_usage() -> int:
	if not delta_texture:
		return 0
	return delta_texture.get_width() * delta_texture.get_height() * 4  # RF = 4 bytes per pixel

## Check if a world XZ position is within bounds.
func _is_in_bounds_xz(world_pos: Vector2) -> bool:
	return (world_pos.x >= world_bounds.position.x and 
			world_pos.x <= world_bounds.position.x + world_bounds.size.x and
			world_pos.y >= world_bounds.position.z and 
			world_pos.y <= world_bounds.position.z + world_bounds.size.z)

## Convert world XZ position to UV coordinates.
func _world_to_uv(world_pos: Vector2) -> Vector2:
	var u := (world_pos.x - world_bounds.position.x) / world_bounds.size.x
	var v := (world_pos.y - world_bounds.position.z) / world_bounds.size.z
	return Vector2(clampf(u, 0.0, 1.0), clampf(v, 0.0, 1.0))

## Bilinear interpolation sampling.
func _sample_bilinear(uv: Vector2) -> float:
	if not delta_texture:
		return 0.0
	var width := delta_texture.get_width()
	var height := delta_texture.get_height()
	var px := uv.x * (width - 1)
	var py := uv.y * (height - 1)
	var x0 := int(floor(px))
	var y0 := int(floor(py))
	var x1 := mini(x0 + 1, width - 1)
	var y1 := mini(y0 + 1, height - 1)
	var fx := px - x0
	var fy := py - y0
	var h00 := delta_texture.get_pixel(x0, y0).r
	var h10 := delta_texture.get_pixel(x1, y0).r
	var h01 := delta_texture.get_pixel(x0, y1).r
	var h11 := delta_texture.get_pixel(x1, y1).r
	var h0 := lerpf(h00, h10, fx)
	var h1 := lerpf(h01, h11, fx)
	return lerpf(h0, h1, fy)

## Calculate edge falloff factor for given UV.
func _calculate_edge_falloff(uv: Vector2) -> float:
	if edge_falloff <= 0.0:
		return 1.0
	var dist_x := minf(uv.x, 1.0 - uv.x)
	var dist_y := minf(uv.y, 1.0 - uv.y)
	var dist_edge := minf(dist_x, dist_y)
	var t := clampf(dist_edge / edge_falloff, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


