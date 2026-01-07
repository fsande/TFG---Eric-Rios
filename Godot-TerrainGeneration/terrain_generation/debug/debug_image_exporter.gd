class_name DebugImageExporter 
static func export_image(image: Image, file_path: String) -> void:
	if not image:
		push_error("DebugImageExporter: Cannot export null image to %s" % file_path)
		return
	var err := image.save_png(file_path)
	if err != OK:
		push_error("DebugImageExporter: Failed to save image to %s (Error code: %d)" % [file_path, err])
	else:
		print("DebugImageExporter: Successfully exported image to %s" % file_path)