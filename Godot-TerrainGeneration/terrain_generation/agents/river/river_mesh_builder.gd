## @brief Builds a ribbon mesh along a river path.
##
## @details Follows SRP — only responsible for constructing the river water
## surface mesh from a downstream path.
##
## The mesh is a triangle-strip ribbon extruded perpendicular to the flow
## direction at each path point. Per-vertex flow direction (path tangent)
## is encoded in the COLOR attribute so the shader can scroll normal maps
## along the local flow direction.
##
## Cross-section geometry:
## - All vertices in a section share the same base water level (flat water plane).
## - Edge vertices are placed at the true bank edge found via binary search.
## - A curvature-derived banking tilt raises the inner bank and lowers the outer.
## - All vertices are clamped above the carved terrain to prevent z-fighting.
class_name RiverMeshBuilder extends RefCounted

const MIN_TOTAL_LENGTH: float = 0.001
const EDGE_VERTEX_COUNT: int = 2
const TRIANGLES_PER_QUAD: int = 2
const INDICES_PER_TRIANGLE: int = 3

## Build an ArrayMesh from a downstream path using TerrainDefinition for sampling.
##
## @param downstream_path	   Ordered Array[Vector2] from mountain to coast.
## @param terrain_def		   TerrainDefinition for height sampling.
## @param river_width		   Base river width in world units.
## @param width_multiplier	  Width multiplier at the downstream end (coast).
## @param water_offset		  Height offset above the carved riverbed.
## @param edge_falloff_distance Max extra distance beyond river_width to search for bank.
## @param bank_strength		 Curvature multiplier for cross-slope banking.
## @param max_bank_degrees	  Maximum banking angle in degrees.
## @param cross_subdivisions	Number of extra vertices across the width.
## @param resample_spacing	  If > 0, resample path to this spacing first.
## @return ArrayMesh ready to assign to a MeshInstance3D, or null on failure.
static func build_from_definition(
	downstream_path: Array[Vector2],
	terrain_def: TerrainDefinition,
	river_width: float,
	width_multiplier: float,
	water_offset: float,
	edge_falloff_distance: float,
	bank_strength: float,
	max_bank_degrees: float,
	cross_subdivisions: int = 0,
	resample_spacing: float = 0.0
) -> ArrayMesh:
	var height_sampler := func(world_2d: Vector2) -> float:
		return terrain_def.sample_height_at(world_2d)
	var surface_arrays := _build_ribbon_surface(
		downstream_path, height_sampler,
		river_width, width_multiplier, water_offset,
		edge_falloff_distance, bank_strength, max_bank_degrees,
		cross_subdivisions, resample_spacing
	)
	if surface_arrays.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
	return mesh

## Build the raw surface arrays for a ribbon mesh along a path.
static func _build_ribbon_surface(
	downstream_path: Array[Vector2],
	height_sampler: Callable,
	river_width: float,
	width_multiplier: float,
	water_offset: float,
	edge_falloff_distance: float,
	bank_strength: float,
	max_bank_degrees: float,
	cross_subdivisions: int,
	resample_spacing: float
) -> Array:
	if downstream_path.size() < 2:
		push_error("RiverMeshBuilder: Path must have at least 2 points")
		return []
	var path := downstream_path
	if resample_spacing > 0.0:
		path = RiverPathResampler.resample(downstream_path, resample_spacing)
	if path.size() < 2:
		push_error("RiverMeshBuilder: Resampled path has fewer than 2 points")
		return []
	var point_count := path.size()
	var verts_per_section: int = EDGE_VERTEX_COUNT + cross_subdivisions
	var total_verts := point_count * verts_per_section
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	vertices.resize(total_verts)
	normals.resize(total_verts)
	uvs.resize(total_verts)
	colors.resize(total_verts)
	var cumulative_lengths := _compute_cumulative_lengths(path)
	var centre_levels := PackedFloat32Array()
	centre_levels.resize(point_count)
	for i in range(point_count):
		centre_levels[i] = height_sampler.call(path[i]) + water_offset
	centre_levels[0] = minf(minf(centre_levels[0], centre_levels[1]), centre_levels[2])
	centre_levels[1] = minf(minf(centre_levels[1], centre_levels[0]), centre_levels[2])
	for i in range(2, point_count):
		centre_levels[i] = minf(minf(centre_levels[i], centre_levels[i - 1]), centre_levels[i - 2])
	var max_bank_rad := deg_to_rad(max_bank_degrees)
	for i in range(point_count):
		var downstream_fraction := float(i) / float(point_count - 1)
		var flow_dir := _compute_flow_direction(path, i)
		var perpendicular := Vector2(-flow_dir.y, flow_dir.x)
		var local_half_width := river_width * lerpf(1.0, width_multiplier, downstream_fraction) * 0.5
		var max_search := local_half_width + edge_falloff_distance
		var water_level := centre_levels[i]
		var left_edge := _find_bank_edge(path[i], -perpendicular, water_level, max_search, height_sampler)
		var right_edge := _find_bank_edge(path[i], perpendicular, water_level, max_search, height_sampler)
		var curvature := _compute_curvature(path, i)
		var bank_tilt := clampf(curvature * bank_strength, -max_bank_rad, max_bank_rad)
		var tan_tilt := tan(bank_tilt)
		var encoded_flow := _encode_direction_as_color(flow_dir)
		var uv_v := cumulative_lengths[i] / maxf(local_half_width * 2.0, 0.001)
		for s in range(verts_per_section):
			var cross_fraction := float(s) / float(verts_per_section - 1)
			var lateral_signed: float
			if cross_fraction <= 0.5:
				lateral_signed = lerpf(-left_edge, 0.0, cross_fraction * 2.0)
			else:
				lateral_signed = lerpf(0.0, right_edge, (cross_fraction - 0.5) * 2.0)
			var world_pos_2d := path[i] + perpendicular * lateral_signed
			var banked_height := water_level + lateral_signed * tan_tilt
			var terrain_h: float = height_sampler.call(world_pos_2d)
			var vertex_height := maxf(banked_height, terrain_h - 0.75)
			var vert_idx := i * verts_per_section + s
			vertices[vert_idx] = Vector3(world_pos_2d.x, vertex_height, world_pos_2d.y)
			normals[vert_idx] = Vector3.UP
			uvs[vert_idx] = Vector2(cross_fraction, uv_v)
			colors[vert_idx] = encoded_flow
	var indices := _build_triangle_indices(point_count, verts_per_section)
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = vertices
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_TEX_UV] = uvs
	surface[Mesh.ARRAY_COLOR] = colors
	surface[Mesh.ARRAY_INDEX] = indices
	return surface

