## @brief Generates collision shapes for tunnel interiors.
##
## @details Creates physics collision geometry for tunnel interiors:
## - Generates ConcavePolygonShape3D from tunnel interior mesh
## - Creates StaticBody3D nodes with collision shapes
## - Configurable collision layers and masks
## - Supports multiple collision shapes per terrain
##
## Design Pattern: Builder Pattern - Constructs complex collision node hierarchies.
## SOLID: Single Responsibility - Only concerned with collision shape generation and scene integration.
@tool
class_name TunnelCollisionGenerator extends RefCounted

## Default collision layer for tunnel interiors (bit 3)
const DEFAULT_TUNNEL_LAYER: int = 1 << 2

## Default collision mask for tunnel interiors (interact with player on layer 1)
const DEFAULT_TUNNEL_MASK: int = 1 << 0

## Minimum number of vertices required to create a valid collision shape (9 = 3 triangles)
const MINIMUM_COLLISION_VERTICES: int = 9

## Number of vertices in a triangle
const VERTICES_PER_TRIANGLE: int = 3

## Index offset for second vertex in triangle
const SECOND_VERTEX_OFFSET: int = 1

## Index offset for third vertex in triangle
const THIRD_VERTEX_OFFSET: int = 2

## Multiplier to convert radius to diameter
const RADIUS_TO_DIAMETER_MULTIPLIER: float = 2.0

## Divisor to get center position from total length
const CENTER_POSITION_DIVISOR: float = 0.5

## Threshold for considering direction vectors parallel
const PARALLEL_DIRECTION_THRESHOLD: float = 0.99

## Minimum valid bit index for collision layers
const MIN_BIT_INDEX: int = 0

## Maximum valid bit index for collision layers (32 bits total)
const MAX_BIT_INDEX: int = 31

## Configuration
var collision_layer: int = DEFAULT_TUNNEL_LAYER
var collision_mask: int = DEFAULT_TUNNEL_MASK
var create_static_body: bool = true
var collision_shape_name_prefix: String = "TunnelCollision"

## Statistics
var _collision_shapes_created: int = 0

## Generate and add collision shape for tunnel interior.
##
## @param tunnel_mesh MeshData containing tunnel interior geometry
## @param collision_root Node3D to add collision nodes to
## @param tunnel_id Unique identifier for this tunnel (used in node naming)
## @return bool true if collision was successfully created and added
func add_tunnel_collision(tunnel_mesh: MeshData, collision_root: Node3D, tunnel_id: int = -1) -> bool:
	if tunnel_mesh == null or tunnel_mesh.get_triangle_count() == 0:
		push_error("TunnelCollisionGenerator: Cannot create collision for empty mesh")
		return false
	if collision_root == null:
		push_error("TunnelCollisionGenerator: collision_root is null")
		return false
	var collision_shape := _create_collision_shape_from_mesh(tunnel_mesh)
	if collision_shape == null:
		push_error("TunnelCollisionGenerator: Failed to create collision shape")
		return false
	var collision_node := _build_collision_node(collision_shape, tunnel_id)
	if collision_node == null:
		push_error("TunnelCollisionGenerator: Failed to build collision node")
		return false
	collision_root.add_child(collision_node)
	collision_node.owner = collision_root.owner if collision_root.owner != null else collision_root
	_collision_shapes_created += 1
	return true

## Generate collision for multiple tunnels in batch.
##
## @param tunnel_meshes Array[MeshData] containing tunnel interior geometry
## @param collision_root Node3D to add collision nodes to
## @return int number of successful collision creations
func add_batch_collision(tunnel_meshes: Array[MeshData], collision_root: Node3D) -> int:
	var success_count := 0
	
	for i in range(tunnel_meshes.size()):
		if add_tunnel_collision(tunnel_meshes[i], collision_root, i):
			success_count += 1
	
	return success_count

