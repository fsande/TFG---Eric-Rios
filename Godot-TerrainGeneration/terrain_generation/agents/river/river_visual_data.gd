## @brief Data container for river visual information.
##
## @details Stores all data needed to present a river's water surface:
## the ribbon mesh geometry, the original path, and an optional material override.
## Follows SRP — only holds data, no scene-tree logic.
@tool
class_name RiverVisualData extends Resource

## The river ribbon mesh arrays, ready to be built into an ArrayMesh.
## Uses Godot surface-array layout (Mesh.ARRAY_MAX sized array).
var surface_arrays: Array = []

## The downstream river path (mountain → coast) in world-space XZ.
var downstream_path: Array[Vector2] = []

## World-space bounding box enclosing the entire river ribbon.
var bounds: AABB = AABB()

## Optional per-river material override. When null the presenter uses
## the global river material from TerrainConfigurationV2.
@export var material_override: Material = null

## Human-readable label (e.g. "River 1").
var display_name: String = ""

## Name of the agent that produced this data.
var source_agent: String = ""

## Check whether this data contains a valid mesh.
func is_valid() -> bool:
	if surface_arrays.size() < Mesh.ARRAY_MAX:
		return false
	var verts: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	return verts.size() >= 3

## Get vertex count.
func get_vertex_count() -> int:
	if surface_arrays.size() < Mesh.ARRAY_MAX:
		return 0
	var verts: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	return verts.size()

## Get triangle count.
func get_triangle_count() -> int:
	if surface_arrays.size() < Mesh.ARRAY_MAX:
		return 0
	var indices: PackedInt32Array = surface_arrays[Mesh.ARRAY_INDEX]
	return indices.size() / 3

## Get summary string for debugging.
func get_summary() -> String:
	return "%s: %d verts, %d tris, path %d pts" % [
		display_name if display_name != "" else "River",
		get_vertex_count(),
		get_triangle_count(),
		downstream_path.size()
	]

