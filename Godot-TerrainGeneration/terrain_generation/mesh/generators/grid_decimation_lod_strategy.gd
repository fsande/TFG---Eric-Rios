## @brief LOD generation strategy using grid-based mesh decimation.
##
## @details For terrain meshes with grid structure, this provides efficient LOD generation
## by sampling vertices at regular intervals. This is ideal for heightmap-based terrain
## where the regular grid structure can be exploited for fast, predictable simplification.
##
## The algorithm works by:
## 1. Calculating a step size based on the reduction ratio
## 2. Sampling vertices at regular intervals (every N vertices)
## 3. Rebuilding the grid with reduced resolution while maintaining topology
@tool
class_name GridDecimationLODStrategy extends LODGenerationStrategy

## Threshold for considering a reduction ratio as "full detail" (floating-point epsilon)
const FULL_DETAIL_THRESHOLD := 0.99

## Minimum grid dimensions required for decimation
const MIN_GRID_DIMENSION := 2

## Generate all LOD levels
func generate_lod_levels(
	source_mesh: MeshData,
	lod_count: int,
	reduction_ratios: Array[float]
) -> Array[MeshData]:
	if not can_process(source_mesh):
		push_error("GridDecimationLODStrategy: Cannot process source mesh")
		return []
	if not _is_valid_grid_mesh(source_mesh):
		push_warning("GridDecimationLODStrategy: Invalid grid mesh, cannot generate LOD levels")
		return [source_mesh]
	return super.generate_lod_levels(source_mesh, lod_count, reduction_ratios)

## Generate a single LOD level
func generate_lod_level(source_mesh: MeshData, reduction_ratio: float) -> MeshData:
	if not can_process(source_mesh):
		return null
	if reduction_ratio >= FULL_DETAIL_THRESHOLD:
		return source_mesh
	if not _is_valid_grid_mesh(source_mesh):
		push_warning("GridDecimationLODStrategy: Non-grid mesh detected, returning original")
		return source_mesh
	return _decimate_grid_mesh(source_mesh, reduction_ratio)

## Decimate a grid-structured mesh by reducing resolution while maintaining topology
func _decimate_grid_mesh(source_mesh: MeshData, reduction_ratio: float) -> MeshData:
	var width := source_mesh.width
	var height := source_mesh.height
	if width == 0 or height == 0:
		push_warning("GridDecimationLODStrategy: Invalid grid dimensions")
		return source_mesh
	var step: int = _calculate_decimation_step(width, height, reduction_ratio)
	var vertex_data := _extract_vertices(source_mesh, width, height, step)
	var new_indices := _generate_grid_indices(vertex_data.vertex_map, width, height, step)
	return _create_decimated_mesh(
		vertex_data.vertices,
		new_indices,
		vertex_data.uvs,
		vertex_data.new_width,
		vertex_data.new_height,
		source_mesh.mesh_size
	)

## Get the human-readable name of this LOD generation strategy
func get_strategy_name() -> String:
	return "Grid Decimation LOD"

## Validate that the mesh has a valid grid structure for decimation
func _is_valid_grid_mesh(mesh: MeshData) -> bool:
	return (mesh.width >= MIN_GRID_DIMENSION and 
			mesh.height >= MIN_GRID_DIMENSION and
			mesh.width * mesh.height == mesh.vertices.size())

## Calculate the decimation step size based on reduction ratio
func _calculate_decimation_step(width: int, height: int, reduction_ratio: float) -> int:
	var step: int = max(1, int(round(1.0 / sqrt(reduction_ratio))))
	step = min(step, min(width - 1, height - 1))
	return step

## Extract vertices and UVs at regular intervals from the source mesh
func _extract_vertices(source_mesh: MeshData, width: int, height: int, step: int) -> VertexExtractionResult:
	var new_width: int = (width - 1) / step + 1
	var new_height: int = (height - 1) / step + 1
	var new_vertices := PackedVector3Array()
	var new_uvs := PackedVector2Array()
	var vertex_map := {}
	var new_idx := 0
	for y in range(0, height, step):
		for x in range(0, width, step):
			var old_idx := y * width + x
			if old_idx < source_mesh.vertices.size():
				new_vertices.append(source_mesh.vertices[old_idx])
				if old_idx < source_mesh.uvs.size():
					new_uvs.append(source_mesh.uvs[old_idx])
				vertex_map[Vector2i(x, y)] = new_idx
				new_idx += 1
	return VertexExtractionResult.new(new_vertices, new_uvs, vertex_map, new_width, new_height)

## Generate triangle indices for the decimated grid topology
func _generate_grid_indices(vertex_map: Dictionary, width: int, height: int, step: int) -> PackedInt32Array:
	var new_indices := PackedInt32Array()
	for y in range(0, height - step, step):
		for x in range(0, width - step, step):
			var v0: int = vertex_map.get(Vector2i(x, y), -1)
			var v1: int = vertex_map.get(Vector2i(x + step, y), -1)
			var v2: int = vertex_map.get(Vector2i(x, y + step), -1)
			var v3: int = vertex_map.get(Vector2i(x + step, y + step), -1)
			if v0 >= 0 and v1 >= 0 and v2 >= 0 and v3 >= 0:
				new_indices.append(v0)
				new_indices.append(v1)
				new_indices.append(v2)
				new_indices.append(v1)
				new_indices.append(v3)
				new_indices.append(v2)
	return new_indices

## Create the final decimated mesh data with updated grid dimensions
func _create_decimated_mesh(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	new_width: int,
	new_height: int,
	mesh_size: Vector2
) -> MeshData:
	var lod_mesh := MeshData.new(vertices, indices, uvs)
	lod_mesh.width = new_width
	lod_mesh.height = new_height
	lod_mesh.mesh_size = mesh_size
	return lod_mesh


