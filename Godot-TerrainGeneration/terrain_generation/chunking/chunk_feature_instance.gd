@abstract
class_name ChunkFeatureInstance extends RefCounted

## World position where prop should be placed
var position: Vector3 = Vector3.ZERO
## Rotation in radians (Euler angles)
var rotation: Vector3 = Vector3.ZERO
## Scale multiplier
var scale: Vector3 = Vector3.ONE

## Whether this placement has been spawned
var is_spawned: bool = false
## Reference to spawned node (if spawned)
var spawned_node: Node3D = null

## Spawn the feature in the scene. 
@abstract
func spawn(parent: Node3D) -> Node3D

## Despawn the feature if spawned.
func despawn() -> void:
	if spawned_node and is_instance_valid(spawned_node):
		spawned_node.queue_free()
	spawned_node = null
	is_spawned = false