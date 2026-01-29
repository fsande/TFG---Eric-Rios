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

## Build multiple LOD level meshes using specified strategy
## @param lod_generation_strategy Strategy for mesh simplification
## @param lod_count Number of LOD levels to generate
## @param p_lod_distances Distance thresholds for LOD transitions
## @param reduction_ratios Triangle reduction ratios per LOD level
func build_mesh_with_multiple_lods(
	lod_generation_strategy: LODGenerationStrategy,
	lod_count: int,
	p_lod_distances: Array[float],
	reduction_ratios: Array[float]
) -> void:
	if not mesh_data or mesh_data.vertices.size() == 0:
		push_warning("ChunkMeshData: Cannot build LOD meshes - no mesh data")
		return
	if not lod_generation_strategy:
		push_warning("ChunkMeshData: No LOD generation strategy provided")
		return
	if not lod_generation_strategy.can_process(mesh_data):
		push_warning("ChunkMeshData: LOD strategy cannot process this mesh")
		return
	var lod_mesh_data := lod_generation_strategy.generate_lod_levels(
		mesh_data,
		lod_count,
		reduction_ratios
	)
	print("Generated mesh data using strategy: %s, with amount of LODs: %d, when lod_count was %d" % [
		lod_generation_strategy.get_strategy_name(),
		lod_mesh_data.size(),
		lod_count
	])
	lod_meshes.clear()
	for i in range(lod_mesh_data.size()):
		var lod_data := lod_mesh_data[i]
		if lod_data:
			var array_mesh := ArrayMeshBuilder.build_mesh(lod_data)
			if array_mesh:
				lod_meshes.append(array_mesh)
			else:
				push_warning("ChunkMeshData: Failed to build ArrayMesh for LOD %d" % i)
		else:
			push_warning("ChunkMeshData: No mesh data for LOD %d" % i)
	lod_level_count = lod_meshes.size()
	lod_distances = p_lod_distances.duplicate()
	if lod_meshes.size() > 0:
		mesh = lod_meshes[0]
	if lod_level_count > 0:
		var total_triangles := 0
		for lod_mesh in lod_meshes:
			if lod_mesh and lod_mesh.get_surface_count() > 0:
				var arrays := lod_mesh.surface_get_arrays(0)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				total_triangles += indices.size() / 3
		print("ChunkMeshData: Built %d LOD levels for chunk %v (Total triangles: %d)" % [
			lod_level_count,
			chunk_coord,
			total_triangles
		])

## Get appropriate mesh for given distance
## @param distance Distance from camera to chunk center
## @return ArrayMesh at appropriate LOD level
func get_mesh_for_distance(distance: float) -> ArrayMesh:
	if lod_meshes.is_empty():
		return mesh
	
	var lod_level := get_lod_level_for_distance(distance)
	if lod_level < lod_meshes.size():
		return lod_meshes[lod_level]
	
	# Return lowest detail LOD if distance exceeds all thresholds
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
## @param use_simplified Use simplified collision (BoxShape3D vs ConcavePolygonShape3D)
## @return Generated collision shape
func build_collision(use_simplified: bool = false) -> Shape3D:
	if not mesh_data or mesh_data.vertices.size() == 0:
		push_warning("ChunkMeshData: Cannot build collision - no mesh data")
		return null
	if use_simplified:
		var shape := BoxShape3D.new()
		shape.size = Vector3(chunk_size.x, aabb.size.y, chunk_size.y)
		collision_shape = shape
	else:
		if not mesh:
			build_mesh_with_lod()
		if mesh:
			collision_shape = mesh.create_trimesh_shape()
		else:
			push_warning("ChunkMeshData: Failed to build mesh for collision")
			return null
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

## Cleanup GPU resources while preserving mesh_data for potential reload
func cleanup() -> void:
	if mesh:
		mesh = null
	lod_meshes.clear()
	lod_level_count = 1
	current_lod_level = 0
	if collision_shape:
		collision_shape = null
	has_collision = false
	is_loaded = false

## Cleanup specific LOD meshes (keep only specified levels)
## @param keep_lod_levels Array of LOD levels to keep in memory
func cleanup_lod_meshes(keep_lod_levels: Array[int] = []) -> void:
	if lod_meshes.is_empty():
		return
	var new_lod_meshes: Array[ArrayMesh] = []
	new_lod_meshes.resize(lod_meshes.size())
	for level in keep_lod_levels:
		if level >= 0 and level < lod_meshes.size():
			new_lod_meshes[level] = lod_meshes[level]
	lod_meshes = new_lod_meshes


## Deep cleanup that also clears mesh_data (chunk cannot be reloaded after this)
func deep_cleanup() -> void:
	cleanup()
	print("Deep cleaning chunk mesh data at coord %v" % chunk_coord)
	if mesh_data:
		mesh_data.vertices.clear()
		mesh_data.indices.clear()
		mesh_data.uvs.clear()
		mesh_data.cached_normals.clear()
		mesh_data.cached_tangents.clear()
		mesh_data = null
	cleanup_lod_meshes()
