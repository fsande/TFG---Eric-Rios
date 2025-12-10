## @brief Spatial index for grid-based vertex lookup.
##
## @details Provides O(1) neighbour queries for regular grid meshes.
## Does NOT store vertex data - only indices into MeshGenerationResult.
##
## Supports two-tier vertex system: grid vertices (surface) and non-grid vertices
## (caves, overhangs). Only grid vertices are indexed for spatial queries.
class_name VertexGrid extends RefCounted

## Grid dimensions
var width: int
var height: int

## SPATIAL INDEX - Maps (col, row) -> vertex_index
var _grid_to_index: Dictionary  # String key: "col,row" -> int vertex_index

## REVERSE INDEX - Maps vertex_index -> (col, row)
var _index_to_grid: Dictionary  # int vertex_index -> Vector2i(col, row)

## Total grid vertices (excludes non-grid vertices like caves)
var grid_vertex_count: int

## Construct grid for given dimensions.
func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height
	grid_vertex_count = 0

## Build grid index from mesh data.
## O(width * height) to create grid mapping.
func build_from_mesh(mesh: MeshGenerationResult) -> void:
	if mesh.width != width or mesh.height != height:
		push_warning("VertexGrid: Dimension mismatch (expected %dx%d, got %dx%d)" % [width, height, mesh.width, mesh.height])
	
	_grid_to_index.clear()
	_index_to_grid.clear()
	grid_vertex_count = 0
	
	for row in range(height):
		for col in range(width):
			var vertex_index := row * width + col
			if vertex_index < mesh.get_vertex_count():
				_set_grid_mapping(col, row, vertex_index)
				grid_vertex_count += 1

## Check if vertex is part of the regular grid (vs cave/overhang geometry).
func is_grid_vertex(vertex_index: int) -> bool:
	return _index_to_grid.has(vertex_index)

## Get grid dimensions.
func get_dimensions() -> Vector2i:
	return Vector2i(width, height)


## ===========================
## NEIGHBOR QUERIES
## ===========================

## Get Moore neighbours (8-connected: all immediate surrounding vertices).
func get_moore_neighbours(vertex_index: int) -> PackedInt32Array:
	var grid_pos := _get_grid_position(vertex_index)
	if grid_pos.x < 0:
		return PackedInt32Array()
	
	var neighbours := PackedInt32Array()
	
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			
			var neighbour_col := grid_pos.x + dx
			var neighbour_row := grid_pos.y + dy
			var neighbour_index := _get_vertex_at(neighbour_col, neighbour_row)
			
			if neighbour_index >= 0:
				neighbours.append(neighbour_index)
	
	return neighbours

## Get neighbours within Chebyshev distance (square region around vertex).
## distance=1 is equivalent to Moore neighbours, distance=2 is 5x5 square, etc.
func get_neighbours_chebyshev(vertex_index: int, distance: int) -> PackedInt32Array:
	var grid_pos := _get_grid_position(vertex_index)
	if grid_pos.x < 0:
		return PackedInt32Array()
	
	var neighbours := PackedInt32Array()
	
	for dy in range(-distance, distance + 1):
		for dx in range(-distance, distance + 1):
			if dx == 0 and dy == 0:
				continue
			
			var neighbour_col := grid_pos.x + dx
			var neighbour_row := grid_pos.y + dy
			var neighbour_index := _get_vertex_at(neighbour_col, neighbour_row)
			
			if neighbour_index >= 0:
				neighbours.append(neighbour_index)
	
	return neighbours



## ===========================
## SPATIAL LOOKUP
## ===========================

## Get nearest grid vertex to UV coordinates (0-1 range).
func get_nearest_grid_vertex_uv(uv: Vector2) -> int:
	var clamped_u: float = clamp(uv.x, 0.0, 1.0)
	var clamped_v: float = clamp(uv.y, 0.0, 1.0)
	var col := int(clamp(clamped_u * width, 0.0, float(max(0, width - 1))))
	var row := int(clamp(clamped_v * height, 0.0, float(max(0, height - 1))))
	return _get_vertex_at(col, row)

## Get nearest grid vertex to world position (XZ plane).
## Assumes (0, 0) is center of mesh, mesh_size is total world dimensions.
## Returns vertex index or -1 if grid is empty.
func get_nearest_grid_vertex(world_pos: Vector2, mesh_size: Vector2) -> int:
	var half_w := mesh_size.x * 0.5
	var half_h := mesh_size.y * 0.5
	var clamped_x: float = clamp(world_pos.x, -half_w, half_w)
	var clamped_y: float = clamp(world_pos.y, -half_h, half_h)
	var normalized_x := (clamped_x / mesh_size.x) + 0.5
	var normalized_y := (clamped_y / mesh_size.y) + 0.5
	var col := int(clamp(normalized_x * width, 0.0, float(max(0, width - 1))))
	var row := int(clamp(normalized_y * height, 0.0, float(max(0, height - 1))))
	return _get_vertex_at(col, row)


## ===========================
## INTERNAL HELPERS
## ===========================

## Get vertex index at grid position (internal - uses string key for Dictionary).
func _get_vertex_at(col: int, row: int) -> int:
	var key := "%d,%d" % [col, row]
	return _grid_to_index.get(key, -1)

## Get grid position of vertex (internal).
func _get_grid_position(vertex_index: int) -> Vector2i:
	return _index_to_grid.get(vertex_index, Vector2i(-1, -1))

## Set bidirectional grid mapping (internal).
func _set_grid_mapping(col: int, row: int, vertex_index: int) -> void:
	var key := "%d,%d" % [col, row]
	_grid_to_index[key] = vertex_index
	_index_to_grid[vertex_index] = Vector2i(col, row)
