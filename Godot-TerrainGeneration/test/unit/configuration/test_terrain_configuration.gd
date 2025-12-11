extends GutTest

## Test suite for TerrainConfiguration
## File: terrain_generation/configuration/terrain_configuration.gd

# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

var test_config: TerrainConfiguration

func before_each():
	test_config = TerrainConfiguration.new()

func after_each():
	test_config = null

# ============================================================================
# CONSTRUCTION
# ============================================================================

func test_construction_creates_valid_object():
	assert_not_null(test_config, "Should create valid TerrainConfiguration")

# ============================================================================
# HEIGHTMAP SOURCE TESTS
# ============================================================================

func test_heightmap_source_can_be_set():
	var source := NoiseHeightmapSource.new()
	test_config.heightmap_source = source
	assert_eq(test_config.heightmap_source, source, "Should store heightmap source")

func test_heightmap_source_signal_connection():
	watch_signals(test_config)
	var source := NoiseHeightmapSource.new()
	test_config.heightmap_source = source
	assert_signal_emitted(test_config, "configuration_changed", "Should emit configuration_changed when heightmap source set")

func test_heightmap_source_change_propagates_signal():
	var source := NoiseHeightmapSource.new()
	test_config.heightmap_source = source
	watch_signals(test_config)
	source.heightmap_changed.emit()
	assert_signal_emitted(test_config, "configuration_changed", "Should propagate heightmap_changed signal")

# ============================================================================
# TERRAIN SIZE TESTS
# ============================================================================

func test_terrain_size_setter():
	watch_signals(test_config)
	test_config.terrain_size = 1024.0
	assert_eq(test_config.terrain_size, 1024.0, "Should update terrain_size")
	assert_signal_emitted(test_config, "configuration_changed", "Should emit signal on terrain_size change")

func test_terrain_size_updates_mesh_parameters():
	test_config.terrain_size = 2048.0
	assert_not_null(test_config.mesh_generator_parameters, "Should create mesh_generator_parameters if null")
	assert_eq(test_config.mesh_generator_parameters.mesh_size, Vector2(2048.0, 2048.0), "Should update mesh_size in parameters")

# ============================================================================
# GENERATION SEED TESTS
# ============================================================================

func test_generation_seed_setter():
	watch_signals(test_config)
	test_config.generation_seed = 12345
	assert_eq(test_config.generation_seed, 12345, "Should update generation_seed")
	assert_signal_emitted(test_config, "configuration_changed", "Should emit signal on seed change")

# ============================================================================
# MESH MODIFICATION PIPELINE TESTS
# ============================================================================

func test_mesh_modification_pipeline_can_be_set():
	var pipeline := MeshModifierPipeline.new()
	watch_signals(test_config)
	test_config.mesh_modification_pipeline = pipeline
	assert_eq(test_config.mesh_modification_pipeline, pipeline, "Should store pipeline")
	assert_signal_emitted(test_config, "configuration_changed", "Should emit signal on pipeline change")

# ============================================================================
# MESH GENERATOR PARAMETERS TESTS
# ============================================================================

func test_mesh_generator_parameters_can_be_set():
	var params := MeshGeneratorParameters.new()
	params.subdivisions = 128
	watch_signals(test_config)
	test_config.mesh_generator_parameters = params
	assert_eq(test_config.mesh_generator_parameters, params, "Should store mesh parameters")
	assert_signal_emitted(test_config, "configuration_changed", "Should emit signal on parameters change")

# ============================================================================
# VISUAL SETTINGS TESTS
# ============================================================================

func test_snow_line_setter():
	watch_signals(test_config)
	test_config.snow_line = 128.0
	assert_eq(test_config.snow_line, 128.0, "Should update snow_line")
	assert_signal_emitted(test_config, "configuration_changed", "Should emit signal on snow_line change")

func test_terrain_material_setter():
	var material := StandardMaterial3D.new()
	watch_signals(test_config)
	test_config.terrain_material = material
	assert_eq(test_config.terrain_material, material, "Should store terrain_material")
	assert_signal_emitted(test_config, "configuration_changed", "Should emit signal on material change")

# ============================================================================
# COLLISION SETTINGS TESTS
# ============================================================================

func test_generate_collision_setter():
	watch_signals(test_config)
	test_config.generate_collision = false
	assert_false(test_config.generate_collision, "Should update generate_collision")
	assert_signal_emitted(test_config, "configuration_changed", "Should emit signal on collision change")

func test_collision_layers_setter():
	watch_signals(test_config)
	test_config.collision_layers = 5
	assert_eq(test_config.collision_layers, 5, "Should update collision_layers")
	assert_signal_emitted(test_config, "configuration_changed", "Should emit signal on layers change")

