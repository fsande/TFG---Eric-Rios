## @brief Facade for mesh generation results.
##
## @details REFACTORED: Now delegates to focused components following SOLID principles.
## This class maintains backward compatibility while using the new architecture internally.
@tool
class_name MeshGenerationResult extends RefCounted

## CORE DATA - Delegated to MeshData
var mesh_data: MeshData

## SPECIALIZED COMPONENTS
var _topology_modifier: MeshTopologyModifier
var _slope_provider: MeshSlopeDataProvider

## FLAGS for lazy calculation
var _normals_dirty: bool = true
var _tangents_dirty: bool = true

## BACKWARD COMPATIBILITY - Direct property access
## These delegate to mesh_data for compatibility with existing code
var vertices: PackedVector3Array:
	get: return mesh_data.vertices
	set(value): mesh_data.vertices = value

var indices: PackedInt32Array:
	get: return mesh_data.indices
	set(value): mesh_data.indices = value

var uvs: PackedVector2Array:
	get: return mesh_data.uvs
	set(value): mesh_data.uvs = value

var elapsed_time_ms: float:
	get: return mesh_data.elapsed_time_ms
	set(value): mesh_data.elapsed_time_ms = value

var processor_type: String:
	get: return mesh_data.processor_type
	set(value): mesh_data.processor_type = value

var vertex_count: int:
	get: return mesh_data.get_vertex_count()
	set(value): pass

var width: int:
	get: return mesh_data.width
	set(value): mesh_data.width = value

var height: int:
	get: return mesh_data.height
	set(value): mesh_data.height = value

var mesh_size: Vector2:
	get: return mesh_data.mesh_size
	set(value): mesh_data.mesh_size = value

var slope_normal_map: Image:
	get: return _slope_provider.get_slope_normal_map()
	set(value): _slope_provider.set_slope_normal_map(value)

## Construct a result with essential mesh data and metrics.
func _init(p_vertices: PackedVector3Array, p_indices: PackedInt32Array, p_uvs: PackedVector2Array, p_time: float, p_type: String) -> void:
	mesh_data = MeshData.new(p_vertices, p_indices, p_uvs)
	mesh_data.elapsed_time_ms = p_time
	mesh_data.processor_type = p_type
	_topology_modifier = MeshTopologyModifier.new(mesh_data)
	_slope_provider = MeshSlopeDataProvider.new(mesh_data)

## Get normals (calculates on first call, then returns cached).
func get_normals() -> PackedVector3Array:
	if _normals_dirty:
		MeshNormalCalculator.calculate_and_cache(mesh_data)
		_normals_dirty = false
	return mesh_data.cached_normals

func get_normal_at_vertex(vertex_index: int) -> Vector3:
	var normals := get_normals()
	if vertex_index >= 0 and vertex_index < normals.size():
		return normals[vertex_index]
	return Vector3.UP

## Get tangents (calculates on first call, then returns cached).
func get_tangents() -> PackedVector4Array:
	if _tangents_dirty:
		MeshTangentCalculator.calculate_and_cache(mesh_data)
		_tangents_dirty = false
	return mesh_data.cached_tangents

## Mark normals and tangents as dirty (call after modifying vertices).
func mark_dirty() -> void:
	_normals_dirty = true
	_tangents_dirty = true

## Get vertex position by index.
func get_vertex(index: int) -> Vector3:
	return mesh_data.get_vertex(index)

## Set vertex position by index.
func set_vertex(index: int, position: Vector3) -> void:
	if mesh_data.set_vertex(index, position):
		mark_dirty()

## Get vertex height (Y component).
func get_height(index: int) -> float:
	return mesh_data.get_height(index)

## Set vertex height (Y component).
func set_height(index: int, new_height: float) -> void:
	if mesh_data.set_height(index, new_height):
		mark_dirty()

## Check if index is valid.
func is_valid_index(index: int) -> bool:
	return mesh_data.is_valid_index(index)

## Get total vertex count.
func get_vertex_count() -> int:
	return mesh_data.get_vertex_count()

## Get total triangle count.
func get_triangle_count() -> int:
	return mesh_data.get_triangle_count()

## ===========================
## TOPOLOGY MODIFICATION (for caves, overhangs, etc.)
## Delegates to MeshTopologyModifier
## ===========================

## Add a single vertex to the mesh. Returns the new vertex index.
## These vertices are NOT part of the grid (non-grid vertices).
func add_vertex(position: Vector3, uv: Vector2 = Vector2.ZERO) -> int:
	var index := _topology_modifier.add_vertex(position, uv)
	mark_dirty()
	return index

## Add multiple vertices in batch. Returns the index of the first new vertex.
func add_vertices(positions: PackedVector3Array, vertex_uvs: PackedVector2Array) -> int:
	var base_index := _topology_modifier.add_vertices(positions, vertex_uvs)
	if base_index >= 0:
		mark_dirty()
	return base_index

## Add a triangle using vertex indices.
func add_triangle(v0: int, v1: int, v2: int) -> void:
	_topology_modifier.add_triangle(v0, v1, v2)

## Add multiple triangles in batch.
func add_triangles(triangle_indices: PackedInt32Array) -> void:
	_topology_modifier.add_triangles(triangle_indices)

## Remove triangles that pass the filter function.
## filter_func: Callable that takes (v0: Vector3, v1: Vector3, v2: Vector3) -> bool
## Returns the number of triangles removed.
func remove_triangles_if(filter_func: Callable) -> int:
	var removed_count := _topology_modifier.remove_triangles_if(filter_func)
	if removed_count > 0:
		mark_dirty()
	return removed_count

## Build an ArrayMesh from the stored data.
## Delegates to ArrayMeshBuilder following Builder Pattern.
func build_mesh() -> ArrayMesh:
	return ArrayMeshBuilder.build_mesh(mesh_data)


## ===========================
## SLOPE DATA ACCESS
## Delegates to MeshSlopeDataProvider
## ===========================

## Get slope normal map (returns null if not computed).
func get_slope_normal_map() -> Image:
	return _slope_provider.get_slope_normal_map()

## Get slope data at UV coordinate (0-1 range).
## Returns SlopeData with normal vector and slope angle.
func get_slope_at_uv(uv: Vector2) -> SlopeData:
	return _slope_provider.get_slope_at_uv(uv)

## Get slope data for specific vertex index.
## Returns SlopeData with normal vector and slope angle.
func get_slope_at_vertex(vertex_index: int) -> SlopeData:
	return _slope_provider.get_slope_at_vertex(vertex_index)

## Get slope data at world position (XZ plane).
## Returns SlopeData with normal vector and slope angle.
func get_slope_at_world_position(world_pos: Vector2) -> SlopeData:
	return _slope_provider.get_slope_at_world_position(world_pos)
