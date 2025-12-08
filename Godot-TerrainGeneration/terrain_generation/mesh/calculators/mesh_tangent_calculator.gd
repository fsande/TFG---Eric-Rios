## @brief Strategy for calculating mesh tangents.
##
## @details Implements tangent calculation algorithms using normals, UVs, and vertex data.
## Separated from data storage following Strategy Pattern and SRP.
@tool
class_name MeshTangentCalculator extends RefCounted

## Calculate tangents from vertices, indices, UVs, and normals.
## Returns a PackedVector4Array with one tangent per vertex (xyz = tangent, w = handedness).
static func calculate_tangents(mesh_data: MeshData, normals: PackedVector3Array) -> PackedVector4Array:
	var tangents := PackedVector4Array()
	tangents.resize(mesh_data.vertices.size())
	
	# Temporary tangent/bitangent accumulators
	var tan1 := PackedVector3Array()
	var tan2 := PackedVector3Array()
	tan1.resize(mesh_data.vertices.size())
	tan2.resize(mesh_data.vertices.size())
	
	for i in range(mesh_data.vertices.size()):
		tan1[i] = Vector3.ZERO
		tan2[i] = Vector3.ZERO
	
	# Accumulate tangent and bitangent for each triangle
	for i in range(0, mesh_data.indices.size(), 3):
		var i0 := mesh_data.indices[i]
		var i1 := mesh_data.indices[i + 1]
		var i2 := mesh_data.indices[i + 2]
		
		var v0 := mesh_data.vertices[i0]
		var v1 := mesh_data.vertices[i1]
		var v2 := mesh_data.vertices[i2]
		
		var uv0 := mesh_data.uvs[i0]
		var uv1 := mesh_data.uvs[i1]
		var uv2 := mesh_data.uvs[i2]
		
		var edge1 := v1 - v0
		var edge2 := v2 - v0
		var delta_uv1 := uv1 - uv0
		var delta_uv2 := uv2 - uv0
		
		var f := 1.0
		var denom := (delta_uv1.x * delta_uv2.y - delta_uv2.x * delta_uv1.y)
		if denom != 0.0:
			f = 1.0 / denom
		
		var tangent := Vector3(
			f * (delta_uv2.y * edge1.x - delta_uv1.y * edge2.x),
			f * (delta_uv2.y * edge1.y - delta_uv1.y * edge2.y),
			f * (delta_uv2.y * edge1.z - delta_uv1.y * edge2.z)
		).normalized()
		
		var bitangent := Vector3(
			f * (-delta_uv2.x * edge1.x + delta_uv1.x * edge2.x),
			f * (-delta_uv2.x * edge1.y + delta_uv1.x * edge2.y),
			f * (-delta_uv2.x * edge1.z + delta_uv1.x * edge2.z)
		).normalized()
		
		tan1[i0] += tangent
		tan1[i1] += tangent
		tan1[i2] += tangent
		
		tan2[i0] += bitangent
		tan2[i1] += bitangent
		tan2[i2] += bitangent
	
	# Orthogonalize and calculate handedness
	for i in range(mesh_data.vertices.size()):
		var n := normals[i]
		var t := tan1[i]
		
		# Gram-Schmidt orthogonalize
		t = (t - n * n.dot(t)).normalized()
		
		# Calculate handedness
		var handedness := 1.0 if n.cross(t).dot(tan2[i]) > 0.0 else -1.0
		
		tangents[i] = Vector4(t.x, t.y, t.z, handedness)
	
	return tangents

## Calculate tangents using cached normals and cache the result in mesh data.
static func calculate_and_cache(mesh_data: MeshData) -> void:
	# Ensure normals are calculated first
	if mesh_data.cached_normals.is_empty():
		MeshNormalCalculator.calculate_and_cache(mesh_data)
	
	mesh_data.cached_tangents = calculate_tangents(mesh_data, mesh_data.cached_normals)

