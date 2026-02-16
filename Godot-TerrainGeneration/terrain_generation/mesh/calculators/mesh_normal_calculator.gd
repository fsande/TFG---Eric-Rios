## @brief Strategy for calculating mesh normals.
##
## @details Implements normal calculation algorithms.
@tool
class_name MeshNormalCalculator extends RefCounted

## Calculate smooth normals from vertex positions and indices.
## Returns a PackedVector3Array with one normal per vertex.
static func calculate_normals(mesh_data: MeshData) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(mesh_data.vertices.size())
	for i in range(mesh_data.vertices.size()):
		normals[i] = Vector3.ZERO
	for i in range(0, mesh_data.indices.size(), 3):
		var i0 := mesh_data.indices[i]
		var i1 := mesh_data.indices[i + 1]
		var i2 := mesh_data.indices[i + 2]
		var v0 := mesh_data.vertices[i0]
		var v1 := mesh_data.vertices[i1]
		var v2 := mesh_data.vertices[i2]
		var face_normal := (v2 - v0).cross(v1 - v0).normalized()
		normals[i0] += face_normal
		normals[i1] += face_normal
		normals[i2] += face_normal
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	return normals

## Calculate normals and cache them in the mesh data.
static func calculate_and_cache(mesh_data: MeshData) -> void:
	mesh_data.cached_normals = calculate_normals(mesh_data)
