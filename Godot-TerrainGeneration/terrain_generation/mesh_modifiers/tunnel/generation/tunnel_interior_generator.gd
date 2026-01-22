## @brief Generates interior mesh geometry for tunnel shapes.
##
## @details Implements the interior mesh generation pipeline:
## - Delegates to TunnelShape.generate_interior_mesh()
## - Applies terrain clipping to remove above-ground geometry
## - Ensures smooth transitions at terrain boundaries
##
## Design Pattern: Strategy Pattern - Uses TunnelShape strategies for different tunnel types.
## SOLID: Single Responsibility - Only concerned with interior mesh generation orchestration.
@tool
class_name TunnelInteriorGenerator extends RefCounted

## Minimum triangle area threshold for degenerate triangle detection (in square units)
const TRIANGLE_AREA_EPSILON: float = 0.0001

## Multiplier for calculating triangle area from cross product magnitude
const TRIANGLE_AREA_MULTIPLIER: float = 0.5

## Reference to the clipper for terrain-aware geometry processing
var _clipper: TunnelInteriorClipper

## Configuration: minimum vertex count threshold for valid meshes
var min_vertex_threshold: int = 3

## Configuration: enable/disable terrain clipping
var enable_terrain_clipping: bool = true

## Configuration: enable/disable mesh optimization
var enable_mesh_optimization: bool = true

func _init() -> void:
	_clipper = TunnelInteriorClipper.new()

## Generate interior mesh for a tunnel shape with terrain awareness.
##
## @param shape TunnelShape defining the tunnel geometry
## @param terrain_querier TerrainHeightQuerier for terrain height lookups
## @return MeshData containing the clipped interior geometry, or empty mesh if generation fails
func generate(shape: TunnelShape, terrain_querier: TerrainHeightQuerier) -> MeshData:
	if shape == null:
		push_error("TunnelInteriorGenerator: Cannot generate interior for null shape")
		return MeshData.new()
	if terrain_querier == null:
		push_error("TunnelInteriorGenerator: Invalid terrain height querier")
		return MeshData.new()
	var raw_mesh := shape.generate_interior_mesh(terrain_querier)
	if raw_mesh.get_vertex_count() < min_vertex_threshold:
		push_warning("TunnelInteriorGenerator: Shape generated insufficient vertices (%d < %d)" % 
			[raw_mesh.get_vertex_count(), min_vertex_threshold])
		return MeshData.new()
	var clipped_mesh := raw_mesh
	if enable_terrain_clipping:
		clipped_mesh = _clipper.clip_to_terrain(raw_mesh, terrain_querier)
		if clipped_mesh.get_vertex_count() < min_vertex_threshold:
			push_warning("TunnelInteriorGenerator: Clipping resulted in insufficient vertices (%d < %d)" % 
				[clipped_mesh.get_vertex_count(), min_vertex_threshold])
			return MeshData.new()
	if enable_mesh_optimization:
		_optimize_mesh(clipped_mesh)
	clipped_mesh.processor_type = "TunnelInteriorGenerator"
	return clipped_mesh

## Generate interior for multiple tunnel shapes in batch.
##
## @param shapes Array of TunnelShape objects
## @param terrain_querier TerrainHeightQuerier for terrain height lookups
## @return Array[MeshData] containing generated meshes (may include empty meshes for failed generations)
func generate_batch(shapes: Array[TunnelShape], terrain_querier: TerrainHeightQuerier) -> Array[MeshData]:
	var results: Array[MeshData] = []
	for shape in shapes:
		var mesh := generate(shape, terrain_querier)
		results.append(mesh)
	return results

## Optimize mesh by removing degenerate triangles and duplicate vertices.
##
## @param mesh MeshData to optimize (modified in-place)
func _optimize_mesh(mesh: MeshData) -> void:
	if mesh.indices.size() == 0:
		return
	var optimized_indices := PackedInt32Array()
	var degenerate_count := 0
	for tri_idx in range(0, mesh.indices.size(), 3):
		var i0 := mesh.indices[tri_idx]
		var i1 := mesh.indices[tri_idx + 1]
		var i2 := mesh.indices[tri_idx + 2]
		if i0 == i1 or i1 == i2 or i2 == i0:
			degenerate_count += 1
			continue
		var v0 := mesh.vertices[i0]
		var v1 := mesh.vertices[i1]
		var v2 := mesh.vertices[i2]
		var edge1 := v1 - v0
		var edge2 := v2 - v0
		var cross := edge1.cross(edge2)
		var area := cross.length() * TRIANGLE_AREA_MULTIPLIER
		if area < TRIANGLE_AREA_EPSILON:
			degenerate_count += 1
			continue
		optimized_indices.append(i0)
		optimized_indices.append(i1)
		optimized_indices.append(i2)
	
	if degenerate_count > 0:
		print("  TunnelInteriorGenerator: Removed %d degenerate triangles" % degenerate_count)
		mesh.indices = optimized_indices

## Set clipper configuration.
##
## @param clipper_config Dictionary with clipper settings (tolerance, interpolation_mode, etc.)
func configure_clipper(clipper_config: Dictionary) -> void:
	if clipper_config.has("tolerance"):
		_clipper.edge_intersection_tolerance = clipper_config["tolerance"]
	
	if clipper_config.has("interpolation_quality"):
		_clipper.interpolation_quality = clipper_config["interpolation_quality"]

## Get statistics about the last generation operation.
##
## @return Dictionary with generation metrics
func get_statistics() -> Dictionary:
	return {
		"clipper_stats": _clipper.get_statistics(),
		"terrain_clipping_enabled": enable_terrain_clipping,
		"mesh_optimization_enabled": enable_mesh_optimization
	}

