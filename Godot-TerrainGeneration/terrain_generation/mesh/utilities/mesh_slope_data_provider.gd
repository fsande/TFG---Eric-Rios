## @brief Provides slope data queries for terrain mesh.
##
## @details Handles slope-specific queries.
## Requires a precomputed slope normal map (Image with RGBAF format).
@tool
class_name MeshSlopeDataProvider extends RefCounted

var _mesh_data: MeshData
var _slope_normal_map: Image

## Construct with mesh data and optional slope normal map.
func _init(mesh_data: MeshData, slope_normal_map: Image = null) -> void:
	_mesh_data = mesh_data
	_slope_normal_map = slope_normal_map

## Set the slope normal map (Image format: RGBAF - RGB=normal vector, A=slope angle in radians).
func set_slope_normal_map(slope_map: Image) -> void:
	_slope_normal_map = slope_map

## Get the slope normal map.
func get_slope_normal_map() -> Image:
	return _slope_normal_map

## Get slope data at UV coordinate (0-1 range).
## Returns SlopeData with normal vector and slope angle.
func get_slope_at_uv(uv: Vector2) -> SlopeData:
	if not _slope_normal_map:
		return SlopeData.new(Vector3.UP, 0.0)
	
	# Clamp UV to valid range
	var clamped_uv := Vector2(
		clamp(uv.x, 0.0, 1.0),
		clamp(uv.y, 0.0, 1.0)
	)
	
	# Convert UV to pixel coordinates
	var pixel_x := int(clamped_uv.x * (_slope_normal_map.get_width() - 1))
	var pixel_y := int(clamped_uv.y * (_slope_normal_map.get_height() - 1))
	
	# Sample pixel
	var pixel := _slope_normal_map.get_pixel(pixel_x, pixel_y)
	
	return SlopeData.new(Vector3(pixel.r, pixel.g, pixel.b), pixel.a)

## Get slope data for specific vertex index.
## Returns SlopeData with normal vector and slope angle.
func get_slope_at_vertex(vertex_index: int) -> SlopeData:
	if vertex_index < 0 or vertex_index >= _mesh_data.vertices.size() or _mesh_data.width == 0 or _mesh_data.height == 0:
		return SlopeData.new(Vector3.UP, 0.0)
	
	# Convert vertex index to grid coordinates
	var col := vertex_index % _mesh_data.width
	var row := vertex_index / _mesh_data.width
	
	# Convert to UV coordinates
	var uv := Vector2(
		float(col) / float(_mesh_data.width - 1) if _mesh_data.width > 1 else 0.0,
		float(row) / float(_mesh_data.height - 1) if _mesh_data.height > 1 else 0.0
	)
	
	return get_slope_at_uv(uv)

## Get slope data at world position (XZ plane).
## Returns SlopeData with normal vector and slope angle.
func get_slope_at_world_position(world_pos: Vector2) -> SlopeData:
	if _mesh_data.mesh_size.x == 0.0 or _mesh_data.mesh_size.y == 0.0:
		return SlopeData.new(Vector3.UP, 0.0)
	
	# Convert world position to UV (assuming mesh is centered at origin)
	var uv := Vector2(
		(world_pos.x / _mesh_data.mesh_size.x) + 0.5,
		(world_pos.y / _mesh_data.mesh_size.y) + 0.5
	)
	
	return get_slope_at_uv(uv)

