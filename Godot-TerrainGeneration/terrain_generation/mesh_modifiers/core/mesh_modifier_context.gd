## @brief High-level facade for mesh modification operations.
##
## @details Provides terrain-focused API for agents to modify mesh data.
## Does NOT own data - references MeshGenerationResult and VertexGrid.
## Follows Facade pattern: simplifies complex operations.
##
## Agents can access GPU operations through the context:
##   - context.use_gpu() - Check if GPU mode is active
##   - context.get_rendering_device() - Get RenderingDevice for compute shaders
##   - context.get_or_create_shader(path) - Load cached shader
##   - context.get_terrain_size() - Get terrain size
##   - context.get_generation_seed() - Get generation seed
class_name MeshModifierContext extends RefCounted

## REFERENCES (not owned)
var _mesh: MeshGenerationResult
var _grid: VertexGrid

## GPU/Processing context
var processing_context: ProcessingContext

## Terrain world data
var _terrain_data: TerrainData

## Scene management (for agents that spawn objects)
var agent_node_root: Node3D

## Pipeline parameters
var parameters: MeshGeneratorParameters

## Execution statistics (used by pipeline for reporting)
var execution_stats: Array[ExecutionStat] = []

## Current agent name (for debugging)
var current_agent_name: String = ""

## Construct context with mesh data and processing context.
## ProcessingContext is REQUIRED for GPU operations and parameter access.
func _init(p_terrain_data: TerrainData, p_processing_context: ProcessingContext, p_agent_node_root: Node3D, p_parameters: MeshGeneratorParameters) -> void:
	_mesh = p_terrain_data.mesh_result
	_terrain_data = p_terrain_data
	processing_context = p_processing_context
	_grid = VertexGrid.new(_mesh.width, _mesh.height)
	_grid.build_from_mesh(_mesh)
	agent_node_root = p_agent_node_root if p_agent_node_root else Node3D.new()
	parameters = p_parameters


## ===========================
## VERTEX ACCESS
## ===========================

## Get vertex position by index (for single vertex queries).
func get_vertex_position(index: int) -> Vector3:
	return _mesh.get_vertex(index)

## Get direct reference to vertex array for batch modifications.
## WARNING: Caller must call mark_mesh_dirty() after modifications.
## Use this for tight loops to avoid function call overhead.
func get_vertex_array() -> PackedVector3Array:
	return _mesh.vertices

## Mark mesh data as dirty (forces normal/tangent recalculation).
## Call this after modifying vertices via get_vertex_array().
func mark_mesh_dirty() -> void:
	_mesh.mark_dirty()


## ===========================
## SPATIAL QUERIES
## ===========================

## Get terrain size in world units.
func terrain_size() -> Vector2:
	return _terrain_data.terrain_size

## Convert world-space measure to grid-space units.
func scale_to_grid(measure: float) -> int:
	if terrain_size().x == 0.0:
		return 0
	return ceili(measure / terrain_size().x * float(_grid.width))

func scale_height(measure: float) -> int:
	var height_scale := parameters.height_scale if parameters else 1.0
	return ceili(measure / height_scale)

## Find nearest vertex to world position (XZ plane).
## Uses grid for O(1) approximation, then checks neighbors for accuracy.
func find_nearest_vertex(world_pos: Vector2) -> int:
	var nearest := _grid.get_nearest_grid_vertex(world_pos, terrain_size())
	if nearest < 0:
		return -1
	var candidates := PackedInt32Array([nearest])
	candidates.append_array(_grid.get_moore_neighbours(nearest))	
	var min_dist_sq := INF
	var best_index := -1
	for index in candidates:
		if not _mesh.is_valid_index(index):
			continue
		var vertex: Vector3 = _mesh.get_vertex(index)
		var vertex_2d := Vector2(vertex.x, vertex.z)
		var dist_sq := vertex_2d.distance_squared_to(world_pos)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			best_index = index
	return best_index

func get_nearest_grid_vertex_uv(uv: Vector2) -> int:
	return _grid.get_nearest_grid_vertex_uv(uv)

