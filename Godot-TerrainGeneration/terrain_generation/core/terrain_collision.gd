@tool 
class_name TerrainCollision extends RefCounted

var _collision_body: StaticBody3D
var _collision_shape: CollisionShape3D

var collision_body_name: String = "TerrainCollision"
		
var collision_shape_name: String = "CollisionShape"

var _terrain_node: Node3D

func _init(parent_node: Node3D):
	_terrain_node = parent_node
	_initialize_body(_terrain_node)
	_initialize_shape(_collision_body)

func update_collision(terrain_data: TerrainData, collision_layers: int) -> void:
	if _collision_shape and terrain_data:
		_collision_shape.shape = terrain_data.collision_shape
		_collision_body.collision_layer = collision_layers
				
func _initialize_body(parent_node: Node3D) -> void:
	_collision_body = NodeCreationHelper.get_or_create_node(parent_node, collision_body_name, StaticBody3D) as StaticBody3D
	
func _initialize_shape(body_node: StaticBody3D) -> void:
	_collision_shape = NodeCreationHelper.get_or_create_node(body_node, collision_shape_name, CollisionShape3D) as CollisionShape3D