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
## Emitted when pipeline fails.
signal pipeline_failed(error: String)
## Overall pipeline progress (0.0 to 1.0).
signal pipeline_progress(progress: float, message: String)

## Human-readable pipeline name.
@export var pipeline_name: String = "Unnamed Pipeline"
## Ordered list of pipeline stages.
@export var stages: Array[PipelineStage] = []

@export_group("Validation")
## Whether to validate agent dependencies before execution.
@export var validate_dependencies: bool = true
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
	if _is_executing:
		push_error("Pipeline is already executing")
		return null
	
	_is_executing = true
	_start_time_ms = Time.get_ticks_msec()
	pipeline_started.emit()
	
	if log_detailed_stats:
		print("\n=== Starting Pipeline: %s ===" % pipeline_name)
	
	# Validate pipeline
	if not validate():
		pipeline_failed.emit("Pipeline validation failed")
		_is_executing = false
		return null
	
	# Get MeshGenerationResult from TerrainData and ensure metadata is set
	var mesh_result := terrain_data.mesh_result
	
	var subdivisions: int = parameters.subdivisions
	# Ensure mesh dimensions match expected subdivisions + 2 (for borders)
	mesh_result.width = subdivisions + 2
	mesh_result.height = subdivisions + 2
	
	if mesh_result.mesh_size == Vector2.ZERO:
		mesh_result.mesh_size = parameters.mesh_size
	_execution_context = MeshModifierContext.new(terrain_data, processing_context, scene_root, parameters)
	
	# Execute stages
	for stage_index in range(stages.size()):
		var stage := stages[stage_index]
		
		if not stage.enabled:
			if log_detailed_stats:
				print("Skipping disabled stage: %s" % stage._get_display_name())
			continue
		
		# Check timeout
		if _check_timeout():
			var error_msg := "Pipeline timeout after %.2f seconds" % (max_pipeline_time_ms / 1000.0)
			pipeline_failed.emit(error_msg)
			_is_executing = false
			return null
		
		# Execute stage
		stage_started.emit(stage_index, stage._get_display_name())
		_report_progress(stage_index, stages.size(), "Executing stage: %s" % stage._get_display_name())
		
		if log_detailed_stats:
			print("\n--- Stage %d/%d: %s ---" % [stage_index + 1, stages.size(), stage._get_display_name()])
		
		var success := stage.execute(_execution_context)
		
		if not success:
			var error_msg := "Stage '%s' failed" % stage._get_display_name()
			stage_failed.emit(stage_index, stage._get_display_name(), error_msg)
			pipeline_failed.emit(error_msg)
			_is_executing = false
			return null
		
		stage_completed.emit(stage_index, stage._get_display_name(), 0.0)  # TODO: Track stage time
	
	# Pipeline complete
	var total_time := Time.get_ticks_msec() - _start_time_ms
	
	if log_detailed_stats:
		print("\n=== Pipeline Complete ===")
		print("Total time: %.2f ms" % total_time)
		_execution_context.print_execution_summary()
	
	_is_executing = false
	pipeline_completed.emit(_execution_context)
	return _execution_context

## Validate pipeline configuration.
func validate() -> bool:
	if stages.is_empty():
		push_error("%s: Pipeline has no stages" % pipeline_name)
		return false
	
	# Validate each stage
	for stage in stages:
		if not stage.validate():
			if fail_on_validation_error:
				push_error("%s: Stage '%s' validation failed" % [pipeline_name, stage._get_display_name()])
				return false
			else:
				push_warning("%s: Stage '%s' validation failed" % [pipeline_name, stage._get_display_name()])
	
	# TODO: Validate dependencies if enabled
	if validate_dependencies:
		pass  # Implement dependency validation
	
	return true

## Get validation errors.
func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	
	if stages.is_empty():
		errors.append("Pipeline has no stages")
	
	for stage in stages:
		if not stage.validate():
			errors.append("Stage '%s' is invalid" % stage._get_display_name())
	
	return errors

## Get all agents in pipeline.
func get_all_agents() -> Array[MeshModifierAgent]:
	var all_agents: Array[MeshModifierAgent] = []
	for stage in stages:
		all_agents.append_array(stage.get_agents())
	return all_agents

## Get agent by name.
func get_agent_by_name(agent_name: String) -> MeshModifierAgent:
	for agent in get_all_agents():
		if agent._get_display_name() == agent_name:
			return agent
	return null

## Get stage by name.
func get_stage_by_name(stage_name: String) -> PipelineStage:
	for stage in stages:
		if stage._get_display_name() == stage_name:
			return stage
	return null

## Get stage count.
func get_stage_count() -> int:
	return stages.size()

## Check if pipeline is currently running.
func is_executing() -> bool:
	return _is_executing

## Cancel currently running pipeline.
func cancel_execution() -> void:
	if _is_executing:
		pipeline_failed.emit("Pipeline cancelled by user")
		_is_executing = false

## Add stage to end of pipeline.
func add_stage(stage: PipelineStage) -> void:
	stages.append(stage)

## Insert stage at specific index.
func insert_stage(index: int, stage: PipelineStage) -> void:
	if index >= 0 and index <= stages.size():
		stages.insert(index, stage)

## Remove stage by index.
func remove_stage(index: int) -> void:
	if index >= 0 and index < stages.size():
		stages.remove_at(index)

## Clear all stages.
func clear_stages() -> void:
	stages.clear()

## Duplicate pipeline.
func duplicate_pipeline() -> MeshModifierPipeline:
	var dup := MeshModifierPipeline.new()
	dup.pipeline_name = pipeline_name + " (Copy)"
	dup.stages = stages.duplicate()
	dup.validate_dependencies = validate_dependencies
	dup.fail_on_validation_error = fail_on_validation_error
	dup.enable_caching = enable_caching
	dup.log_detailed_stats = log_detailed_stats
	dup.max_pipeline_time_ms = max_pipeline_time_ms
	return dup

## Internal: Report pipeline progress.
func _report_progress(current_stage: int, total_stages: int, message: String) -> void:
	var progress := float(current_stage) / float(total_stages)
	pipeline_progress.emit(progress, message)

## Internal: Check if pipeline exceeded max time.
func _check_timeout() -> bool:
	if max_pipeline_time_ms <= 0:
		return false
	return (Time.get_ticks_msec() - _start_time_ms) > max_pipeline_time_ms
