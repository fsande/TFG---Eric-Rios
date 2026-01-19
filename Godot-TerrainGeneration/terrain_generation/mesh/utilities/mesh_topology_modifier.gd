## @brief Handles mesh topology modifications.
##
## @details Provides operations for adding/removing vertices and triangles.
@tool
class_name MeshTopologyModifier extends RefCounted

var _mesh_data: MeshData

## Construct with reference to mesh data.
func _init(mesh_data: MeshData) -> void:
	_mesh_data = mesh_data

## Add a single vertex to the mesh. Returns the new vertex index.
## These vertices are NOT part of the grid (non-grid vertices).
func add_vertex(position: Vector3, uv: Vector2 = Vector2.ZERO) -> int:
	var index := _mesh_data.vertices.size()
	_mesh_data.vertices.append(position)
	_mesh_data.uvs.append(uv)
	return index

## Add multiple vertices in batch. Returns the index of the first new vertex.
func add_vertices(positions: PackedVector3Array, vertex_uvs: PackedVector2Array) -> int:
	if positions.size() != vertex_uvs.size():
		push_error("MeshTopologyModifier: Position and UV array size mismatch")
		return -1
	var base_index := _mesh_data.vertices.size()
	_mesh_data.vertices.append_array(positions)
	_mesh_data.uvs.append_array(vertex_uvs)
	return base_index

## Add a triangle using vertex indices.
func add_triangle(v0: int, v1: int, v2: int) -> void:
	_mesh_data.indices.append(v0)
	_mesh_data.indices.append(v1)
	_mesh_data.indices.append(v2)

## Add multiple triangles in batch.
func add_triangles(triangle_indices: PackedInt32Array) -> void:
	if triangle_indices.size() % 3 != 0:
		push_error("MeshTopologyModifier: Triangle indices must be multiple of 3")
		return
	_mesh_data.indices.append_array(triangle_indices)

## Remove triangles that pass the filter function.
## filter_func: Callable that takes (v0: Vector3, v1: Vector3, v2: Vector3) -> bool
## Returns the number of triangles removed.
func remove_triangles_if(filter_func: Callable) -> int:
	var new_indices := PackedInt32Array()
	var removed_count := 0
	for i in range(0, _mesh_data.indices.size(), 3):
		var i0 := _mesh_data.indices[i]
		var i1 := _mesh_data.indices[i + 1]
		var i2 := _mesh_data.indices[i + 2]
		var v0 := _mesh_data.vertices[i0]
		var v1 := _mesh_data.vertices[i1]
		var v2 := _mesh_data.vertices[i2]
		if filter_func.call(v0, v1, v2):
			removed_count += 1
			continue
		new_indices.append(i0)
		new_indices.append(i1)
		new_indices.append(i2)
	_mesh_data.indices = new_indices
	return removed_count


