## @brief Container for a MultiMesh-based prop group.
##
## @details Manages a single MultiMeshInstance3D that batches multiple props
## from the same rule within a chunk. This provides better performance than
## individual node instances.
class_name PropMultiMeshGroup extends RefCounted

## The MultiMeshInstance3D node in the scene
var multimesh_instance: MultiMeshInstance3D = null

## The MultiMesh resource
var multimesh: MultiMesh = null

## The mesh used for all instances
var mesh: Mesh = null

## Array of placements that are part of this group
var placements: Array[PropPlacement] = []

## ID of the rule that generated these props
var rule_id: String = ""

## Whether this group has been spawned in the scene
var is_spawned: bool = false

## Create and spawn a MultiMesh group from placements.
## @param parent Parent node to add MultiMeshInstance3D to
## @param prop_placements Array of PropPlacement instances
## @param prop_scene The prop scene to extract mesh from
## @param p_rule_id ID of the rule
## @return True if successful
func spawn(
	parent: Node3D,
	prop_placements: Array[PropPlacement],
	prop_scene: PackedScene,
	p_rule_id: String
) -> bool:
	if is_spawned:
		push_warning("PropMultiMeshGroup: Already spawned")
		return false
	if prop_placements.is_empty():
		push_warning("PropMultiMeshGroup: No placements provided")
		return false
	rule_id = p_rule_id
	placements = prop_placements
	var extracted := PropMeshExtractor.extract_from_scene(prop_scene)
	if not extracted.success:
		push_error("PropMultiMeshGroup: Failed to extract mesh - %s" % extracted.error_message)
		return false
	mesh = PropMeshExtractor.create_merged_mesh(extracted)
	if not mesh:
		push_error("PropMultiMeshGroup: Failed to create merged mesh")
		return false
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = placements.size()
	multimesh.mesh = mesh
	for i in range(placements.size()):
		var placement := placements[i]
		multimesh.set_instance_transform(i, placement.get_transform())
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "MultiMesh_%s" % rule_id
	multimesh_instance.multimesh = multimesh
#	if not extracted.materials.is_empty() and not extracted.materials[0].is_empty():
#		for surface_idx in range(extracted.materials[0].size()):
#			var material = extracted.materials[0][surface_idx]
#			if material:
#				multimesh_instance.set_surface_override_material(surface_idx, material)
	parent.add_child(multimesh_instance)
	is_spawned = true
	return true

## Despawn the MultiMesh group.
func despawn() -> void:
	if multimesh_instance and is_instance_valid(multimesh_instance):
		multimesh_instance.queue_free()
	multimesh_instance = null
	multimesh = null
	is_spawned = false

## Update a specific instance transform.
## @param instance_idx Index of the instance to update
## @param new_transform New transform for the instance
func update_instance_transform(instance_idx: int, new_transform: Transform3D) -> void:
	if not is_spawned or not multimesh:
		return
	if instance_idx < 0 or instance_idx >= placements.size():
		push_warning("PropMultiMeshGroup: Invalid instance index %d" % instance_idx)
		return
	multimesh.set_instance_transform(instance_idx, new_transform)
	placements[instance_idx].position = new_transform.origin
	placements[instance_idx].rotation = new_transform.basis.get_euler()
	placements[instance_idx].scale = new_transform.basis.get_scale()

## Get the number of instances in this group.
func get_instance_count() -> int:
	return placements.size()

## Get the AABB of this MultiMesh group.
func get_aabb() -> AABB:
	if multimesh_instance:
		return multimesh_instance.get_aabb()
	return AABB()

## Check if this group contains any placements.
func is_empty() -> bool:
	return placements.is_empty()

