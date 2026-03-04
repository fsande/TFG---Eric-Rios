## @brief Resource defining what to benchmark and how.
##
## @details Points to real TerrainConfigurationV2 resources — the same ones
## your scenes use. Create profiles as .tres files for different scenarios:
## one for current scene, one for resolution sweeps, one for smoke tests, etc.
@tool
class_name BenchmarkProfile extends Resource

@export_group("Configurations")
## The terrain configurations to benchmark. Each is run independently.
@export var configurations: Array[TerrainConfigurationV2] = []

@export_group("Benchmark Parameters")
@export_range(0, 10) var warmup_iterations: int = 1
@export_range(1, 100) var iterations: int = 5

## How many chunks to generate per configuration (spread from terrain center).
@export_range(1, 100) var chunks_to_generate: int = 25

@export_group("Output")
@export var output_dir: String = "user://benchmarks/"

## Tag appended to filenames (e.g. "baseline", "after_fix", "no_props").
@export var run_tag: String = ""
@export var export_raw_samples: bool = false

@export_group("Optional Overrides")
## If non-empty, benchmark these LOD levels instead of deriving from config.
@export var lod_level_overrides: Array[int] = []

func get_config_name(index: int) -> String:
	if index < 0 or index >= configurations.size():
		return "unknown"
	var config := configurations[index]
	return "config_%d_t%d_r%d" % [index, int(config.terrain_size.x), config.base_chunk_resolution]

func get_lod_levels_for_config(config: TerrainConfigurationV2) -> Array[int]:
	if not lod_level_overrides.is_empty():
		return lod_level_overrides
	var levels: Array[int] = [0]
	for i in range(1, config.lod_distances.size() + 1):
		levels.append(i)
	return levels
