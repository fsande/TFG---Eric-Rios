extends GutTest

var test_config: TerrainConfiguration

func before_each():
	test_config = TerrainConfiguration.new()

func after_each():
	test_config = null

func test_heightmap_source_change_propagates_through_signal_chain():
	var source := NoiseHeightmapSource.new()
	test_config.heightmap_source = source
	watch_signals(test_config)
	source.heightmap_changed.emit()
	assert_signal_emitted(test_config, "configuration_changed", "Should propagate heightmap_changed")

func test_replacing_heightmap_source_disconnects_old_source():
	var source1 := NoiseHeightmapSource.new()
	test_config.heightmap_source = source1
	var source2 := NoiseHeightmapSource.new()
	watch_signals(test_config)
	test_config.heightmap_source = source2
	assert_signal_emit_count(test_config, "configuration_changed", 1, "Should emit once for replacement")
	source1.heightmap_changed.emit()
	assert_signal_emit_count(test_config, "configuration_changed", 1, "Old source should be disconnected")

func test_multiple_property_changes_emit_multiple_signals():
	watch_signals(test_config)
	test_config.terrain_size = 1024.0
	test_config.generation_seed = 12345
	test_config.snow_line = 128.0
	# Emmits 4, as terrain_size change also updates mesh_generator_parameters
	assert_signal_emit_count(test_config, "configuration_changed", 4, "Should emit once per property change")

func test_terrain_size_rejects_invalid_values():
	watch_signals(test_config)
	test_config.terrain_size = -100.0
	assert_signal_emit_count(test_config, "configuration_changed", 0, "Should not emit signal for invalid value")
	test_config.terrain_size = 0.0
	assert_push_error(2, "terrain_size must be positive")
	assert_signal_emit_count(test_config, "configuration_changed", 0, "Should reject zero")

func test_terrain_size_updates_mesh_parameters_automatically():
	test_config.terrain_size = 2048.0
	assert_not_null(test_config.mesh_generator_parameters, "Should auto-create parameters")
	assert_eq(test_config.mesh_generator_parameters.mesh_size, Vector2(2048.0, 2048.0), "Should sync size")
	test_config.terrain_size = 512.0
	assert_eq(test_config.mesh_generator_parameters.mesh_size, Vector2(512.0, 512.0), "Should update on change")

func test_is_valid_requires_heightmap_source():
	assert_false(test_config.is_valid(), "Should be invalid without heightmap source")
	test_config.heightmap_source = NoiseHeightmapSource.new()
	assert_true(test_config.is_valid(), "Should be valid with heightmap source")
	test_config.heightmap_source = null
	assert_false(test_config.is_valid(), "Should become invalid when source removed")

func test_get_effective_processor_type_with_explicit_settings():
	test_config.heightmap_processor_type = ProcessingContext.ProcessorType.CPU
	assert_eq(test_config.get_effective_processor_type(), ProcessingContext.ProcessorType.CPU, "Explicit CPU")
	test_config.heightmap_processor_type = ProcessingContext.ProcessorType.GPU
	assert_eq(test_config.get_effective_processor_type(), ProcessingContext.ProcessorType.GPU, "Explicit GPU")

func test_get_mesh_parameters_returns_correct_dictionary():
	var params := MeshGeneratorParameters.new()
	params.height_scale = 150.0
	params.mesh_size = Vector2(512.0, 512.0)
	params.subdivisions = 64
	test_config.mesh_generator_parameters = params
	var result := test_config.get_mesh_parameters()
	assert_eq(result.size(), 3, "Should return 3 parameters")
	assert_eq(result["height_scale"], 150.0, "Should include height_scale")
	assert_eq(result["mesh_size"], Vector2(512.0, 512.0), "Should include mesh_size")
	assert_eq(result["subdivisions"], 64, "Should include subdivisions")
