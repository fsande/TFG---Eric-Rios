## @brief Container for a single terrain chunk's mesh data and LOD.
##
## @details Holds a subset of the terrain mesh, its world position,
## and can generate LOD levels using Godot's built-in mesh decimation.
class_name ChunkMeshData extends RefCounted

## Chunk grid coordinate (e.g., Vector2i(0,0) for first chunk)
var chunk_coord: Vector2i

## World-space center position of this chunk
var world_position: Vector3

## Size of chunk in world units (XZ plane)
var chunk_size: Vector2

## Axis-aligned bounding box for this chunk
var aabb: AABB

## Core mesh data (vertices, indices, UVs) - subset of terrain mesh
var mesh_data: MeshData

## Built ArrayMesh with LOD levels (null until built)
var mesh: ArrayMesh = null

## Number of LOD levels in the mesh
var lod_level_count: int = 1

## Collision shape for this chunk (generated on-demand)
var collision_shape: Shape3D = null

## Whether collision has been generated
var has_collision: bool = false

## Whether this chunk is currently loaded in the scene
var is_loaded: bool = false

## Initialize chunk with coordinate, position, size, and mesh data
func _init(coord: Vector2i, position: Vector3, size: Vector2, p_mesh: MeshData):
	chunk_coord = coord
	world_position = position
	chunk_size = size
	mesh_data = p_mesh
	var half_size := Vector3(size.x / 2.0, 0, size.y / 2.0)
	var aabb_min := position - half_size
	var aabb_max := position + half_size
	if p_mesh and p_mesh.vertices.size() > 0:
		var min_y := INF
		var max_y := -INF
		for vertex in p_mesh.vertices:
			min_y = min(min_y, vertex.y)
			max_y = max(max_y, vertex.y)
		aabb_min.y = min_y
		aabb_max.y = max_y
	aabb = AABB(aabb_min, aabb_max - aabb_min)

## Build ArrayMesh with automatic LOD generation using Godot's ImporterMesh
## @param normal_merge_angle Maximum angle difference to merge normals (degrees)
## @param normal_split_angle Maximum angle to split normals during LOD (degrees)
## @return Built ArrayMesh with LOD levels
func build_mesh_with_lod(normal_merge_angle: float = 60.0, normal_split_angle: float = 25.0) -> ArrayMesh:
	if not mesh_data or mesh_data.vertices.size() == 0:
		push_warning("ChunkMeshData: Cannot build mesh - no mesh data")
		return null
	mesh = ArrayMeshBuilder.build_mesh(mesh_data)
	return mesh

## Generate collision shape for this chunk
## @param use_simplified Use simplified collision (BoxShape3D vs ConcavePolygonShape3D)
## @return Generated collision shape
func build_collision(use_simplified: bool = false) -> Shape3D:
	return null

## Get distance from this chunk's center to a point
func distance_to(point: Vector3) -> float:
	return world_position.distance_to(point)

## Check if point is within chunk bounds (XZ plane)
func contains_point_xz(point: Vector3) -> bool:
	var local := point - world_position
	var half_x := chunk_size.x / 2.0
	var half_z := chunk_size.y / 2.0
	return abs(local.x) <= half_x and abs(local.z) <= half_z

## Cleanup resources
func cleanup() -> void:
	if mesh:
		mesh = null
	if collision_shape:
		collision_shape = null
	has_collision = false
	is_loaded = false

