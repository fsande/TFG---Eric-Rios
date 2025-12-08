## @brief Helper container used during tangent calculation for mesh vertices.
##
## Holds vertex/index/uv arrays and temporary tangent/bitangent accumulators
## used by CPU tangent-space computation.
class_name TangentCalculationData extends RefCounted

## Vertex positions for the mesh.
var vertices: PackedVector3Array
## Triangle indices.
var indices: PackedInt32Array
## Texture coordinates per-vertex.
var uvs: PackedVector2Array
## Accumulated normals per-vertex.
var normals: PackedVector3Array
## Temporary tangent accumulators.
var tan1: PackedVector3Array
## Temporary bitangent accumulators.
var tan2: PackedVector3Array

## Initialize with vertex, index and uv arrays and the expected vertex count.
func _init(v: PackedVector3Array, i: PackedInt32Array, u: PackedVector2Array, size: int):
	vertices = v
	indices = i
	uvs = u
	normals = PackedVector3Array()
	normals.resize(size)
	tan1 = PackedVector3Array()
	tan1.resize(size)
	tan2 = PackedVector3Array()
	tan2.resize(size)
