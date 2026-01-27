## @brief Partitions a MeshGenerationResult into spatial chunks.
##
## @details Provides static methods to split a single terrain mesh into
## a grid of smaller chunks while preserving triangle integrity and
## minimizing vertex duplication.
class_name MeshPartitioner extends RefCounted

## Partition mesh into grid of chunks based on world-space bounds
##
## @param mesh_result Source mesh to partition
## @param chunk_size Size of each chunk in world units (XZ plane)
## @return Array of ChunkMeshData objects
static func partition_mesh(mesh_result: MeshGenerationResult, chunk_size: Vector2) -> Array[ChunkMeshData]:
	if not mesh_result or mesh_result.vertices.size() == 0:
		push_warning("MeshPartitioner: Cannot partition empty mesh")
		return []
	var mesh_size := mesh_result.mesh_size
	var grid_dims := _calculate_chunk_grid_dimensions(mesh_size, chunk_size)
	var chunks: Array[ChunkMeshData] = []
	var origin_offset := Vector3(-mesh_size.x / 2.0, 0, -mesh_size.y / 2.0)
	for chunk_z in range(grid_dims.y):
		for chunk_x in range(grid_dims.x):
			var coord := Vector2i(chunk_x, chunk_z)
			var chunk := _extract_chunk(mesh_result, coord, chunk_size, mesh_size)
			if chunk:
				chunks.append(chunk)
	print("MeshPartitioner: Created %d chunks (%dx%d grid)" % [chunks.size(), grid_dims.x, grid_dims.y])
	return chunks

## Partition mesh with overlapping boundaries to prevent seams
##
## @param mesh_result Source mesh to partition
## @param chunk_size Size of each chunk in world units
## @param overlap_margin Amount of overlap between adjacent chunks (world units)
## @return Array of ChunkMeshData objects with overlapping edges
static func partition_mesh_with_overlap(
	mesh_result: MeshGenerationResult,
	chunk_size: Vector2,
	_overlap_margin: float = 2.0
) -> Array[ChunkMeshData]:
	push_warning("MeshPartitioner: Overlapping partition not yet implemented, using standard partition")
	return partition_mesh(mesh_result, chunk_size)

## Extract single chunk from source mesh
static func _extract_chunk(
	mesh_result: MeshGenerationResult,
	chunk_coord: Vector2i,
	chunk_size: Vector2,
	total_mesh_size: Vector2
) -> ChunkMeshData:
	var origin_offset := Vector3(-total_mesh_size.x / 2.0, 0, -total_mesh_size.y / 2.0)
	var chunk_min := Vector2(
		chunk_coord.x * chunk_size.x,
		chunk_coord.y * chunk_size.y
	)
	var chunk_max := chunk_min + chunk_size
	var chunk_center := origin_offset + Vector3(
		chunk_min.x + chunk_size.x / 2.0,
		0,
		chunk_min.y + chunk_size.y / 2.0
	)
	var chunk_vertices := PackedVector3Array()
	var chunk_uvs := PackedVector2Array()
	var chunk_indices := PackedInt32Array()
	var vertex_map := {}
	for i in range(0, mesh_result.indices.size(), 3):
		var idx0 := mesh_result.indices[i]
		var idx1 := mesh_result.indices[i + 1]
		var idx2 := mesh_result.indices[i + 2]
		var v0 := mesh_result.vertices[idx0]
		var v1 := mesh_result.vertices[idx1]
		var v2 := mesh_result.vertices[idx2]
		var triangle_center := (v0 + v1 + v2) / 3.0
		var local_pos := Vector2(triangle_center.x - origin_offset.x, triangle_center.z - origin_offset.z)
		if local_pos.x >= chunk_min.x and local_pos.x < chunk_max.x and \
		   local_pos.y >= chunk_min.y and local_pos.y < chunk_max.y:
			var new_idx0 := _add_vertex_to_chunk(idx0, mesh_result, chunk_vertices, chunk_uvs, vertex_map)
			var new_idx1 := _add_vertex_to_chunk(idx1, mesh_result, chunk_vertices, chunk_uvs, vertex_map)
			var new_idx2 := _add_vertex_to_chunk(idx2, mesh_result, chunk_vertices, chunk_uvs, vertex_map)
			chunk_indices.append(new_idx0)
			chunk_indices.append(new_idx1)
			chunk_indices.append(new_idx2)
	if chunk_vertices.size() == 0:
		return null
	var chunk_mesh_data := MeshData.new(chunk_vertices, chunk_indices, chunk_uvs)
	chunk_mesh_data.mesh_size = chunk_size
	return ChunkMeshData.new(chunk_coord, chunk_center, chunk_size, chunk_mesh_data)

## Check if point is within chunk bounds (XZ plane)
static func _is_point_in_chunk_bounds(point: Vector3, min_bounds: Vector2, max_bounds: Vector2) -> bool:
	return point.x >= min_bounds.x and point.x < max_bounds.x and \
	       point.z >= min_bounds.y and point.z < max_bounds.y

## Add vertex to chunk arrays, avoiding duplication
static func _add_vertex_to_chunk(
	original_index: int,
	source_mesh: MeshGenerationResult,
	chunk_vertices: PackedVector3Array,
	chunk_uvs: PackedVector2Array,
	vertex_map: Dictionary
) -> int:
	if vertex_map.has(original_index):
		return vertex_map[original_index]
	var new_index := chunk_vertices.size()
	chunk_vertices.append(source_mesh.vertices[original_index])
	chunk_uvs.append(source_mesh.uvs[original_index])
	vertex_map[original_index] = new_index
	return new_index

## Calculate chunk grid dimensions from mesh size
static func _calculate_chunk_grid_dimensions(mesh_size: Vector2, chunk_size: Vector2) -> Vector2i:
	var chunks_x := ceili(mesh_size.x / chunk_size.x)
	var chunks_y := ceili(mesh_size.y / chunk_size.y)
	return Vector2i(chunks_x, chunks_y)

