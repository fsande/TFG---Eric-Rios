## @brief Utility for extracting mesh data from prop scenes for MultiMesh usage.
##
## @details Scans a prop scene for all MeshInstance3D nodes and extracts
## their meshes and materials for use in MultiMeshInstance3D.
class_name PropMeshExtractor extends RefCounted

## Result of mesh extraction from a prop scene
class ExtractedMeshData:
	var meshes: Array[Mesh] = []
	var materials: Array[Array] = []
	var transforms: Array[Transform3D] = []
	var success: bool = false
	var error_message: String = ""

## Extract all meshes and materials from a prop scene.
## @param prop_scene The PackedScene to extract from
## @return ExtractedMeshData containing meshes, materials, and transforms
static func extract_from_scene(prop_scene: PackedScene) -> ExtractedMeshData:
	var result := ExtractedMeshData.new()
	if not prop_scene:
		result.error_message = "Prop scene is null"
		return result
	var temp_instance := prop_scene.instantiate()
	if not temp_instance:
		result.error_message = "Failed to instantiate prop scene"
		return result
	_extract_meshes_recursive(temp_instance, Transform3D.IDENTITY, result)
	temp_instance.queue_free()
	if result.meshes.is_empty():
		result.error_message = "No MeshInstance3D nodes found in prop scene"
		return result
	result.success = true
	return result

## Recursively search for MeshInstance3D nodes and extract their data.
## @param node Current node being inspected
## @param parent_transform Accumulated transform from root
## @param result ExtractedMeshData to populate
static func _extract_meshes_recursive(
	node: Node,
	parent_transform: Transform3D,
	result: ExtractedMeshData
) -> void:
	var current_transform := parent_transform
	if node is Node3D:
		current_transform = parent_transform * node.transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			result.meshes.append(mesh_instance.mesh)
			result.transforms.append(current_transform)
			var mesh_materials: Array = []
			var surface_count := mesh_instance.mesh.get_surface_count()
			for i in range(surface_count):
				var material: Material = null
				if mesh_instance.get_surface_override_material(i):
					material = mesh_instance.get_surface_override_material(i)
				elif mesh_instance.mesh.surface_get_material(i):
					material = mesh_instance.mesh.surface_get_material(i)
				mesh_materials.append(material)
			result.materials.append(mesh_materials)
	for child in node.get_children():
		_extract_meshes_recursive(child, current_transform, result)

## Create a merged mesh from multiple extracted meshes.
## Useful for creating a single MultiMesh from a prop with multiple mesh parts.
## @param extracted_data The extracted mesh data
## @return A single merged ArrayMesh, or null if merge fails
static func create_merged_mesh(extracted_data: ExtractedMeshData) -> ArrayMesh:
	if not extracted_data.success or extracted_data.meshes.is_empty():
		return null
	if extracted_data.meshes.size() == 1:
		if extracted_data.transforms[0] != Transform3D.IDENTITY:
			return _transform_mesh(extracted_data.meshes[0], extracted_data.transforms[0])
		return extracted_data.meshes[0]
	var merged := ArrayMesh.new()
	for i in range(extracted_data.meshes.size()):
		var mesh := extracted_data.meshes[i]
		var transform := extracted_data.transforms[i]
		var mesh_materials := extracted_data.materials[i]
		for surface_idx in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface_idx)
			if transform != Transform3D.IDENTITY:
				arrays = _transform_mesh_arrays(arrays, transform)
			var material: Material = null
			if surface_idx < mesh_materials.size():
				material = mesh_materials[surface_idx]
			merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if material:
				merged.surface_set_material(merged.get_surface_count() - 1, material)
	return merged

## Transform a mesh by a given transform.
## @param mesh The mesh to transform
## @param xform The transform to apply
## @return Transformed ArrayMesh
static func _transform_mesh(mesh: Mesh, xform: Transform3D) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface_idx in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_idx)
		arrays = _transform_mesh_arrays(arrays, xform)
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := mesh.surface_get_material(surface_idx)
		if material:
			result.surface_set_material(surface_idx, material)
	return result


## Transform mesh array data by a transform.
## @param arrays Mesh arrays (vertices, normals, etc.)
## @param xform Transform to apply
## @return Transformed arrays
static func _transform_mesh_arrays(arrays: Array, xform: Transform3D) -> Array:
	if arrays[Mesh.ARRAY_VERTEX]:
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var transformed_verts := PackedVector3Array()
		transformed_verts.resize(vertices.size())
		for i in range(vertices.size()):
			transformed_verts[i] = xform * vertices[i]
		arrays[Mesh.ARRAY_VERTEX] = transformed_verts
	if arrays[Mesh.ARRAY_NORMAL]:
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var transformed_normals := PackedVector3Array()
		transformed_normals.resize(normals.size())
		for i in range(normals.size()):
			transformed_normals[i] = xform.basis * normals[i]
			transformed_normals[i] = transformed_normals[i].normalized()
		arrays[Mesh.ARRAY_NORMAL] = transformed_normals
	if arrays[Mesh.ARRAY_TANGENT]:
		var tangents := arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
		var transformed_tangents := PackedFloat32Array()
		transformed_tangents.resize(tangents.size())
		for i in range(0, tangents.size(), 4):
			var tangent := Vector3(tangents[i], tangents[i+1], tangents[i+2])
			tangent = xform.basis * tangent
			tangent = tangent.normalized()
			transformed_tangents[i] = tangent.x
			transformed_tangents[i+1] = tangent.y
			transformed_tangents[i+2] = tangent.z
			transformed_tangents[i+3] = tangents[i+3]
		arrays[Mesh.ARRAY_TANGENT] = transformed_tangents
	return arrays