## Get neighbors within Chebyshev distance (square region).
func get_neighbours_chebyshev(vertex_index: int, distance: int) -> PackedInt32Array:
	return _grid.get_neighbours_chebyshev(vertex_index, distance)


## ===========================
## TOPOLOGY MODIFICATION
## ===========================
## For adding 3D features (caves, overhangs, tunnels) that require new geometry.
## New vertices are NOT part of the grid (non-grid vertices).

## Add a single vertex. Returns the new vertex index.
func add_vertex(position: Vector3, uv: Vector2 = Vector2.ZERO) -> int:
	return _mesh.add_vertex(position, uv)

## Add multiple vertices in batch. Returns the index of the first new vertex.
func add_vertices(positions: PackedVector3Array, vertex_uvs: PackedVector2Array) -> int:
	return _mesh.add_vertices(positions, vertex_uvs)

## Add a triangle using vertex indices.
func add_triangle(v0: int, v1: int, v2: int) -> void:
	_mesh.add_triangle(v0, v1, v2)

## Add multiple triangles in batch.
func add_triangles(triangle_indices: PackedInt32Array) -> void:
	_mesh.add_triangles(triangle_indices)

## Check if vertex is part of the surface grid (vs cave/overhang geometry).
func is_surface_vertex(index: int) -> bool:
	return _grid.is_grid_vertex(index)

## Remove triangles that pass the filter function.
## filter_func: Callable that takes (v0: Vector3, v1: Vector3, v2: Vector3) -> bool
## Returns true to REMOVE the triangle, false to keep it.
func remove_triangles_if(filter_func: Callable) -> int:
	return _mesh.remove_triangles_if(filter_func)

## ===========================
## GPU OPERATIONS
## ===========================

## Check if GPU operations are available (ProcessingContext may use CPU mode).
func use_gpu() -> bool:
	return processing_context.mesh_generator_use_gpu()

## Get RenderingDevice for GPU operations.
## Returns null if GPU not available (CPU fallback mode).
func get_rendering_device() -> RenderingDevice:
	return processing_context.get_rendering_device()

## Get or create a cached shader (reuses across agents).
## Returns invalid RID if GPU not available.
func get_or_create_shader(shader_path: String) -> RID:
	return processing_context.get_or_create_shader(shader_path)

## Get terrain size from processing context.
func get_terrain_size() -> float:
	return processing_context.terrain_size

## Get generation seed from processing context.
func get_generation_seed() -> int:
	return processing_context.generation_seed

## ===========================
## PIPELINE INTEGRATION
## ===========================

## Record agent execution statistics (called by pipeline stages).
func add_execution_stat(agent_name: String, elapsed_ms: float, success: bool, message: String = "") -> void:
	execution_stats.append(ExecutionStat.new(agent_name, success, elapsed_ms, message))

## Print execution summary (called by pipeline after completion).
func print_execution_summary() -> void:
	print("=== Pipeline Execution Summary ===")
	print("Total agents: %d" % execution_stats.size())
	print("Total time: %.2f ms" % _get_total_execution_time())
	print("\nAgent Details:")
	for stat in execution_stats:
		var status := "✓" if stat.success else "✗"
		print("  %s %s: %.2f ms - %s" % [
			status,
			stat.agent_name,
			stat.elapsed_ms,
			stat.message
		])

## Get mesh data reference (for agent validation).
func get_mesh_generation_result() -> MeshGenerationResult:
	return _mesh

## ===========================
## INTERNAL HELPERS
## ===========================

func _get_total_execution_time() -> float:
	var total := 0.0
	for stat in execution_stats:
		total += stat.elapsed_ms
	return total

## Get Moore neighbours (8-connected) - used internally by find_nearest_vertex.
func get_moore_neighbours(vertex_index: int) -> PackedInt32Array:
	return _grid.get_moore_neighbours(vertex_index)

## ===========================
## SLOPE DATA ACCESS
## ===========================

## Get the original heightmap used to generate this terrain.
func get_heightmap() -> Image:
	return _terrain_data.heightmap

