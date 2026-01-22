## @brief Clips tunnel interior mesh to terrain surface.
##
## @details Ensures tunnel interior geometry only exists underground:
## - Classifies triangles relative to terrain surface
## - Clips intersecting triangles at terrain boundary
## - Preserves UV coordinates through interpolation
## - Handles partial triangle clipping with proper topology
##
## Design Pattern: Template Method - Defines clipping algorithm with extension points.
## SOLID: Single Responsibility - Only concerned with geometric clipping operations.
@tool
class_name TunnelInteriorClipper extends RefCounted

## Classification of triangle relative to terrain
enum TriangleClass {
	FULLY_UNDERGROUND,  ## All vertices below terrain surface
	FULLY_ABOVE,        ## All vertices above terrain surface
	INTERSECTING        ## Some vertices above, some below (needs clipping)
}

## Number of vertices in a triangle
const TRIANGLE_VERTEX_COUNT: int = 3

## Vertices per triangle (3 corners)
const VERTICES_PER_TRIANGLE: int = 3

## Minimum polygon vertex count for triangulation
const MINIMUM_TRIANGULATION_VERTICES: int = 3

## Edge index offset for next vertex in triangle
const NEXT_VERTEX_OFFSET: int = 1

## Base index for first vertex in triangle
const FIRST_TRIANGLE_VERTEX: int = 0

## Index offset for second vertex in triangle indices
const SECOND_TRIANGLE_VERTEX: int = 1

## Index offset for third vertex in triangle indices
const THIRD_TRIANGLE_VERTEX: int = 2

## Epsilon for parallel edge detection (denominator near zero)
const PARALLEL_EDGE_EPSILON: float = 0.0001

## Interpolation parameter for midpoint when edges are parallel
const MIDPOINT_INTERPOLATION: float = 0.5

## Minimum clamp value for intersection parameter
const INTERSECTION_T_MIN: float = 0.0

## Maximum clamp value for intersection parameter
const INTERSECTION_T_MAX: float = 1.0

## Tolerance for edge-terrain intersection calculations (in world units)
var edge_intersection_tolerance: float = 0.01

## Quality setting for interpolation (higher = more accurate but slower)
var interpolation_quality: int = 1

## Statistics tracking
var _stats := {
	"triangles_processed": 0,
	"triangles_kept": 0,
	"triangles_discarded": 0,
	"triangles_clipped": 0,
	"vertices_added_by_clipping": 0
}

func _init() -> void:
	_reset_statistics()

## Clip mesh to terrain surface, removing all above-ground geometry.
##
## @param mesh_data MeshData to clip
## @param terrain_querier TerrainHeightQuerier for terrain height lookups
## @return MeshData containing only underground geometry
func clip_to_terrain(mesh_data: MeshData, terrain_querier: TerrainHeightQuerier) -> MeshData:
	_reset_statistics()
	if mesh_data.get_triangle_count() == 0:
		return mesh_data
	var clipped := MeshData.new()
	clipped.mesh_size = mesh_data.mesh_size
	clipped.width = mesh_data.width
	clipped.height = mesh_data.height
	for tri_idx in range(0, mesh_data.indices.size(), VERTICES_PER_TRIANGLE):
		_stats["triangles_processed"] += 1
		var i0 := mesh_data.indices[tri_idx]
		var i1 := mesh_data.indices[tri_idx + SECOND_TRIANGLE_VERTEX]
		var i2 := mesh_data.indices[tri_idx + THIRD_TRIANGLE_VERTEX]
		var v0 := mesh_data.vertices[i0]
		var v1 := mesh_data.vertices[i1]
		var v2 := mesh_data.vertices[i2]
		var uv0 := mesh_data.uvs[i0]
		var uv1 := mesh_data.uvs[i1]
		var uv2 := mesh_data.uvs[i2]
		var h0: float = terrain_querier.get_height_at(Vector2(v0.x, v0.z))
		var h1: float = terrain_querier.get_height_at(Vector2(v1.x, v1.z))
		var h2: float = terrain_querier.get_height_at(Vector2(v2.x, v2.z))
		var classification := _classify_triangle_vs_terrain(
			[v0, v1, v2],
			[h0, h1, h2]
		)
		match classification:
			TriangleClass.FULLY_UNDERGROUND:
				_add_triangle(clipped, v0, v1, v2, uv0, uv1, uv2)
				_stats["triangles_kept"] += 1
			TriangleClass.FULLY_ABOVE:
				_stats["triangles_discarded"] += 1
			TriangleClass.INTERSECTING:
				_clip_and_add_intersecting_triangle(
					clipped,
					[v0, v1, v2],
					[uv0, uv1, uv2],
					[h0, h1, h2]
				)
				_stats["triangles_clipped"] += 1
	return clipped

## Classify triangle relative to terrain surface.
##
## @param vertices Array of 3 Vector3 positions
## @param terrain_heights Array of 3 float terrain heights at vertex XZ positions
## @return TriangleClass classification
func _classify_triangle_vs_terrain(vertices: Array, terrain_heights: Array) -> TriangleClass:
	var underground_count := 0
	for i in range(TRIANGLE_VERTEX_COUNT):
		if vertices[i].y < terrain_heights[i] + edge_intersection_tolerance:
			underground_count += 1
	if underground_count == TRIANGLE_VERTEX_COUNT:
		return TriangleClass.FULLY_UNDERGROUND
	elif underground_count == 0:
		return TriangleClass.FULLY_ABOVE
	else:
		return TriangleClass.INTERSECTING

