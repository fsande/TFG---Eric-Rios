## @brief Builds scene node hierarchies for tunnel visuals and physics.
##
## @details Constructs complete tunnel scene nodes with MeshInstance3D and collision.
## Design Pattern: Builder Pattern - Constructs complex tunnel scene node hierarchies.
@tool
class_name TunnelSceneBuilder extends RefCounted

## Default material color for tunnels (gray stone)
const DEFAULT_TUNNEL_COLOR: Color = Color(0.4, 0.4, 0.45, 1.0)
const DEFAULT_ROUGHNESS: float = 0.9
const DEFAULT_METALLIC: float = 0.1

## Container name for all tunnel nodes
const TUNNEL_CONTAINER_NAME: String = "TunnelInteriors"

## Configuration
var default_material: Material = null
var cast_shadows: bool = true
var collision_generator: TunnelCollisionGenerator = null

## Statistics
var _tunnels_built: int = 0

func _init() -> void:
	collision_generator = TunnelCollisionGenerator.new()
	default_material = _create_default_material()

## Build complete tunnel scene node from mesh data.
func build_tunnel_node(
	tunnel_mesh: MeshData,
	definition: TunnelDefinition,
	tunnel_id: int = -1
) -> Node3D:
	if tunnel_mesh == null or tunnel_mesh.get_triangle_count() == 0:
		push_error("TunnelSceneBuilder: Cannot build node from empty mesh")
		return null
	
	if definition == null:
		push_error("TunnelSceneBuilder: Cannot build node from null definition")
		return null
	
	# Create root container for this tunnel
	var tunnel_root := Node3D.new()
	tunnel_root.name = "Tunnel_%d" % tunnel_id if tunnel_id >= 0 else "Tunnel"
	
	# Create and add visual mesh
	var mesh_instance := _build_mesh_instance(tunnel_mesh, definition, tunnel_id)
	if mesh_instance != null:
		tunnel_root.add_child(mesh_instance)
		mesh_instance.owner = tunnel_root
	
	# Create and add collision (if enabled)
	if definition.generate_collision:
		collision_generator.configure_collision_layers(
			definition.collision_layers,
			definition.collision_mask
		)
		
		if collision_generator.add_tunnel_collision(tunnel_mesh, tunnel_root, tunnel_id):
			pass  # Success logged by generator
	
	_tunnels_built += 1
	return tunnel_root

## Build mesh instance from tunnel mesh data.
func _build_mesh_instance(
	tunnel_mesh: MeshData,
	definition: TunnelDefinition,
	tunnel_id: int
) -> MeshInstance3D:
	# Convert MeshData to ArrayMesh
	var godot_mesh := ArrayMeshBuilder.build_mesh(tunnel_mesh)
	if godot_mesh == null:
		push_error("TunnelSceneBuilder: Failed to build Godot mesh from MeshData")
		return null
	
	# Create mesh instance
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TunnelMesh_%d" % tunnel_id if tunnel_id >= 0 else "TunnelMesh"
	mesh_instance.mesh = godot_mesh
	
	# Apply material
	var material := definition.tunnel_material if definition.tunnel_material != null else default_material
	mesh_instance.material_override = material
	
	# Shadow settings
	if definition.cast_shadows:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	return mesh_instance

## Get or create tunnel container in scene.
func get_or_create_tunnel_container(root: Node3D) -> Node3D:
	if root == null:
		push_error("TunnelSceneBuilder: Cannot create container with null root")
		return null
	
	# Check if container already exists
	var existing := root.get_node_or_null(TUNNEL_CONTAINER_NAME)
	if existing != null and existing is Node3D:
		return existing as Node3D
	
	# Create new container
	var container := Node3D.new()
	container.name = TUNNEL_CONTAINER_NAME
	root.add_child(container)
	container.owner = root.owner if root.owner != null else root
	
	return container

## Build and add tunnel to scene.
func build_and_add_to_scene(
	tunnel_mesh: MeshData,
	definition: TunnelDefinition,
	scene_root: Node3D,
	tunnel_id: int = -1
) -> bool:
	if scene_root == null:
		push_error("TunnelSceneBuilder: Cannot add to null scene root")
		return false
	
	var tunnel_node := build_tunnel_node(tunnel_mesh, definition, tunnel_id)
	if tunnel_node == null:
		return false
	
	var container := get_or_create_tunnel_container(scene_root)
	if container == null:
		tunnel_node.queue_free()
		return false
	
	container.add_child(tunnel_node)
	tunnel_node.owner = container.owner if container.owner != null else container
	
	return true

## Build multiple tunnels in batch.
func build_batch(
	tunnel_meshes: Array[MeshData],
	definitions: Array[TunnelDefinition],
	scene_root: Node3D
) -> int:
	if tunnel_meshes.size() != definitions.size():
		push_error("TunnelSceneBuilder: Mesh and definition array sizes don't match")
		return 0
	
	var success_count := 0
	
	for i in range(tunnel_meshes.size()):
		if build_and_add_to_scene(tunnel_meshes[i], definitions[i], scene_root, i):
			success_count += 1
	
	return success_count

## Create default tunnel material (gray stone).
func _create_default_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = DEFAULT_TUNNEL_COLOR
	material.roughness = DEFAULT_ROUGHNESS
	material.metallic = DEFAULT_METALLIC
	return material