## Get precomputed slope normal map (returns null if not computed).
func get_slope_normal_map() -> Image:
	return _mesh.get_slope_normal_map()

## Get slope data at specific vertex index.
func get_slope_at_vertex(vertex_index: int) -> SlopeData:
	return _mesh.get_slope_at_vertex(vertex_index)

## Get slope data at UV coordinate (0-1 range).
func get_slope_at_uv(uv: Vector2) -> SlopeData:
	return _mesh.get_slope_at_uv(uv)

## Get slope data at world position (XZ plane).
func get_slope_at_position(world_pos: Vector2) -> SlopeData:
	return _mesh.get_slope_at_world_position(world_pos)

## Sample random valid cliff positions using image-based filtering. 
func sample_cliff_positions(min_slope_angle: float, min_height: float, sample_count: int, seed_value: int = 0) -> Array[TunnelEntryPoint]:
	var results: Array[TunnelEntryPoint] = []
	var slope_map := get_slope_normal_map()
	var heightmap := get_heightmap()
	if not slope_map or not heightmap:
		push_error("MeshModifierContext: Missing slope map or heightmap for cliff sampling")
		return results
	var resized_images := ImageHelper.resize_images_to_largest([slope_map, heightmap])
	slope_map = resized_images[0]
	heightmap = resized_images[1]
	var mask := Image.create(slope_map.get_width(), slope_map.get_height(), false, Image.FORMAT_L8)
	var slope_mask := Image.create(slope_map.get_width(), slope_map.get_height(), false, Image.FORMAT_L8)
	var height_mask := Image.create(heightmap.get_width(), heightmap.get_height(), false, Image.FORMAT_L8)
	var min_angle_rad := deg_to_rad(min_slope_angle)
	var height_scale := parameters.height_scale if parameters else 1.0
	var valid_pixel_count := 0
	for y in range(mask.get_height()):
		for x in range(mask.get_width()):
			var slope_pixel := slope_map.get_pixel(x, y)
			var slope_angle := slope_pixel.a
			var height_pixel := heightmap.get_pixel(x, y)
			var world_height := height_pixel.r * height_scale
			if slope_angle >= min_angle_rad:
				slope_mask.set_pixel(x, y, Color.WHITE)
			else:
				slope_mask.set_pixel(x, y, Color.BLACK)
			if world_height >= min_height:
				height_mask.set_pixel(x, y, Color.WHITE)
			else:
				height_mask.set_pixel(x, y, Color.BLACK)
			if slope_angle >= min_angle_rad and world_height >= min_height:
				mask.set_pixel(x, y, Color.WHITE)
				valid_pixel_count += 1
			else:
				mask.set_pixel(x, y, Color.BLACK)
	if valid_pixel_count == 0:
		return results
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else get_generation_seed()
	var attempts := 0
	var max_attempts := sample_count * 10
	while results.size() < sample_count and attempts < max_attempts:
		attempts += 1
		var x := rng.randi_range(0, mask.get_width() - 1)
		var y := rng.randi_range(0, mask.get_height() - 1)
		if mask.get_pixel(x, y).r < 1:
			continue
		var uv := Vector2(float(x) / (mask.get_width() - 1), float(y) / (mask.get_height() - 1))
		var vertex_index := get_nearest_grid_vertex_uv(uv)
		var vertex_normal := _mesh.get_normal_at_vertex(vertex_index)
		var terrain_sz := terrain_size()
		var world_x := (uv.x - 0.5) * terrain_sz.x
		var world_z := (uv.y - 0.5) * terrain_sz.y
		var height_pixel := heightmap.get_pixel(x, y)
		var world_height := height_pixel.r * height_scale		
		var world_pos := Vector3(world_x, world_height, world_z)
		var slope_pixel := slope_map.get_pixel(x, y)
		var slope_angle := slope_pixel.a
		var entry_point := TunnelEntryPoint.new(world_pos, vertex_normal, slope_angle, uv, x, y)
		results.append(entry_point)
	
	return results