# ============================================================================
# PERFORMANCE SETTINGS TESTS
# ============================================================================

func test_mesh_modifier_type_setter():
	watch_signals(test_config)
	test_config.mesh_modifier_type = TerrainConfiguration.MeshModifierType.GPU
	assert_eq(test_config.mesh_modifier_type, TerrainConfiguration.MeshModifierType.GPU, "Should update mesh_modifier_type")
	assert_signal_emitted(test_config, "configuration_changed", "Should emit signal on type change")

func test_heightmap_processor_type_setter():
	watch_signals(test_config)
	test_config.heightmap_processor_type = TerrainConfiguration.HeightmapProcessorType.GPU
	assert_eq(test_config.heightmap_processor_type, TerrainConfiguration.HeightmapProcessorType.GPU, "Should update heightmap_processor_type")
	assert_signal_emitted(test_config, "configuration_changed", "Should emit signal on processor type change")

func test_enable_caching_can_be_toggled():
	test_config.enable_caching = false
	assert_false(test_config.enable_caching, "Should update enable_caching")
	test_config.enable_caching = true
	assert_true(test_config.enable_caching, "Should toggle enable_caching")

# ============================================================================
# VALIDATION TESTS
# ============================================================================

func test_is_valid_returns_false_without_heightmap_source():
	assert_false(test_config.is_valid(), "Should return false when heightmap_source is null")

func test_is_valid_returns_true_with_heightmap_source():
	test_config.heightmap_source = NoiseHeightmapSource.new()
	assert_true(test_config.is_valid(), "Should return true when heightmap_source is set")

# ============================================================================
# HELPER METHOD TESTS
# ============================================================================

func test_get_generation_size():
	test_config.terrain_size = 1024.0
	assert_eq(test_config.get_generation_size(), 1024.0, "Should return terrain_size")

func test_get_mesh_parameters():
	var params := MeshGeneratorParameters.new()
	params.height_scale = 150.0
	params.mesh_size = Vector2(512.0, 512.0)
	params.subdivisions = 64
	test_config.mesh_generator_parameters = params
	var result := test_config.get_mesh_parameters()
	assert_eq(result["height_scale"], 150.0, "Should return height_scale")
	assert_eq(result["mesh_size"], Vector2(512.0, 512.0), "Should return mesh_size")
	assert_eq(result["subdivisions"], 64, "Should return subdivisions")

func test_get_effective_processor_type_cpu():
	test_config.heightmap_processor_type = TerrainConfiguration.HeightmapProcessorType.CPU
	var result := test_config.get_effective_processor_type()
	assert_eq(result, ProcessingContext.ProcessorType.CPU, "Should return CPU type")

func test_get_effective_processor_type_gpu():
	test_config.heightmap_processor_type = TerrainConfiguration.HeightmapProcessorType.GPU
	var result := test_config.get_effective_processor_type()
	assert_eq(result, ProcessingContext.ProcessorType.GPU, "Should return GPU type")

func test_get_effective_processor_type_match_mesh_cpu():
	test_config.heightmap_processor_type = TerrainConfiguration.HeightmapProcessorType.MATCH_MESH
	test_config.mesh_modifier_type = TerrainConfiguration.MeshModifierType.CPU
	var result := test_config.get_effective_processor_type()
	assert_eq(result, ProcessingContext.ProcessorType.CPU, "Should match CPU mesh modifier")

func test_get_effective_processor_type_match_mesh_gpu():
	test_config.heightmap_processor_type = TerrainConfiguration.HeightmapProcessorType.MATCH_MESH
	test_config.mesh_modifier_type = TerrainConfiguration.MeshModifierType.GPU
	var result := test_config.get_effective_processor_type()
	assert_eq(result, ProcessingContext.ProcessorType.GPU, "Should match GPU mesh modifier")

# ============================================================================
# ENUM TESTS
# ============================================================================

func test_mesh_modifier_type_enum_values():
	assert_eq(TerrainConfiguration.MeshModifierType.CPU, 0, "CPU should be 0")
	assert_eq(TerrainConfiguration.MeshModifierType.GPU, 1, "GPU should be 1")

func test_heightmap_processor_type_enum_values():
	assert_eq(TerrainConfiguration.HeightmapProcessorType.MATCH_MESH, 0, "MATCH_MESH should be 0")
	assert_eq(TerrainConfiguration.HeightmapProcessorType.CPU, 1, "CPU should be 1")
	assert_eq(TerrainConfiguration.HeightmapProcessorType.GPU, 2, "GPU should be 2")
