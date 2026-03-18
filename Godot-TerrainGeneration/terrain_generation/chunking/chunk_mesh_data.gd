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

## Array of meshes, index = LOD level (0 = highest detail)
var lod_meshes: Array[ArrayMesh] = []

## Number of LOD levels in the mesh
var lod_level_count: int = 1

## Currently active LOD level
var current_lod_level: int = 0

## Distance thresholds for each LOD level
var lod_distances: Array[float] = []

## Collision shape for this chunk (generated on-demand)
var collision_shape: Shape3D = null

## Whether collision has been generated
var has_collision: bool = false

## Whether this chunk is currently loaded in the scene
var is_loaded: bool = false

## Initialize chunk with coordinate, position, size, and mesh data
func _init(coord: Vector2i, position: Vector3, size: Vector2, p_mesh: MeshData, lod_level: int):
	chunk_coord = coord
	world_position = position
	chunk_size = size
	add_lod_mesh(p_mesh, lod_level)
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

func add_lod_mesh(p_mesh_data: MeshData, lod_level: int) -> void:
	if lod_level < 0:
		push_warning("ChunkMeshData: Invalid LOD level %d" % lod_level)
		return
	while lod_meshes.size() <= lod_level:
		lod_meshes.append(null)
	var array_mesh := ArrayMeshBuilder.build_mesh(p_mesh_data)
	if array_mesh:
		lod_meshes[lod_level] = array_mesh
	else:
		push_warning("ChunkMeshData: Failed to build ArrayMesh for LOD %d" % lod_level)
	lod_level_count = max(lod_level_count, lod_level + 1)

func has_lod_mesh(lod_level: int) -> bool:
	return lod_level >= 0 and lod_level < lod_meshes.size() and lod_meshes[lod_level] != null

## Get appropriate mesh for given distance
## @param distance Distance from camera to chunk center
## @return ArrayMesh at appropriate LOD level
func get_mesh_for_distance(distance: float) -> ArrayMesh:
	if lod_meshes.is_empty():
		push_error("Could not get mesh")
		return null
	var lod_level := get_lod_level_for_distance(distance)
	if lod_level < lod_meshes.size():
		return lod_meshes[lod_level]
	return lod_meshes[lod_meshes.size() - 1]

## Get appropriate LOD level for distance
## @param distance Distance from camera to chunk center
## @return LOD level (0 = highest detail, higher = lower detail)
func get_lod_level_for_distance(distance: float) -> int:
	if lod_distances.is_empty():
		return 0
	for i in range(lod_distances.size()):
		if distance < lod_distances[i]:
			return i
	return min(lod_distances.size(), lod_level_count - 1)

## Generate collision shape for this chunk
## @param lod_level LOD level to use for collision mesh (-1 for simple box)
## @return Generated collision shape
func build_collision(lod_level: int) -> Shape3D:
	if lod_level == -1:
		var shape := BoxShape3D.new()
		shape.size = Vector3(chunk_size.x, aabb.size.y, chunk_size.y)
		collision_shape = shape
	var mesh: ArrayMesh = null
	if lod_level < lod_meshes.size() and lod_meshes[lod_level]:
		mesh = lod_meshes[lod_level]
	else:
		mesh = lod_meshes[0]
	if not mesh:
		push_warning("ChunkMeshData: Cannot build collision - no mesh")
		return null
	else:
		collision_shape = mesh.create_trimesh_shape()
	has_collision = true
	return collision_shape

## Get distance from this chunk's center to a point
func distance_to(point: Vector3) -> float:
	return world_position.distance_to(point)

## Check if point is within chunk bounds (XZ plane)
func contains_point_xz(point: Vector3) -> bool:
	var local := point - world_position
	var half_x := chunk_size.x / 2.0
	var half_z := chunk_size.y / 2.0
	return abs(local.x) <= half_x and abs(local.z) <= half_z
