## @brief Builds terrain meshes from heightmaps using a `HeightmapMeshGenerator` implementation.
class_name TerrainMeshBuilder extends RefCounted

## Mesh generator strategy used to create meshes from heightmaps.
var mesh_modifier: HeightmapMeshGenerator

func _init(p_modifier: HeightmapMeshGenerator = null):
	mesh_modifier = p_modifier if p_modifier else CPUMeshGenerator.new()

## Build mesh from heightmap using ProcessingContext.
## Returns a MeshGenerationResult or null on failure.
func build_mesh(heightmap: Image, context: ProcessingContext) -> MeshGenerationResult:
	if not heightmap:
		push_error("TerrainMeshBuilder: No heightmap provided")
		return null
	
	var mesh_params := context.mesh_params
	var mesh_size: Vector2 = mesh_params.mesh_size
	var subdivisions: int = mesh_params.subdivisions
	var plane := PlaneMesh.new()
	plane.subdivide_depth = subdivisions
	plane.subdivide_width = subdivisions
	plane.size = mesh_size
	var original_arrays := plane.get_mesh_arrays()
	var result: MeshGenerationResult = mesh_modifier.generate_mesh(original_arrays, heightmap, context)
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
func set_mesh_modifier(modifier: HeightmapMeshGenerator) -> void:
	mesh_modifier = modifier