## Add a complete triangle to the mesh.
##
## @param mesh MeshData to add to
## @param v0, v1, v2 Vertex positions
## @param uv0, uv1, uv2 UV coordinates
func _add_triangle(mesh: MeshData, v0: Vector3, v1: Vector3, v2: Vector3, 
					uv0: Vector2, uv1: Vector2, uv2: Vector2) -> void:
	var base_idx := mesh.vertices.size()
	mesh.vertices.append(v0)
	mesh.vertices.append(v1)
	mesh.vertices.append(v2)
	mesh.uvs.append(uv0)
	mesh.uvs.append(uv1)
	mesh.uvs.append(uv2)
	mesh.indices.append(base_idx)
	mesh.indices.append(base_idx + SECOND_TRIANGLE_VERTEX)
	mesh.indices.append(base_idx + THIRD_TRIANGLE_VERTEX)

## Clip and add a triangle that intersects the terrain surface.
##
## @details Uses Sutherland-Hodgman-like clipping to create triangulated polygon.
## Handles cases where 1 or 2 vertices are above ground.
##
## @param mesh MeshData to add clipped geometry to
## @param vertices Array of 3 Vector3 positions
## @param uvs Array of 3 Vector2 UV coordinates
## @param terrain_heights Array of 3 float terrain heights
func _clip_and_add_intersecting_triangle(mesh: MeshData, vertices: Array, 
										uvs: Array, terrain_heights: Array) -> void:
	var clipped_vertices: Array[Vector3] = []
	var clipped_uvs: Array[Vector2] = []
	for i in range(TRIANGLE_VERTEX_COUNT):
		var current: Vector3 = vertices[i]
		var next: Vector3 = vertices[(i + NEXT_VERTEX_OFFSET) % TRIANGLE_VERTEX_COUNT]
		var curr_uv: Vector2 = uvs[i]
		var next_uv: Vector2 = uvs[(i + NEXT_VERTEX_OFFSET) % TRIANGLE_VERTEX_COUNT]
		var curr_height: float = terrain_heights[i]
		var next_height: float = terrain_heights[(i + NEXT_VERTEX_OFFSET) % TRIANGLE_VERTEX_COUNT]
		var curr_underground := current.y < curr_height
		var next_underground := next.y < next_height
		if curr_underground:
			clipped_vertices.append(current)
			clipped_uvs.append(curr_uv)
		if curr_underground != next_underground:
			var intersection_data := _compute_edge_terrain_intersection(
				current, next, curr_uv, next_uv, curr_height, next_height
			)
			clipped_vertices.append(intersection_data[0])
			clipped_uvs.append(intersection_data[1])
			_stats["vertices_added_by_clipping"] += 1
	if clipped_vertices.size() >= MINIMUM_TRIANGULATION_VERTICES:
		for i in range(NEXT_VERTEX_OFFSET, clipped_vertices.size() - NEXT_VERTEX_OFFSET):
			_add_triangle(
				mesh,
				clipped_vertices[FIRST_TRIANGLE_VERTEX],
				clipped_vertices[i],
				clipped_vertices[i + NEXT_VERTEX_OFFSET],
				clipped_uvs[FIRST_TRIANGLE_VERTEX],
				clipped_uvs[i],
				clipped_uvs[i + NEXT_VERTEX_OFFSET]
			)

## Compute intersection point where edge crosses terrain surface.
##
## @details Uses linear interpolation to find where edge intersects terrain height.
## Interpolates both position and UV coordinates.
##
## @param v0, v1 Edge endpoints
## @param uv0, uv1 UV coordinates at endpoints
## @param h0, h1 Terrain heights at endpoint XZ positions
## @return Array [Vector3 intersection_pos, Vector2 intersection_uv]
func _compute_edge_terrain_intersection(v0: Vector3, v1: Vector3, 
	uv0: Vector2, uv1: Vector2,
	h0: float, h1: float) -> Array:
	var v_delta := v1.y - v0.y
	var h_delta := h1 - h0
	var denominator := v_delta - h_delta
	if abs(denominator) < PARALLEL_EDGE_EPSILON:
		var t := MIDPOINT_INTERPOLATION
		var intersection_pos := v0.lerp(v1, t)
		var terrain_height_at_midpoint := (h0 + h1) * MIDPOINT_INTERPOLATION
		intersection_pos.y = terrain_height_at_midpoint
		var intersection_uv := uv0.lerp(uv1, t)
		return [intersection_pos, intersection_uv]
	var t := (h0 - v0.y) / denominator
	t = clamp(t, INTERSECTION_T_MIN, INTERSECTION_T_MAX)
	var intersection_pos := v0.lerp(v1, t)
	var terrain_height_at_intersection := h0 + t * h_delta
	intersection_pos.y = terrain_height_at_intersection
	var intersection_uv := uv0.lerp(uv1, t)
	return [intersection_pos, intersection_uv]

## Reset statistics tracking.
func _reset_statistics() -> void:
	_stats = {
		"triangles_processed": 0,
		"triangles_kept": 0,
		"triangles_discarded": 0,
		"triangles_clipped": 0,
		"vertices_added_by_clipping": 0
	}

## Get clipping statistics from last operation.
##
## @return Dictionary with clipping metrics
func get_statistics() -> Dictionary:
	return _stats.duplicate()

## Get summary string of clipping operation.
##
## @return String describing clipping results
func get_summary_string() -> String:
	return "Clipped: %d kept, %d discarded, %d modified (%d vertices added)" % [
		_stats["triangles_kept"],
		_stats["triangles_discarded"],
		_stats["triangles_clipped"],
		_stats["vertices_added_by_clipping"]
	]