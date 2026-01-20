## @brief Container that holds the generated terrain artifacts.
##
## @details Immutable result produced by the terrain generation pipeline. Holds
## the heightmap image, mesh generation result, optional collision shape, Metadata and
## timing information. The mesh is built lazily from MeshGenerationResult for performance.
class_name TerrainData extends RefCounted

## Heightmap Image (FORMAT_RF) used to build the mesh.
var heightmap: Image
## Generated mesh data (vertices, indices, UVs). Build to ArrayMesh via get_mesh().
var mesh_result: MeshGenerationResult
## Optional collision shape for physics.
var collision_shape: Shape3D
## Metadata dictionary with generation parameters and provenance.
var metadata: Dictionary
## Generation time in milliseconds.
var generation_time_ms: float

## World size of the terrain
var terrain_size: Vector2

## Container for agent-generated nodes (debug visualizations, spawned objects, etc.)
## Populated during mesh modification pipeline, transferred to scene tree by presenter.
var agent_node_root: Node3D

## Cached ArrayMesh built from mesh_result.
var _cached_mesh: ArrayMesh = null

## Construct a TerrainData result.
func _init(
	p_heightmap: Image,
	p_mesh_result: MeshGenerationResult,
	p_terrain_size: Vector2,
	p_collision: Shape3D = null,
	p_metadata: Dictionary = {},
	p_time: float = 0.0,
	p_agent_node_root: Node3D = null
):
	heightmap = p_heightmap
	mesh_result = p_mesh_result
	terrain_size = p_terrain_size
	collision_shape = p_collision
	metadata = p_metadata
	generation_time_ms = p_time
	agent_node_root = p_agent_node_root

## Get the mesh as ArrayMesh (builds on first call, then cached).
func get_mesh() -> ArrayMesh:
	if not _cached_mesh and mesh_result:
		_cached_mesh = mesh_result.build_mesh()
	return _cached_mesh

## Return true when a collision shape is attached.
func has_collision() -> bool:
	return collision_shape != null

## Return the number of vertices in the mesh (0 if none).
func get_vertex_count() -> int:
	if mesh_result:
		return mesh_result.vertex_count
	return 0

## Return the number of triangles in the mesh (0 if none).
func get_triangle_count() -> int:
	if mesh_result:
		return mesh_result.indices.size() / 3
	return 0

## Cleanup orphaned agent nodes to prevent memory leaks.
## Call this when discarding TerrainData that was never applied to the scene.
## If nodes were transferred to scene tree, they're safe and won't be freed.
func cleanup_orphaned_nodes() -> void:
	if agent_node_root:
		var freed_count := OrphanNodeDetector.cleanup_orphans_in(agent_node_root)
		if freed_count > 0:
			print("TerrainData: Freed %d orphaned nodes" % freed_count)
		agent_node_root = null

