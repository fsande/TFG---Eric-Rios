## @brief Data container for a single prop placement.
##
## @details Holds all information needed to instantiate a prop
## at a specific location on the terrain.
class_name PropPlacement extends RefCounted

## World position where prop should be placed
var position: Vector3 = Vector3.ZERO

## Rotation in radians (Euler angles)
var rotation: Vector3 = Vector3.ZERO

## Scale multiplier
var scale: Vector3 = Vector3.ONE

## Reference to the scene to instantiate
var prop_scene: PackedScene = null

## ID of the rule that generated this placement
var rule_id: String = ""

## Whether this placement has been spawned
var is_spawned: bool = false

## Reference to spawned node (if spawned)
var spawned_node: Node3D = null


## Spawn the prop in the scene.
## @param parent Parent node to add prop to
## @return The spawned Node3D, or null on failure
func spawn(parent: Node3D) -> Node3D:
	if not prop_scene:
		push_error("PropPlacement: No prop_scene set")
		return null
	if is_spawned and spawned_node and is_instance_valid(spawned_node):
		return spawned_node
	var instance := prop_scene.instantiate() as Node3D
	if not instance:
		push_error("PropPlacement: Failed to instantiate prop_scene")
		return null
	instance.position = position
	instance.rotation = rotation
	instance.scale = scale
	parent.add_child(instance)
	is_spawned = true
	spawned_node = instance
	return instance

## Despawn the prop if spawned.
func despawn() -> void:
	if spawned_node and is_instance_valid(spawned_node):
		spawned_node.queue_free()
	spawned_node = null
	is_spawned = false

## Get transform for this placement.
func get_transform() -> Transform3D:
	var basis := Basis.from_euler(rotation)
	basis = basis.scaled(scale)
	return Transform3D(basis, position)

## Get distance from this placement to a point.
func distance_to(point: Vector3) -> float:
	return position.distance_to(point)