## Create ConcavePolygonShape3D from mesh data.
##
## @param mesh_data MeshData containing geometry
## @return ConcavePolygonShape3D or null on failure
func _create_collision_shape_from_mesh(mesh_data: MeshData) -> ConcavePolygonShape3D:
	if mesh_data.vertices.size() == 0 or mesh_data.indices.size() == 0:
		push_error("TunnelCollisionGenerator: Empty mesh data")
		return null
	var faces := PackedVector3Array()
	for tri_idx in range(0, mesh_data.indices.size(), VERTICES_PER_TRIANGLE):
		var i0 := mesh_data.indices[tri_idx]
		var i1 := mesh_data.indices[tri_idx + SECOND_VERTEX_OFFSET]
		var i2 := mesh_data.indices[tri_idx + THIRD_VERTEX_OFFSET]
		if i0 >= mesh_data.vertices.size() or i1 >= mesh_data.vertices.size() or i2 >= mesh_data.vertices.size():
			push_warning("TunnelCollisionGenerator: Invalid index in triangle %d" % (tri_idx / VERTICES_PER_TRIANGLE))
			continue
		faces.append(mesh_data.vertices[i0])
		faces.append(mesh_data.vertices[i1])
		faces.append(mesh_data.vertices[i2])
	if faces.size() < MINIMUM_COLLISION_VERTICES:
		push_error("TunnelCollisionGenerator: Insufficient faces for collision shape (minimum %d vertices required), got %d" % [MINIMUM_COLLISION_VERTICES, faces.size()])
		return null
	var collision_shape := ConcavePolygonShape3D.new()
	collision_shape.set_faces(faces)
	
	return collision_shape

## Build collision node hierarchy (StaticBody3D + CollisionShape3D).
##
## @param collision_shape Shape3D to use
## @param tunnel_id Unique identifier for naming
## @return Node3D root of collision hierarchy (StaticBody3D or CollisionShape3D)
func _build_collision_node(collision_shape: Shape3D, tunnel_id: int) -> Node3D:
	if create_static_body:
		# Create StaticBody3D with CollisionShape3D child
		var static_body := StaticBody3D.new()
		static_body.name = _get_collision_node_name("Body", tunnel_id)
		static_body.collision_layer = collision_layer
		static_body.collision_mask = collision_mask
		
		var collision_shape_node := CollisionShape3D.new()
		collision_shape_node.name = _get_collision_node_name("Shape", tunnel_id)
		collision_shape_node.shape = collision_shape
		
		static_body.add_child(collision_shape_node)
		collision_shape_node.owner = static_body
		
		return static_body
	else:
		# Create standalone CollisionShape3D (must be added to existing body)
		var collision_shape_node := CollisionShape3D.new()
		collision_shape_node.name = _get_collision_node_name("Shape", tunnel_id)
		collision_shape_node.shape = collision_shape
		
		return collision_shape_node

## Generate unique collision node name.
##
## @param suffix Name suffix (e.g., "Body", "Shape")
## @param tunnel_id Tunnel identifier
## @return String node name
func _get_collision_node_name(suffix: String, tunnel_id: int) -> String:
	if tunnel_id >= 0:
		return "%s_%s_%d" % [collision_shape_name_prefix, suffix, tunnel_id]
	else:
		return "%s_%s" % [collision_shape_name_prefix, suffix]

## Configure collision layer and mask.
##
## @param layer Collision layer bits
## @param mask Collision mask bits
func configure_collision_layers(layer: int, mask: int) -> void:
	collision_layer = layer
	collision_mask = mask

## Set collision layer bit.
##
## @param bit_index Bit position (0-31)
## @param enabled Whether bit should be set
func set_collision_layer_bit(bit_index: int, enabled: bool) -> void:
	if bit_index < MIN_BIT_INDEX or bit_index > MAX_BIT_INDEX:
		push_error("TunnelCollisionGenerator: Invalid bit index %d (must be %d-%d)" % [bit_index, MIN_BIT_INDEX, MAX_BIT_INDEX])
		return
	if enabled:
		collision_layer |= (1 << bit_index)
	else:
		collision_layer &= ~(1 << bit_index)

