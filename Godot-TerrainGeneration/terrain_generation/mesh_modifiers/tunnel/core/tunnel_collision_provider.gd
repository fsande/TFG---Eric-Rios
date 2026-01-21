## Interface for tunnel collision shape generation.
@tool
class_name TunnelCollisionProvider extends RefCounted

func get_collision_shape() -> Shape3D:
	push_error("TunnelCollisionProvider.get_collision_shape() must be overridden")
	return null

func create_collision_from_mesh(mesh_data: MeshData) -> ConcavePolygonShape3D:
	if mesh_data.vertices.size() == 0:
		push_error("TunnelCollisionProvider: Empty mesh data, returning null shape")
		return null
	var shape := ConcavePolygonShape3D.new()
	var faces := PackedVector3Array()
	for i in range(0, mesh_data.indices.size(), 3):
		var i0 := mesh_data.indices[i]
		var i1 := mesh_data.indices[i + 1]
		var i2 := mesh_data.indices[i + 2]
		if i0 < mesh_data.vertices.size() and i1 < mesh_data.vertices.size() and i2 < mesh_data.vertices.size():
			faces.append(mesh_data.vertices[i0])
			faces.append(mesh_data.vertices[i1])
			faces.append(mesh_data.vertices[i2])
	shape.set_faces(faces)
	return shape

