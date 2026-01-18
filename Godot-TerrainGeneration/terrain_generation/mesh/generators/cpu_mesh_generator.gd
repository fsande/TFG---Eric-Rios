## @brief CPU-based mesh generator that creates meshes from heightmaps.
@tool
class_name CpuMeshGenerator extends HeightmapMeshGenerator

## Generate mesh by sampling the heightmap using ProcessingContext parameters.
func generate_mesh(mesh_array: Array, heightmap: Image, context: ProcessingContext) -> MeshGenerationResult:
	var start_time := Time.get_ticks_usec()
	var arrays := mesh_array
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var mesh_parameters := context.mesh_parameters
	var height_scale: float = mesh_parameters.height_scale
	var mesh_size: Vector2 = mesh_parameters.mesh_size
	for i in range(vertices.size()):
		var vertex := vertices[i]
		var uv := _vertex_to_uv(vertex, mesh_size)
		var height := _sample_heightmap(heightmap, uv)
		vertex.y = height * height_scale
		vertices[i] = vertex
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var elapsed_time := Time.get_ticks_usec() - start_time
	var result := MeshGenerationResult.new(vertices, indices, uvs, elapsed_time * 0.001, "CPU")
	var subdivisions: int = mesh_parameters.subdivisions
	result.width = subdivisions + 1
	result.height = subdivisions + 1
	result.mesh_size = mesh_size
	print("CPUMeshGenerator: subdivisions=%d, grid=%dx%d, actual vertices=%d, mesh_size=%s" % [
		subdivisions, result.width, result.height, vertices.size(), mesh_size
	])
	result.slope_normal_map = SlopeComputer.compute_slope_normal_map(result, context)
	return result

## Convert a vertex position to a UV coordinate for heightmap sampling.
## NOTE: We calculate UVs from world position rather than using mesh UVs because
## the heightmap represents world space. The original mesh UVs are preserved
## for texture mapping in the final mesh.
func _vertex_to_uv(vertex: Vector3, mesh_size: Vector2) -> Vector2:
	return Vector2(
		(vertex.x / mesh_size.x) + 0.5, 
		(vertex.z / mesh_size.y) + 0.5
	)

## Sample the heightmap at the given UV and return the red channel as height.
func _sample_heightmap(heightmap: Image, uv: Vector2) -> float:
	return ImageHelper.sample_bilinear(heightmap, uv)
