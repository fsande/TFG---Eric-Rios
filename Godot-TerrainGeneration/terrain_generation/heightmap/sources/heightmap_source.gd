## @brief Interface for heightmap sources used in terrain generation.
##
## @details All heightmap sources receive a ProcessingContext containing GPU resources,
## terrain size, seed, and parameters. This eliminates duplicate GPU initialization.
@tool @abstract
class_name HeightmapSource extends Resource 

signal heightmap_changed

@export var save_path: String
@export var export_size: float = 1024.0:
	set(value):
		export_size = value
		heightmap_changed.emit()

## Generate a heightmap using the provided ProcessingContext.
## Context contains terrain_size, generation_seed, GPU resources, and parameters.
@abstract func generate(context: ProcessingContext) -> Image

## Get metadata about this heightmap source for debugging/logging.
@abstract func get_metadata() -> Dictionary
	
## Export heightmap to PNG (used by editor tool button).
@export_tool_button("Export") var export_action := export_to_png
func export_to_png() -> void:
	var temp_context := ProcessingContext.new(export_size,
		ProcessingContext.ProcessorType.CPU,
		ProcessingContext.ProcessorType.CPU,
		0)
	var img := generate(temp_context)
	temp_context.dispose()
	if not img:
		push_error("HeightmapSource: No image to export")
		return
	var file_path := save_path if save_path != "" else "res://heightmap.png"
	if not file_path.begins_with("res://") and not file_path.begins_with("user://"):
		file_path = "res://" + file_path
	var err := img.save_png(file_path)
	if err != OK:
		push_error("HeightmapSource: Failed to save image to %s" % file_path)
	else:
		print("HeightmapSource: Image saved to %s" % file_path)
