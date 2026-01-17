## @brief Builds terrain meshes from heightmaps using a `HeightmapMeshGenerator` implementation.
class_name TerrainMeshBuilder extends RefCounted

## Mesh generator strategy used to create meshes from heightmaps.
var mesh_generator: HeightmapMeshGenerator

## Build mesh from heightmap using ProcessingContext.
## Returns a MeshGenerationResult or null on failure.
func build_mesh(heightmap: Image, context: ProcessingContext) -> MeshGenerationResult:
	if not heightmap:
		push_error("TerrainMeshBuilder: No heightmap provided")
		return null
	var mesh_params := context.mesh_parameters
	var mesh_size: Vector2 = mesh_params.mesh_size
	var subdivisions := mesh_params.subdivisions
	var plane := PlaneMesh.new()
	plane.subdivide_depth = subdivisions
	plane.subdivide_width = subdivisions
	plane.size = mesh_size
	var original_arrays := plane.get_mesh_arrays()
	initialize_generator(context.mesh_generator_type)
	var result: MeshGenerationResult = mesh_generator.generate_mesh(original_arrays, heightmap, context)
	if not result:
		push_error("TerrainMeshBuilder: Mesh generation failed")
		return null	
	return result

## Create a collision Shape3D from the provided mesh result (triangle mesh).
func build_collision(mesh_result: MeshGenerationResult) -> Shape3D:
	if not mesh_result:
		return null
	var mesh := mesh_result.build_mesh()
	return mesh.create_trimesh_shape() if mesh else null

## Set the mesh modifier strategy used by this builder.
func initialize_generator(type: ProcessingContext.ProcessorType):
	match type:
		ProcessingContext.ProcessorType.CPU:
			mesh_generator = CpuMeshGenerator.new()
		ProcessingContext.ProcessorType.GPU:
			mesh_generator = GpuMeshGenerator.new()
		_:
			push_error("TerrainMeshBuilder: Unknown processor type %s" % str(type))
