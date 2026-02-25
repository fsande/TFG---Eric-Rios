## @brief Presents river water surfaces in the scene tree.
##
## MeshInstance3D nodes that visualise rivers. Analogous to SeaPresenter.
@tool
class_name RiverPresenter extends RefCounted

var _river_instances: Array[MeshInstance3D] = []
var _container: Node3D = null

## Create MeshInstance3D nodes for all river visuals.
##
## @param parent            Parent Node3D (typically TerrainPresenterV2).
## @param river_visuals     Array of RiverVisualData produced by river agents.
## @param default_material  Fallback material when a RiverVisualData has no override.
func create_river_meshes(
	parent: Node3D,
	river_visuals: Array[RiverVisualData],
	default_material: Material
) -> void:
	clear()
	if river_visuals.is_empty():
		return
	_container = NodeCreationHelper.get_or_create_node(parent, "RiversContainer", Node3D)
	for i in range(river_visuals.size()):
		var visual := river_visuals[i]
		if not visual or not visual.is_valid():
			push_warning("RiverPresenter: Skipping invalid RiverVisualData at index %d" % i)
			continue
		var mesh := _build_array_mesh(visual)
		if not mesh:
			continue
		var instance := MeshInstance3D.new()
		instance.name = "River_%d" % i
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material: Material = visual.material_override if visual.material_override else default_material
		if material:
			instance.material_override = material
		_container.add_child(instance)
		if Engine.is_editor_hint() and parent.is_inside_tree():
			instance.owner = parent.get_tree().edited_scene_root
		_river_instances.append(instance)

## Remove all previously created river nodes.
func clear() -> void:
	for instance in _river_instances:
		if is_instance_valid(instance):
			instance.queue_free()
	_river_instances.clear()
	if _container and is_instance_valid(_container):
		NodeCreationHelper.remove_all_children(_container)

## Build an ArrayMesh from a RiverVisualData's surface arrays.
func _build_array_mesh(visual: RiverVisualData) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, visual.surface_arrays)
	return mesh

