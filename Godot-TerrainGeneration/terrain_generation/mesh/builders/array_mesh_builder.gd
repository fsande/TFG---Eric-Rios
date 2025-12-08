## @brief Builds Godot ArrayMesh from mesh data.
##
## @details Handles conversion from internal format to Godot's mesh format.
@tool
class_name ArrayMeshBuilder extends RefCounted

## Build an ArrayMesh from mesh data.
## Calculates normals and tangents if not already cached.
static func build_mesh(mesh_data: MeshData) -> ArrayMesh:
	# Ensure normals are calculated
	if mesh_data.cached_normals.is_empty():
		MeshNormalCalculator.calculate_and_cache(mesh_data)
	
	# Ensure tangents are calculated
	if mesh_data.cached_tangents.is_empty():
		MeshTangentCalculator.calculate_and_cache(mesh_data)
	
	# Build arrays for Godot mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mesh_data.vertices
	arrays[Mesh.ARRAY_NORMAL] = mesh_data.cached_normals
	arrays[Mesh.ARRAY_TANGENT] = _tangents_to_packed_float32(mesh_data.cached_tangents)
	arrays[Mesh.ARRAY_TEX_UV] = mesh_data.uvs
	arrays[Mesh.ARRAY_INDEX] = mesh_data.indices
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Convert PackedVector4Array tangents to PackedFloat32Array format expected by Godot.
static func _tangents_to_packed_float32(tangent_vec4: PackedVector4Array) -> PackedFloat32Array:
	var tangent_array := PackedFloat32Array()
	tangent_array.resize(tangent_vec4.size() * 4)
	for i in range(tangent_vec4.size()):
		var t := tangent_vec4[i]
		var base := i * 4
		tangent_array[base] = t.x
		tangent_array[base + 1] = t.y
		tangent_array[base + 2] = t.z
		tangent_array[base + 3] = t.w
	return tangent_array

