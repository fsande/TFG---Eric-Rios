## @brief Main orchestrator that executes stages in sequence.
##
## @details Manages the complete mesh modification pipeline, handling dependencies,
## validation, error handling, and progress tracking.
@tool
class_name MeshModifierPipeline extends Resource

## Emitted when pipeline begins execution.
signal pipeline_started()
## Emitted when each stage starts.
signal stage_started(stage_index: int, stage_name: String)
## Emitted when each stage completes.
signal stage_completed(stage_index: int, stage_name: String, elapsed_ms: float)
## Emitted when stage fails.
signal stage_failed(stage_index: int, stage_name: String, error: String)
## Emitted when entire pipeline completes successfully.
signal pipeline_completed(context: MeshModifierContext)

## Human-readable pipeline name.
@export var pipeline_name: String = "Unnamed Pipeline"
## Ordered list of pipeline stages.
@export var stages: Array[PipelineStage] = []

@export_group("Validation")
## Whether to abort on validation failure.
@export var fail_on_validation_error: bool = true

@export_group("Performance")
## Cache pipeline results (future feature).
@export var enable_caching: bool = false
## Log detailed performance stats.
@export var log_detailed_stats: bool = true
## Maximum total pipeline time (5 minutes default).
@export var max_pipeline_time_ms: int = 300000

## Internal state
var _is_executing: bool = false
var _execution_context: MeshModifierContext = null
var _start_time_ms: int = 0

## Execute entire pipeline.
func execute(terrain_data: TerrainData, processing_context: ProcessingContext, scene_root: Node3D, parameters: MeshGeneratorParameters) -> MeshModifierContext:
	if not validate(terrain_data):
		_is_executing = false
		return null
	if log_detailed_stats:
		print("\n=== Starting Pipeline: %s ===" % pipeline_name)
	_is_executing = true
	_start_time_ms = Time.get_ticks_msec()
	pipeline_started.emit()
	_execution_context = MeshModifierContext.new(terrain_data, processing_context, scene_root, parameters)
	for stage_index in range(stages.size()):
		var stage := stages[stage_index]
		if not stage.enabled:
			if log_detailed_stats:
				print("Skipping disabled stage: %s" % stage._get_display_name())
			continue
		if _check_timeout():
			var error_msg := "Pipeline timeout after %.2f seconds" % (max_pipeline_time_ms / 1000.0)
			push_error(error_msg)
			_is_executing = false
			return null
		stage_started.emit(stage_index, stage._get_display_name())
		if log_detailed_stats:
			print("\n--- Stage %d/%d: %s ---" % [stage_index + 1, stages.size(), stage._get_display_name()])
		var success := stage.execute(_execution_context)
		if not success:
			var error_msg := "Stage '%s' failed" % stage._get_display_name()
			stage_failed.emit(stage_index, stage._get_display_name(), error_msg)
			_is_executing = false
			return null
		stage_completed.emit(stage_index, stage._get_display_name(), 0.0)  # TODO: Track stage time
	var total_time := Time.get_ticks_msec() - _start_time_ms
	if log_detailed_stats:
		print("\n=== Pipeline Complete ===")
		print("Total time: %.2f ms" % total_time)
		_execution_context.print_execution_summary()
	_is_executing = false
	pipeline_completed.emit(_execution_context)
	return _execution_context

## Validate pipeline configuration.
func validate(terrain_data: TerrainData) -> bool:
	if _is_executing:
		push_error("Pipeline is already executing")
		return false
	if terrain_data.mesh_result.mesh_size == Vector2.ZERO:
		push_error("Pipeline execution failed: Mesh size is zero")
		return false
	if stages.is_empty():
		push_error("%s: Pipeline has no stages" % pipeline_name)
		return false
	for stage in stages:
		if not stage.validate():
			if fail_on_validation_error:
				push_error("%s: Stage '%s' validation failed" % [pipeline_name, stage._get_display_name()])
				return false
			else:
				push_warning("%s: Stage '%s' validation failed" % [pipeline_name, stage._get_display_name()])
	return true

## Internal: Check if pipeline exceeded max time.
func _check_timeout() -> bool:
	if max_pipeline_time_ms <= 0:
		return false
	return (Time.get_ticks_msec() - _start_time_ms) > max_pipeline_time_ms
