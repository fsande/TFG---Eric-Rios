## @brief Typed container for system environment information.
##
## @details Captures hardware and engine details at benchmark time for
## reproducibility and cross-run comparison. Replaces loose Dictionary metadata.
class_name EnvironmentInfo extends RefCounted

var timestamp: String
var engine_version: String
var renderer: String
var os_name: String
var cpu_name: String
var cpu_count: int

static func capture() -> EnvironmentInfo:
	var info := EnvironmentInfo.new()
	info.timestamp = Time.get_datetime_string_from_system()
	info.engine_version = Engine.get_version_info().string
	info.renderer = ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")
	info.os_name = OS.get_name()
	info.cpu_name = OS.get_processor_name()
	info.cpu_count = OS.get_processor_count()
	return info

func to_dict() -> Dictionary:
	return {
		"timestamp": timestamp,
		"engine_version": engine_version,
		"renderer": renderer,
		"os_name": os_name,
		"cpu_name": cpu_name,
		"cpu_count": cpu_count
	}

func print_summary() -> void:
	print("║ Engine: %s" % engine_version)
	print("║ Renderer: %s" % renderer)
	print("║ OS: %s | CPU: %s (%d cores)" % [os_name, cpu_name, cpu_count])