## Binary search for the distance along `direction` from `path_pos` at which
## terrain height exceeds `water_level`. Returns max_search if the entire
## search range is below water (e.g. flooding into flat ocean).
static func _find_bank_edge(
	path_pos: Vector2,
	direction: Vector2,
	water_level: float,
	max_search: float,
	height_sampler: Callable
) -> float:
	if height_sampler.call(path_pos + direction * max_search) < water_level:
		return max_search
	var low := 0.0
	var high := max_search
	for _i in range(12):
		var mid := (low + high) * 0.5
		if height_sampler.call(path_pos + direction * mid) < water_level:
			low = mid
		else:
			high = mid
	return low

## Signed curvature at point i from the 2D cross product of consecutive tangents.
## Positive = left turn (inner bank on left), negative = right turn.
static func _compute_curvature(path: Array[Vector2], i: int) -> float:
	if i == 0 or i == path.size() - 1:
		return 0.0
	var t0 := (path[i] - path[i - 1]).normalized()
	var t1 := (path[i + 1] - path[i]).normalized()
	return t0.x * t1.y - t0.y * t1.x

## Compute cumulative arc-lengths along the path.
static func _compute_cumulative_lengths(path: Array[Vector2]) -> PackedFloat32Array:
	var lengths := PackedFloat32Array()
	lengths.resize(path.size())
	lengths[0] = 0.0
	for i in range(1, path.size()):
		lengths[i] = lengths[i - 1] + path[i].distance_to(path[i - 1])
	return lengths

## Compute the flow (tangent) direction at path point i.
## Uses central differencing for interior points, forward/backward for endpoints.
static func _compute_flow_direction(path: Array[Vector2], i: int) -> Vector2:
	var point_count := path.size()
	if i == 0:
		return (path[1] - path[0]).normalized()
	elif i == point_count - 1:
		return (path[i] - path[i - 1]).normalized()
	else:
		return (path[i + 1] - path[i - 1]).normalized()

## Encode a normalised 2D direction into a Color for vertex attribute storage.
## Decode in shader: direction = vec2(COLOR.r * 2.0 - 1.0, COLOR.g * 2.0 - 1.0)
static func _encode_direction_as_color(direction: Vector2) -> Color:
	return Color(
		direction.x * 0.5 + 0.5,
		direction.y * 0.5 + 0.5,
		0.0,
		1.0
	)

## Build the triangle index buffer for a ribbon.
static func _build_triangle_indices(point_count: int, verts_per_section: int) -> PackedInt32Array:
	var quads_along_path := point_count - 1
	var quads_across_section := verts_per_section - 1
	var total_indices := quads_along_path * quads_across_section * TRIANGLES_PER_QUAD * INDICES_PER_TRIANGLE
	var indices := PackedInt32Array()
	indices.resize(total_indices)
	var write_pos := 0
	for i in range(quads_along_path):
		for s in range(quads_across_section):
			var top_left := i * verts_per_section + s
			var top_right := top_left + 1
			var bottom_left := top_left + verts_per_section
			var bottom_right := bottom_left + 1
			indices[write_pos] = top_left;	  write_pos += 1
			indices[write_pos] = bottom_left;   write_pos += 1
			indices[write_pos] = top_right;	 write_pos += 1
			indices[write_pos] = top_right;	 write_pos += 1
			indices[write_pos] = bottom_left;   write_pos += 1
			indices[write_pos] = bottom_right;  write_pos += 1
	return indices

## Compute an AABB from a packed vertex array.
static func _compute_bounds_from_vertices(vertices: PackedVector3Array) -> AABB:
	if vertices.is_empty():
		return AABB()
	var min_pos := vertices[0]
	var max_pos := vertices[0]
	for v in vertices:
		min_pos = Vector3(minf(min_pos.x, v.x), minf(min_pos.y, v.y), minf(min_pos.z, v.z))
		max_pos = Vector3(maxf(max_pos.x, v.x), maxf(max_pos.y, v.y), maxf(max_pos.z, v.z))
	return AABB(min_pos, max_pos - min_pos)

## Calculate the downhill direction at a world position using TerrainDefinition.
static func _calculate_downhill_from_definition(
	world_pos: Vector2,
	terrain_def: TerrainDefinition,
	epsilon: float
) -> Vector2:
	var h_center := terrain_def.sample_height_at(world_pos)
	var h_right := terrain_def.sample_height_at(world_pos + Vector2(epsilon, 0))
	var h_forward := terrain_def.sample_height_at(world_pos + Vector2(0, epsilon))
	var grad := Vector2(h_right - h_center, h_forward - h_center) / epsilon
	if grad.length_squared() < 0.0001:
		return Vector2.ZERO
	return -grad.normalized()
