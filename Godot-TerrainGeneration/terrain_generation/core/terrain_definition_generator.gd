## @brief Service that generates TerrainDefinition from configuration and agents.
##
## @details Orchestrates the execution of terrain modifier stages/agents to produce
## a complete TerrainDefinition that can be used for on-demand chunk generation.
## Supports both flat agent arrays (legacy) and stage-based pipelines (new).
class_name TerrainDefinitionGenerator extends RefCounted

signal generation_started()
signal stage_started(stage_name: String, index: int, total: int)
signal stage_completed(stage_name: String, elapsed_ms: float)
signal agent_started(agent_name: String, index: int, total: int)
signal agent_completed(agent_name: String, result: TerrainModifierResult)
signal generation_completed(definition: TerrainDefinition)

var reference_resolution: int = 512
var verbose: bool = true

func generate(
	heightmap_source: HeightmapSource,
	terrain_size: Vector2,
	height_scale: float,
	stages: Array[TerrainModifierStage],
	generation_seed: int = 0,
	shared_context: ProcessingContext = null,
	prop_rules: Array[PropPlacementRule] = []
) -> TerrainDefinition:
	var start_time := Time.get_ticks_msec()
	if verbose:
		print("\n=== TerrainDefinitionGenerator: Starting (Stage-based) ===")
		print("Terrain size: %s, Height scale: %.1f, Seed: %d" % [terrain_size, height_scale, generation_seed])
		print("Stages to process: %d" % stages.size())
	generation_started.emit()
	var definition := TerrainDefinition.create(heightmap_source, terrain_size, height_scale, generation_seed)
	var owns_context := shared_context == null
	var processing_context: ProcessingContext
	if shared_context:
		processing_context = shared_context
	else:
		processing_context = ProcessingContext.new(
			terrain_size.x,
			ProcessingContext.ProcessorType.CPU,
			ProcessingContext.ProcessorType.CPU,
			generation_seed
		)
	var reference_heightmap := _generate_reference_heightmap(heightmap_source, terrain_size, generation_seed, processing_context)
	if not reference_heightmap:
		push_error("TerrainDefinitionGenerator: Failed to generate reference heightmap")
		if owns_context:
			processing_context.dispose()
		return definition
	var context := TerrainGenerationContext.new(terrain_size, height_scale, generation_seed, reference_heightmap)
	context.reference_resolution = Vector2i(reference_resolution, reference_resolution)
	context.terrain_definition = definition
	context.processing_context = processing_context
	var stage_index := 0
	for stage in stages:
		if not stage.enabled:
			continue
		stage_index += 1
		if verbose:
			print("\n=== Stage %d/%d: %s ===" % [stage_index, stages.size(), stage._get_display_name()])
		stage_started.emit(stage._get_display_name(), stage_index, stages.size())
		if not stage.validate():
			push_warning("TerrainDefinitionGenerator: Stage '%s' validation failed, skipping" % stage._get_display_name())
			continue
		var stage_start := Time.get_ticks_msec()
		var success := stage.execute(context, definition)
		var stage_elapsed := Time.get_ticks_msec() - stage_start
		stage_completed.emit(stage._get_display_name(), stage_elapsed)
		if not success:
			push_error("TerrainDefinitionGenerator: Stage '%s' failed" % stage._get_display_name())
	if not prop_rules.is_empty():
		if verbose:
			print("\n=== Adding Prop Placement Rules ===")
		for rule in prop_rules:
			if rule:
				if rule.rule_id.is_empty():
					rule.rule_id = "prop_rule_%d" % definition.prop_placement_rules.size()
				if rule.seed_offset == 0:
					rule.seed_offset = generation_seed
				definition.add_prop_rule(rule)
				if verbose:
					print("Added rule: %s (density: %.3f)" % [rule.rule_id, rule.density])
	if owns_context:
		context.dispose()
	var total_time := Time.get_ticks_msec() - start_time
	if verbose:
		print("\n=== TerrainDefinitionGenerator: Complete ===")
		print("Total time: %.1f ms" % total_time)
		print(definition.get_summary())
	generation_completed.emit(definition)
	return definition

## Generate reference heightmap for agent analysis.
func _generate_reference_heightmap(
	source: HeightmapSource,
	terrain_size: Vector2,
	generation_seed: int,
	processing_context: ProcessingContext
) -> Image:
	var heightmap := source.generate(processing_context)
	return heightmap
