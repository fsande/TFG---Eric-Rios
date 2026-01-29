## @brief Type-safe container for vertex extraction results.
##
## @details Holds the results of vertex extraction during grid decimation,
## including new vertices, UVs, vertex mapping, and grid dimensions.
@tool
class_name VertexExtractionResult extends RefCounted

var vertices: PackedVector3Array
var uvs: PackedVector2Array
var vertex_map: Dictionary
var new_width: int
var new_height: int

func _init(
	p_vertices: PackedVector3Array,
	p_uvs: PackedVector2Array,
	p_vertex_map: Dictionary,
	p_new_width: int,
	p_new_height: int
) -> void:
	vertices = p_vertices
	uvs = p_uvs
	vertex_map = p_vertex_map
	new_width = p_new_width
	new_height = p_new_height

