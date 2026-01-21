## Interface for tunnel interior mesh generation.
@tool
class_name TunnelInteriorProvider extends RefCounted

func generate_interior_mesh(terrain_query: Callable) -> MeshData:
	push_error("TunnelInteriorProvider.generate_interior_mesh() must be overridden")
	return MeshData.new()

func get_detail_level() -> int:
	return -1

