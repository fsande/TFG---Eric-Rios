## @brief Debug HUD for terrain generation statistics.
##
## @details Shows chunk count, memory usage, and cache stats.
extends Control

@export var terrain_presenter_path: NodePath

var _terrain_presenter: TerrainPresenterV2
var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.name = "DebugLabel"
	_label.position = Vector2(10, 10)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)
	if terrain_presenter_path:
		_terrain_presenter = get_node_or_null(terrain_presenter_path) as TerrainPresenterV2

func _process(_delta: float) -> void:
	if not _terrain_presenter:
		if terrain_presenter_path:
			_terrain_presenter = get_node_or_null(terrain_presenter_path) as TerrainPresenterV2
		else:
			_terrain_presenter = _find_terrain_presenter()
		if not _terrain_presenter:
			_label.text = "TerrainPresenterV2 not found"
			return
	var stats := _terrain_presenter.get_cache_stats()
	var text := "=== Terrain V2 Debug ===\n"
	text += "Cached chunks: %d\n" % stats.get("cached_chunks", 0)
	text += "Memory: %.1f / %.1f MB (%.0f%%)\n" % [
		stats.get("memory_usage_mb", 0.0),
		stats.get("max_size_mb", 200.0),
		stats.get("utilization", 0.0) * 100.0
	]
	text += "FPS: %d\n" % Engine.get_frames_per_second()
	var camera := get_viewport().get_camera_3d()
	if camera:
		text += "Camera: (%.0f, %.0f, %.0f)\n" % [camera.position.x, camera.position.y, camera.position.z]
	text += "\n[WASD] Move  [Shift] Fast\n"
	text += "[Right Mouse] Look\n"
	text += "[E/Q] Up/Down"
	_label.text = text

func _find_terrain_presenter() -> TerrainPresenterV2:
	var root := get_tree().current_scene
	if not root:
		return null
	return _find_node_of_type(root, "TerrainPresenterV2")

func _find_node_of_type(node: Node, type_name: String) -> TerrainPresenterV2:
	if node.get_class() == type_name or (node.get_script() and node.get_script().get_global_name() == type_name):
		return node as TerrainPresenterV2
	for child in node.get_children():
		var found := _find_node_of_type(child, type_name)
		if found:
			return found
	return null

