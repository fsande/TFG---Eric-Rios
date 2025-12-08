## @brief Base interface for mesh generators that create meshes from heightmaps.
##
## @details Implementations generate mesh vertex positions, normals, and tangents from a
## heightmap using a shared ProcessingContext for GPU resources and parameters.
@tool
class_name HeightmapMeshGenerator extends Resource

## Emitted when a generation operation completes with a `MeshGenerationResult`.
signal modification_completed(result: MeshGenerationResult)

## Generate a mesh from heightmap using ProcessingContext. Must be overridden.
func generate_mesh(mesh_array: Array, heightmap: Image, context: ProcessingContext) -> MeshGenerationResult:
	push_error("HeightmapMeshGenerator.generate_mesh() must be overridden in subclass")
	return null
