## @brief Abstract interface for different mesh simplification algorithms.
##
## @details Implement this to create custom LOD generation strategies.
## The strategy pattern allows swapping between different simplification
## algorithms (ImporterMesh, Quadric Error Metrics, GPU-based, etc.)
## without changing client code.
@tool
class_name LODGenerationStrategy extends RefCounted

## Generate a single LOD level from source mesh
## @param source_mesh Original mesh data at full detail
## @param reduction_ratio Target triangle reduction (1.0 = full, 0.5 = half, etc.)
## @return Simplified MeshData
func generate_lod_level(source_mesh: MeshData, reduction_ratio: float) -> MeshData:
	push_error("LODGenerationStrategy.generate_lod_level() must be overridden in subclass")
	return null

## Generate all LOD levels at once (some algorithms can optimize batch generation)
## @param source_mesh Original mesh data
## @param lod_count Number of LOD levels to generate
## @param reduction_ratios Array of reduction ratios per level
## @return Array of MeshData, index 0 = highest detail (original mesh)
func generate_lod_levels(
	source_mesh: MeshData,
	lod_count: int,
	reduction_ratios: Array[float]
) -> Array[MeshData]:
	var lod_meshes: Array[MeshData] = []
	lod_meshes.append(source_mesh)
	print("Called generate lod levels with lod count: %d" % lod_count)
	for i in range(1, lod_count):
		if i >= reduction_ratios.size():
			push_warning("LODGenerationStrategy: Not enough reduction ratios for LOD level %d" % i)
			break
		var lod_mesh := generate_lod_level(source_mesh, reduction_ratios[i])
		if lod_mesh:
			lod_meshes.append(lod_mesh)
		else:
			push_warning("LODGenerationStrategy: Failed to generate LOD level %d" % i)
			break
	return lod_meshes

## Validate if this strategy can process the given mesh
## @param mesh Mesh to validate
## @return true if mesh can be processed
func can_process(mesh: MeshData) -> bool:
	return mesh != null and mesh.vertices.size() > 0

## Get human-readable name of this strategy
func get_strategy_name() -> String:
	return "Base LOD Strategy"