## Set collision mask bit.
##
## @param bit_index Bit position (0-31)
## @param enabled Whether bit should be set
func set_collision_mask_bit(bit_index: int, enabled: bool) -> void:
	if bit_index < MIN_BIT_INDEX or bit_index > MAX_BIT_INDEX:
		push_error("TunnelCollisionGenerator: Invalid bit index %d (must be %d-%d)" % [bit_index, MIN_BIT_INDEX, MAX_BIT_INDEX])
		return
	
	if enabled:
		collision_mask |= (1 << bit_index)
	else:
		collision_mask &= ~(1 << bit_index)

## Get number of collision shapes created by this generator.
##
## @return int count of collision shapes
func get_collision_shapes_created() -> int:
	return _collision_shapes_created

## Reset collision shape counter.
func reset_statistics() -> void:
	_collision_shapes_created = 0

## Get configuration as dictionary.
##
## @return Dictionary with current configuration
func get_configuration() -> Dictionary:
	return {
		"collision_layer": collision_layer,
		"collision_mask": collision_mask,
		"create_static_body": create_static_body,
		"name_prefix": collision_shape_name_prefix,
		"shapes_created": _collision_shapes_created
	}

## Create a simplified box collision shape for performance.
##
## @param shape TunnelShape to approximate
## @return BoxShape3D or null on failure
func create_simplified_box_collision(shape: TunnelShape) -> BoxShape3D:
	if shape == null:
		return null
	if shape is CylindricalTunnelShape:
		var cyl := shape as CylindricalTunnelShape
		var box := BoxShape3D.new()
		box.size = Vector3(cyl.radius * RADIUS_TO_DIAMETER_MULTIPLIER, cyl.radius * RADIUS_TO_DIAMETER_MULTIPLIER, cyl.length)
		return box
	push_warning("TunnelCollisionGenerator: Simplified collision not implemented for shape type: %s" % shape.get_class())
	return null

## Add simplified collision using box approximation.
##
## @param shape TunnelShape to create collision for
## @param collision_root Node3D to add collision nodes to
## @param tunnel_id Unique identifier for this tunnel
## @return bool true if collision was successfully created and added
func add_simplified_collision(shape: TunnelShape, collision_root: Node3D, tunnel_id: int = -1) -> bool:
	var box_shape := create_simplified_box_collision(shape)
	if box_shape == null:
		return false
	var collision_node := _build_collision_node(box_shape, tunnel_id)
	if collision_node == null:
		return false
	if collision_node is StaticBody3D:
		collision_node.global_transform = _compute_tunnel_transform(shape)
	collision_root.add_child(collision_node)
	collision_node.owner = collision_root.owner if collision_root.owner != null else collision_root
	_collision_shapes_created += 1
	return true

## Compute transform for positioning collision node at tunnel location.
##
## @param shape TunnelShape to get transform from
## @return Transform3D for collision node positioning
func _compute_tunnel_transform(shape: TunnelShape) -> Transform3D:
	var origin := shape.get_origin()
	var direction := shape.get_direction()
	var length := shape.get_length()
	
	# Compute basis (align +Z with tunnel direction)
	var forward := direction.normalized()
	var up := Vector3.UP
	if abs(forward.dot(up)) > PARALLEL_DIRECTION_THRESHOLD:
		up = Vector3.RIGHT
	var right := forward.cross(up).normalized()
	up = right.cross(forward).normalized()
	
	var basis := Basis(right, up, forward)
	
	# Position at tunnel center (offset by half length)
	var center := origin + direction * (length * CENTER_POSITION_DIVISOR)
	
	return Transform3D(basis, center)

