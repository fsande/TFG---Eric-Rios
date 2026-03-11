## @brief Scene script that runs TerrainBenchmark with an assigned profile on _ready().
class_name BenchmarkSceneRunner extends Node

## Assign your BenchmarkProfile .tres resource here in the inspector.
@export var profile: BenchmarkProfile
@export var auto_run: bool = true

var _report: BenchmarkReport


func _ready() -> void:
	if auto_run and profile:
		call_deferred("_run")
	elif not profile:
		push_warning("BenchmarkSceneRunner: No profile assigned.")


func _run() -> void:
	if not profile or profile.configurations.is_empty():
		push_error("BenchmarkSceneRunner: Profile has no configurations.")
		return
	var benchmark := TerrainBenchmark.new()
	benchmark.config_started.connect(
		func(benchmark_name: String, idx: int, total: int) -> void:
			print("[Bench] Config %d/%d: %s" % [idx + 1, total, benchmark_name])
	)
	benchmark.benchmark_completed.connect(
		func(report: BenchmarkReport) -> void:
			print("[Bench] Done — %d results saved to %s" % [report.get_result_count(), profile.output_dir])
	)
	_report = benchmark.run(profile)
