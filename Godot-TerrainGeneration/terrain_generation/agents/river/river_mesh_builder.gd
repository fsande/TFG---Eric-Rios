## @brief Builds a ribbon mesh along a river path.
##
## @details Follows SRP — only responsible for constructing the river water
## surface mesh from a downstream path and a terrain generation context.
##
## The mesh is a triangle-strip ribbon extruded perpendicular to the flow
## direction at each path point. Per-vertex flow direction (terrain gradient)
## is encoded in the COLOR attribute so the shader can scroll normal maps
## along the local downhill direction.
class_name RiverMeshBuilder extends RefCounted

## Build a RiverVisualData from a downstream path (mountain → coast).
##
## @param downstream_path  Ordered Array[Vector2] from mountain to coast.
## @param context           TerrainGenerationContext for height / gradient sampling.
## @param river_width       Base river width in world units.
## @param width_multiplier  Width multiplier at the downstream end (coast).
## @param water_offset      Height offset above the carved riverbed.
## @param cross_subdivisions Number of extra vertices across the width
##                           (0 = only left+right, 1 = left+center+right, …).
## @param resample_spacing  If > 0, resample the path to this spacing first.
## @return RiverVisualData   Ready-to-present visual data, or null on failure.
static func build(
	downstream_path: Array[Vector2],
	context: TerrainGenerationContext,
	river_width: float,
	width_multiplier: float,
	water_offset: float,
	cross_subdivisions: int = 0,
	resample_spacing: float = 0.0
) -> RiverVisualData:
	if downstream_path.size() < 2:
		push_error("RiverMeshBuilder: Path must have at least 2 points")
		return null
	var path := downstream_path
	if resample_spacing > 0.0:
		path = RiverPathResampler.resample(downstream_path, resample_spacing)
	if path.size() < 2:
		push_error("RiverMeshBuilder: Resampled path has fewer than 2 points")
		return null
	var point_count := path.size()
	var verts_per_section: int = 2 + cross_subdivisions
	var total_verts := point_count * verts_per_section
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(total_verts)
	normals.resize(total_verts)
	uvs.resize(total_verts)
	colors.resize(total_verts)
	var cumulative_lengths := PackedFloat32Array()
	cumulative_lengths.resize(point_count)
	cumulative_lengths[0] = 0.0
	for i in range(1, point_count):
		cumulative_lengths[i] = cumulative_lengths[i - 1] + path[i].distance_to(path[i - 1])
	var total_length: float = cumulative_lengths[point_count - 1]
	if total_length < 0.001:
		total_length = 1.0
	var min_pos := Vector3(INF, INF, INF)
	var max_pos := Vector3(-INF, -INF, -INF)
	for i in range(point_count):
		var t := float(i) / float(point_count - 1)
		var uv_v: float = cumulative_lengths[i] / total_length
		var flow_dir: Vector2
		if i == 0:
			flow_dir = (path[1] - path[0]).normalized()
		elif i == point_count - 1:
			flow_dir = (path[i] - path[i - 1]).normalized()
		else:
			flow_dir = (path[i + 1] - path[i - 1]).normalized()
		var perp := Vector2(-flow_dir.y, flow_dir.x)
		var half_w: float = (river_width * lerpf(1.0, width_multiplier, t)) / 2.0
		var gradient: Vector2 = context.calculate_downhill_direction(path[i])
		if gradient.length_squared() < 0.0001:
			gradient = flow_dir
		else:
			gradient = gradient.normalized()
		var encoded_color := Color(
			gradient.x * 0.5 + 0.5,
			gradient.y * 0.5 + 0.5,
			0.0,
			1.0
		)
		for s in range(verts_per_section):
			var frac: float = float(s) / float(verts_per_section - 1)
			var offset_2d: Vector2 = perp * lerpf(-half_w, half_w, frac)
			var world_2d: Vector2 = path[i] + offset_2d
			var height: float = context.get_scaled_height_at(world_2d) + water_offset
			var idx := i * verts_per_section + s
			var vertex := Vector3(world_2d.x, height, world_2d.y)
			vertices[idx] = vertex
			normals[idx] = Vector3.UP 
			uvs[idx] = Vector2(frac, uv_v)
			colors[idx] = encoded_color
			min_pos = Vector3(minf(min_pos.x, vertex.x), minf(min_pos.y, vertex.y), minf(min_pos.z, vertex.z))
			max_pos = Vector3(maxf(max_pos.x, vertex.x), maxf(max_pos.y, vertex.y), maxf(max_pos.z, vertex.z))
	var quad_count := (point_count - 1) * (verts_per_section - 1)
	indices.resize(quad_count * 6)
	var idx_write := 0
	for i in range(point_count - 1):
		for s in range(verts_per_section - 1):
			var v0 := i * verts_per_section + s
			var v1 := v0 + 1
			var v2 := v0 + verts_per_section
			var v3 := v2 + 1
			indices[idx_write] = v0;     idx_write += 1
			indices[idx_write] = v2;     idx_write += 1
			indices[idx_write] = v1;     idx_write += 1
			# Triangle 2
			indices[idx_write] = v1;     idx_write += 1
			indices[idx_write] = v2;     idx_write += 1
			indices[idx_write] = v3;     idx_write += 1
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = vertices
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_TEX_UV] = uvs
	surface[Mesh.ARRAY_COLOR] = colors
	surface[Mesh.ARRAY_INDEX] = indices
	var data := RiverVisualData.new()
	data.surface_arrays = surface
	data.downstream_path = path
	data.bounds = AABB(min_pos, max_pos - min_pos)
	return data
