@tool 
class_name SeaPresenter extends RefCounted

## @brief Creates and manages a subdivided water plane for the sea/ocean
##
## @details Generates a plane mesh with customizable subdivisions and applies a water material

var _mesh_instance: MeshInstance3D
var _parent_node: Node3D

## Creates a new sea plane mesh
## @param parent The parent Node3D to attach the sea plane to
## @param size The size of the sea plane (Vector2)
## @param sea_level The Y position of the sea plane
## @param subdivisions Number of subdivisions for the plane (for wave vertex displacement)
## @param material The water material to apply
func create_sea_plane(
	parent: Node3D,
	size: Vector2,
	sea_level: float,
	subdivisions: int,
	material: Material
) -> MeshInstance3D:
	_parent_node = parent
	_mesh_instance = NodeCreationHelper.get_or_create_node(_parent_node, "SeaPlane", MeshInstance3D)
	var plane_mesh := _generate_subdivided_plane(size, subdivisions)
	_mesh_instance.mesh = plane_mesh
	if material:
		_mesh_instance.material_override = material
	_mesh_instance.position = Vector3(0, sea_level, 0)
	if Engine.is_editor_hint():
		_mesh_instance.owner = parent.get_tree().edited_scene_root
	return _mesh_instance

## Generates a subdivided plane mesh
func _generate_subdivided_plane(size: Vector2, subdivisions: int) -> ArrayMesh:
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = size
	plane_mesh.subdivide_width = subdivisions
	plane_mesh.subdivide_depth = subdivisions
	var arrays := plane_mesh.get_mesh_arrays()
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh

## Removes the sea plane
func remove_sea_plane() -> void:
	if _mesh_instance and _mesh_instance.is_inside_tree():
		_mesh_instance.queue_free()
		_mesh_instance = null

