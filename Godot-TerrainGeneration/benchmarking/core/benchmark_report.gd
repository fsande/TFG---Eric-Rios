## @brief Report generator: console, CSV, and JSON output from benchmark results.
class_name BenchmarkReport extends RefCounted

var _results: Array[BenchmarkResult] = []
var _environment: EnvironmentInfo

const HIGHER_IS_BETTER_UNITS := ["fps", "count"]

func _init() -> void:
	_environment = EnvironmentInfo.capture()

func add_result(result: BenchmarkResult) -> void:
	_results.append(result)

func add_results(results: Array[BenchmarkResult]) -> void:
	_results.append_array(results)

func get_result_count() -> int:
	return _results.size()

func get_results_by_category(category: String) -> Array[BenchmarkResult]:
	var filtered: Array[BenchmarkResult] = []
	for r in _results:
		if r.category == category:
			filtered.append(r)
	return filtered

func get_categories() -> PackedStringArray:
	var categories := PackedStringArray()
	for r in _results:
		if not categories.has(r.category):
			categories.append(r.category)
	return categories

func print_report() -> void:
	print("")
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║         TERRAIN BENCHMARK REPORT                             ║")
	print("║         %s" % _environment.timestamp)
	print("╠══════════════════════════════════════════════════════════════╣")
	_environment.print_summary()
	print("╠══════════════════════════════════════════════════════════════╣")
	for category in get_categories():
		print("║")
		print("║ ─── %s ───" % category.to_upper())
		for r in get_results_by_category(category):
			print("║   %s" % r.format(true))
	print("╚══════════════════════════════════════════════════════════════╝")
	print("")


func save_csv(path: String, include_raw_samples: bool = false) -> Error:
	_ensure_directory(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("BenchmarkReport: Cannot write %s" % path)
		return FileAccess.get_open_error()
	var meta_keys := _collect_metadata_keys()
	var header := "category,metric,unit,mean,min,max,median,std_dev,ci95_lower,ci95_upper,cv_percent,iqr,p95,p99,sample_count"
	if include_raw_samples:
		header += ",raw_samples"
	for key in meta_keys:
		header += ",%s" % key
	file.store_line(header)
	for r in _results:
		var ci := r.get_confidence_interval_95()
		var line := "%s,%s,%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%d" % [
			_escape(r.category), _escape(r.metric_name), _escape(r.unit),
			r.get_mean(), r.get_min(), r.get_max(), r.get_median(),
			r.get_std_dev(), ci.x, ci.y,
			r.get_coefficient_of_variation(), r.get_iqr(),
			r.get_percentile(95.0), r.get_percentile(99.0),
			r.get_sample_count()
		]
		if include_raw_samples:
			var parts := PackedStringArray()
			for s in r.samples:
				parts.append("%.4f" % s)
			line += ",\"%s\"" % ";".join(parts)
		for key in meta_keys:
			line += ",%s" % _escape(str(r.metadata.get(key, "")))
		file.store_line(line)
	file.close()
	print("BenchmarkReport: CSV → %s" % path)
	return OK


func save_json(path: String) -> Error:
	_ensure_directory(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("BenchmarkReport: Cannot write %s" % path)
		return FileAccess.get_open_error()
	var data := {"environment": _environment.to_dict(), "results": []}
	for r in _results:
		data.results.append(r.to_dict())
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("BenchmarkReport: JSON → %s" % path)
	return OK

## @brief Compare two benchmark reports and generate a summary of significant changes.
static func compare(baseline: BenchmarkReport, current: BenchmarkReport, threshold_pct: float = 5.0) -> String:
	var lines := PackedStringArray()
	lines.append("=== Benchmark Comparison (threshold: %.1f%%) ===" % threshold_pct)
	lines.append("")
	var baseline_map := {}
	for result in baseline._results:
		baseline_map["%s/%s" % [result.category, result.metric_name]] = result
	for result in current._results:
		var key := "%s/%s" % [result.category, result.metric_name]
		if not baseline_map.has(key):
			lines.append("  [NEW] %s: %.2f %s" % [key, result.get_mean(), result.unit])
			continue
		var base_r: BenchmarkResult = baseline_map[key]
		if base_r.get_mean() == 0.0:
			continue
		var pct := ((result.get_mean() - base_r.get_mean()) / base_r.get_mean()) * 100.0
		if absf(pct) < threshold_pct:
			continue
		var higher_is_worse := not HIGHER_IS_BETTER_UNITS.has(result.unit.to_lower())
		var is_regression := (pct > 0.0) if higher_is_worse else (pct < 0.0)
		var tag := "REGRESSION" if is_regression else "IMPROVED"
		lines.append("  %s %s: %.2f → %.2f %s (%+.1f%%)" % [
			tag, key, base_r.get_mean(), result.get_mean(), result.unit, pct
		])
	if lines.size() <= 2:
		lines.append("  No significant changes detected.")
	return "\n".join(lines)

## @brief Collect all unique metadata keys from the benchmark results for CSV header generation.
func _collect_metadata_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for r in _results:
		for key in r.metadata.keys():
			if not keys.has(key):
				keys.append(key)
	return keys

## @brief Escape CSV values if they contain special characters.
func _escape(value: String) -> String:
	if value.contains(",") or value.contains("\"") or value.contains("\n"):
		return "\"%s\"" % value.replace("\"", "\"\"")
	return value

## @brief Ensure the directory for a given file path exists, creating it if necessary.
func _ensure_directory(file_path: String) -> void:
	var dir_path := file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
