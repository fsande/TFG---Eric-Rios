## @brief Typed container for a single benchmark measurement.
##
## @details Stores timing, metric name, metadata, and supports statistical aggregation
## across multiple samples. Provides confidence intervals, coefficient of variation,
## and interquartile range for robust analysis.
class_name BenchmarkResult extends RefCounted

## Z-score for 95% confidence interval (normal distribution approximation)
const Z_95: float = 1.96

## Identifies the benchmark (e.g. "pipeline_generation", "chunk_gen_lod0")
var metric_name: String

## Category for grouping in reports (e.g. "pipeline", "chunk_generation", "static_analysis")
var category: String

## Unit of measurement (e.g. "ms", "count", "MB", "fps", "triangles")
var unit: String

## Raw sample values
var samples: PackedFloat64Array

## Arbitrary key-value metadata (terrain_size, resolution, lod, config_name, etc.)
var metadata: Dictionary

## Timestamp when the benchmark was recorded
var timestamp: int

func _init(
	p_metric_name: String = "",
	p_category: String = "",
	p_unit: String = "ms",
	p_samples: PackedFloat64Array = PackedFloat64Array(),
	p_metadata: Dictionary = {}
) -> void:
	metric_name = p_metric_name
	category = p_category
	unit = p_unit
	samples = p_samples
	metadata = p_metadata
	timestamp = int(Time.get_unix_time_from_system())

func get_sample_count() -> int:
	return samples.size()

func get_mean() -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for sample in samples:
		total += sample
	return total / samples.size()

func get_min() -> float:
	if samples.is_empty():
		return 0.0
	var min := samples[0]
	for sample in samples:
		min = minf(min, sample)
	return min

func get_max() -> float:
	if samples.is_empty():
		return 0.0
	var max := samples[0]
	for sample in samples:
		max = maxf(max, sample)
	return max

func get_median() -> float:
	return get_percentile(50.0)

func get_std_dev() -> float:
	if samples.size() < 2:
		return 0.0
	var mean := get_mean()
	var sum_sq := 0.0
	for sample in samples:
		var diff := sample - mean
		sum_sq += diff * diff
	return sqrt(sum_sq / (samples.size() - 1))

## Percentile value (0-100)
func get_percentile(p: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := Array(samples)
	sorted.sort()
	var rank := int(ceil(p / 100.0 * sorted.size())) - 1
	rank = clampi(rank, 0, sorted.size() - 1)
	return sorted[rank]

## Standard error of the mean (SEM = σ / sqrt(n)).
func get_standard_error() -> float:
	if samples.size() < 2:
		return 0.0
	return get_std_dev() / sqrt(float(samples.size()))

## 95% confidence interval as Vector2(lower_bound, upper_bound).
## Uses Z_95 ≈ 1.96 (normal approximation; valid for n >= 30, reasonable for n >= 5).
func get_confidence_interval_95() -> Vector2:
	if samples.size() < 2:
		return Vector2(get_mean(), get_mean())
	var se := get_standard_error()
	var margin := Z_95 * se
	return Vector2(get_mean() - margin, get_mean() + margin)

## Coefficient of variation (CV = σ / μ × 100%). Indicates measurement stability.
func get_coefficient_of_variation() -> float:
	var mean := get_mean()
	if mean == 0.0 or samples.size() < 2:
		return 0.0
	return (get_std_dev() / absf(mean)) * 100.0

## Interquartile range (IQR = Q3 - Q1). More robust than std_dev for outlier detection.
func get_iqr() -> float:
	return get_percentile(75.0) - get_percentile(25.0)

func get_value() -> float:
	if samples.size() == 1:
		return samples[0]
	return get_mean()

func format(include_stats: bool = true) -> String:
	if samples.is_empty():
		return "%s: no data" % metric_name
	if samples.size() == 1 or not include_stats:
		return "%s: %.2f %s" % [metric_name, get_value(), unit]
	var ci := get_confidence_interval_95()
	return "%s: %.2f %s (min=%.2f, max=%.2f, σ=%.2f, CI95=[%.2f, %.2f], n=%d)" % [
		metric_name, get_mean(), unit,
		get_min(), get_max(), get_std_dev(),
		ci.x, ci.y, samples.size()
	]

func to_dict() -> Dictionary:
	var ci := get_confidence_interval_95()
	return {
		"metric_name": metric_name,
		"category": category,
		"unit": unit,
		"sample_count": samples.size(),
		"mean": get_mean(),
		"min": get_min(),
		"max": get_max(),
		"median": get_median(),
		"std_dev": get_std_dev(),
		"standard_error": get_standard_error(),
		"ci95_lower": ci.x,
		"ci95_upper": ci.y,
		"cv_percent": get_coefficient_of_variation(),
		"iqr": get_iqr(),
		"p95": get_percentile(95.0),
		"p99": get_percentile(99.0),
		"samples": Array(samples),
		"metadata": metadata,
		"timestamp": timestamp
	}
