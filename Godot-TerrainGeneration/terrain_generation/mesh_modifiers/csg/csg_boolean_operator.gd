## @brief Performs CSG boolean operations on meshes.
##
## @details Implements mesh-volume boolean subtraction using triangle classification
## and clipping. This is a minimal viable CSG implementation focused on subtraction.
@tool
class_name CSGBooleanOperator extends RefCounted

## Classification result for a triangle
enum TriangleClass {
	FULLY_OUTSIDE,   ## All vertices outside volume
	FULLY_INSIDE,    ## All vertices inside volume
	INTERSECTING     ## Mixed - some vertices in, some out
}

## Subtract a volume from mesh data, returning modified mesh
func subtract_volume_from_mesh(mesh_data: MeshData, volume: CSGVolume) -> MeshData:
	var result := MeshData.new()
	result.width = mesh_data.width
	result.height = mesh_data.height
	result.mesh_size = mesh_data.mesh_size
	var vertices := mesh_data.vertices
	var indices := mesh_data.indices
	var uvs := mesh_data.uvs
	var vertex_classifications := PackedByteArray()
	vertex_classifications.resize(vertices.size())
	for i in range(vertices.size()):
		var classification := volume.classify_point(vertices[i])
		vertex_classifications[i] = classification
	for tri_idx in range(0, indices.size(), 3):
		var i0 := indices[tri_idx]
		var i1 := indices[tri_idx + 1]
		var i2 := indices[tri_idx + 2]
		var c0 := vertex_classifications[i0]
		var c1 := vertex_classifications[i1]
		var c2 := vertex_classifications[i2]
		var tri_class := _classify_triangle(c0, c1, c2)
		match tri_class:
			TriangleClass.FULLY_OUTSIDE:
				_add_triangle(result, vertices[i0], vertices[i1], vertices[i2], 
							 uvs[i0], uvs[i1], uvs[i2])
			TriangleClass.FULLY_INSIDE:
				pass
			TriangleClass.INTERSECTING:
				_clip_and_add_triangle(result, 
									  vertices[i0], vertices[i1], vertices[i2],
									  uvs[i0], uvs[i1], uvs[i2],
									  c0, c1, c2, volume)
	return result

## Classify a triangle based on its vertex classifications
func _classify_triangle(c0: int, c1: int, c2: int) -> TriangleClass:
	var inside_count := 0
	var outside_count := 0
	for c in [c0, c1, c2]:
		if c == CSGVolume.Classification.INSIDE:
			inside_count += 1
		elif c == CSGVolume.Classification.OUTSIDE:
			outside_count += 1	
	if inside_count == 3:
		return TriangleClass.FULLY_INSIDE
	elif outside_count == 3:
		return TriangleClass.FULLY_OUTSIDE
	else:
		return TriangleClass.INTERSECTING

## Add a triangle to result mesh
func _add_triangle(result: MeshData, v0: Vector3, v1: Vector3, v2: Vector3, 
				  uv0: Vector2, uv1: Vector2, uv2: Vector2) -> void:
	var base_idx := result.vertices.size()
	result.vertices.append(v0)
	result.vertices.append(v1)
	result.vertices.append(v2)
	result.uvs.append(uv0)
	result.uvs.append(uv1)
	result.uvs.append(uv2)
	result.indices.append(base_idx)
	result.indices.append(base_idx + 1)
	result.indices.append(base_idx + 2)

## Clip intersecting triangle and add outside parts
func _clip_and_add_triangle(result: MeshData,
						   v0: Vector3, v1: Vector3, v2: Vector3,
						   uv0: Vector2, uv1: Vector2, uv2: Vector2,
						   c0: int, c1: int, c2: int, volume: CSGVolume) -> void:
	var verts: Array[Vector3]= [v0, v1, v2]
	var classes: Array[int] = [c0, c1, c2]
	var vertex_uvs: Array[Vector2] = [uv0, uv1, uv2]
	var clipped_verts: Array[Vector3] = []
	var clipped_uvs: Array[Vector2] = []
	for i in range(3):
		var j := (i + 1) % 3
		var vi := verts[i]
		var vj := verts[j]
		var ci := classes[i]
		var cj := classes[j]
		var uvi := vertex_uvs[i]
		var uvj := vertex_uvs[j]
		if ci != CSGVolume.Classification.INSIDE:
			clipped_verts.append(vi)
			clipped_uvs.append(uvi)
		if (ci == CSGVolume.Classification.INSIDE and cj != CSGVolume.Classification.INSIDE) or \
		   (ci != CSGVolume.Classification.INSIDE and cj == CSGVolume.Classification.INSIDE):
			var t := volume.intersect_segment(vi, vj)
			if t >= 0.0:
				var intersection := vi.lerp(vj, t)
				var intersection_uv := uvi.lerp(uvj, t)
				clipped_verts.append(intersection)
				clipped_uvs.append(intersection_uv)
	if clipped_verts.size() >= 3:
		for i in range(1, clipped_verts.size() - 1):
			_add_triangle(result,
						 clipped_verts[0], clipped_verts[i], clipped_verts[i + 1],
						 clipped_uvs[0], clipped_uvs[i], clipped_uvs[i + 1])
