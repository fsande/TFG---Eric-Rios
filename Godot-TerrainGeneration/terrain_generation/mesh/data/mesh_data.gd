## @brief Pure data container for mesh geometry.
##
## @details Stores only essential mesh data (vertices, indices, UVs).
@tool
class_name MeshData extends RefCounted

## Vertex positions in 3D space
var vertices: PackedVector3Array

## Triangle indices (every 3 indices form a triangle)
var indices: PackedInt32Array

## UV texture coordinates
var uvs: PackedVector2Array

## Cached normals (calculated externally)
var cached_normals: PackedVector3Array = PackedVector3Array()

## Cached tangents (calculated externally)
var cached_tangents: PackedVector4Array = PackedVector4Array()

## Grid metadata (for regular grids)
var width: int = 0
var height: int = 0

## World-space dimensions
var mesh_size: Vector2 = Vector2.ZERO

## Generation metadata
var elapsed_time_ms: float = 0.0
var processor_type: String = ""

## Construct mesh data with essential geometry.
func _init(p_vertices: PackedVector3Array = PackedVector3Array(), 
           p_indices: PackedInt32Array = PackedInt32Array(), 
           p_uvs: PackedVector2Array = PackedVector2Array()) -> void:
	vertices = p_vertices
	indices = p_indices
	uvs = p_uvs

## Get total vertex count.
func get_vertex_count() -> int:
	return vertices.size()

## Get total triangle count.
func get_triangle_count() -> int:
	return indices.size() / 3

## Check if vertex index is valid.
func is_valid_index(index: int) -> bool:
	return index >= 0 and index < vertices.size()

## Get vertex position by index.
func get_vertex(index: int) -> Vector3:
	if not is_valid_index(index):
		push_warning("MeshData: Invalid vertex index %d" % index)
		return Vector3.ZERO
	return vertices[index]

## Get vertex height (Y component).
func get_height(index: int) -> float:
	if not is_valid_index(index):
		return 0.0
	return vertices[index].y
