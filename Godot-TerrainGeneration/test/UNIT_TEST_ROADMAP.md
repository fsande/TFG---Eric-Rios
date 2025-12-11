# Terrain Generation Unit Test Roadmap

## Overview

This document provides a comprehensive, prioritized roadmap for implementing unit tests for the terrain generation system using GUT (Godot Unit Testing). The system is a work-in-progress with a sophisticated architecture covering heightmap generation, mesh generation, mesh modification pipelines, and various supporting utilities.

---

## System Architecture Summary

The terrain generation system consists of the following major components:

### 1. **Core System** (`terrain_generation/core/`)
- `TerrainGenerationService`: Main orchestrator
- `TerrainMeshBuilder`: Mesh building coordinator
- `TerrainData`: Result container
- `TerrainPresenter`: Visualization layer
- `ProcessingContext`: GPU/CPU resource management

### 2. **Configuration** (`terrain_generation/configuration/`)
- `TerrainConfiguration`: Main configuration resource
- `MeshGeneratorParameters`: Mesh generation parameters

### 3. **Heightmap System** (`terrain_generation/heightmap/`)
- **Sources**: `HeightmapSource`, `NoiseHeightmapSource`, `ImageHeightmapSource`, `TextureHeightmapSource`, `CompositeHeightmapSource`
- **Processors**: `HeightmapProcessor`, `BlurProcessor`, `MaskProcessor`, `NormalizationProcessor`, `ThermalErosionProcessor`
- **Combiners**: `HeightmapCombiner`, `WeightedCombiner`, `AverageCombiner`, `MultiplicationCombiner`
- **Transitions**: `TransitionStrategy`, `BeachTransition`, `CliffTransition`
- **Utilities**: `ImageBinarizer`

### 4. **Mesh Generation** (`terrain_generation/mesh/`)
- **Generators**: `HeightmapMeshGenerator`, `CPUMeshGenerator`, `GpuMeshGenerator`
- **Data**: `MeshData`, `MeshGenerationResult`, `SlopeData`, `TangentCalculationData`
- **Calculators**: `MeshNormalCalculator`, `MeshTangentCalculator`, `SlopeComputer`
- **Builders**: `ArrayMeshBuilder`
- **Utilities**: `MeshTopologyModifier`, `MeshSlopeDataProvider`

### 5. **Mesh Modification Pipeline** (`terrain_generation/mesh_modifiers/`)
- **Core**: `MeshModifierPipeline`, `MeshModifierAgent`, `MeshModifierContext`, `MeshModifierResult`, `VertexGrid`, `PipelineStage` (Sequential, Parallel, Conditional)
- **Agents**: `TunnelBoringAgent`, `TerrainRaiseAgent`
- **Conditions**: `AgentCondition`, `DataExistsCondition`
- **CSG**: `CSGVolume`, `CSGBooleanOperator`, `CylinderVolume`

### 6. **Resource Helpers** (`terrain_generation/resource_helpers/`)
- `ImageHelper`, `GpuResourceHelper`, `GpuTextureHelper`

### 7. **Debug** (`terrain_generation/debug/`)
- `DebugImageExporter`

---

## Testing Philosophy

### GUT Testing Best Practices
- Use descriptive test names that explain what is being tested
- Follow the Arrange-Act-Assert pattern
- Test one behavior per test function
- Use `before_each()` and `after_each()` for setup/teardown
- Leverage GUT's assertions: `assert_eq()`, `assert_ne()`, `assert_true()`, `assert_false()`, `assert_null()`, `assert_not_null()`, `assert_gt()`, `assert_lt()`, etc.
- Use `gut.p()` for debug output
- Use `watch_signals()` for testing signal emissions

### Test Organization
- One test file per class/module
- Group related tests in the same file
- Use clear section comments
- Follow naming convention: `test_<file_name>.gd`

---

## Priority Levels

**P0 (Critical)**: Core functionality - system cannot work without these  
**P1 (High)**: Essential features - major functionality  
**P2 (Medium)**: Important features - supporting functionality  
**P3 (Low)**: Nice to have - edge cases, optimizations

---

## Phase 1: Foundation & Core System (P0)

### 1.1 Data Structures (P0)
**Files to create:**
- `test/unit/test_terrain_data.gd`
- `test/unit/test_processing_context.gd`
- `test/unit/test_mesh_data.gd`
- `test/unit/test_mesh_generation_result.gd`

**Test Coverage:**

#### `test_terrain_data.gd`
```gdscript
extends GutTest

# Test TerrainData creation and accessors
- test_construction_with_valid_data()
- test_get_mesh_builds_array_mesh()
- test_get_mesh_caches_result()
- test_has_collision_returns_correct_value()
- test_get_vertex_count_returns_correct_value()
- test_get_triangle_count_calculates_correctly()
- test_metadata_storage()
- test_null_mesh_result_handling()
```

#### `test_processing_context.gd`
```gdscript
extends GutTest

# Test ProcessingContext lifecycle and resource management
- test_construction_with_cpu_type()
- test_construction_with_gpu_type()
- test_gpu_initialization_when_available()
- test_use_gpu_returns_false_for_cpu_context()
- test_use_gpu_returns_true_for_gpu_context()
- test_get_rendering_device_returns_null_for_cpu()
- test_shader_caching_works()
- test_shader_cache_returns_same_shader()
- test_dispose_prevents_further_use()
- test_disposed_context_returns_errors()
```

#### `test_mesh_data.gd`
```gdscript
extends GutTest

# Test MeshData container
- test_construction_with_empty_arrays()
- test_construction_with_valid_data()
- test_get_vertex_count()
- test_get_triangle_count()
- test_is_valid_index()
- test_get_vertex_with_valid_index()
- test_get_vertex_with_invalid_index()
- test_set_vertex_updates_position()
- test_get_height_returns_y_component()
- test_set_height_updates_y_component()
```

#### `test_mesh_generation_result.gd`
```gdscript
extends GutTest

# Test MeshGenerationResult
- test_construction_with_required_parameters()
- test_build_mesh_creates_array_mesh()
- test_metadata_fields_stored_correctly()
- test_grid_dimensions_stored()
```

### 1.2 Configuration System (P0)
**Files to create:**
- `test/unit/test_terrain_configuration.gd`
- `test/unit/test_mesh_generator_parameters.gd`

**Test Coverage:**

#### `test_terrain_configuration.gd`
```gdscript
extends GutTest

# Test TerrainConfiguration resource
- test_default_values()
- test_heightmap_source_setter_connects_signal()
- test_terrain_size_updates_mesh_parameters()
- test_configuration_changed_signal_emits()
- test_is_valid_returns_true_for_valid_config()
- test_is_valid_returns_false_for_invalid_config()
- test_get_effective_processor_type()
- test_mesh_modifier_type_enum_values()
```

### 1.3 Core Service (P0)
**Files to create:**
- `test/unit/test_terrain_generation_service.gd`

**Test Coverage:**
```gdscript
extends GutTest

# Test TerrainGenerationService orchestration
- test_generate_returns_null_for_invalid_config()
- test_generate_returns_terrain_data_for_valid_config()
- test_generate_uses_cache_when_enabled()
- test_generate_bypasses_cache_when_disabled()
- test_clear_cache_removes_cached_data()
- test_mesh_modifier_pipeline_executes_when_present()
- test_collision_generation_when_enabled()
- test_collision_skipped_when_disabled()
- test_processing_context_disposal_after_generation()
```

---

## Phase 2: Heightmap System (P1)

### 2.1 Heightmap Sources (P1)
**Files to create:**
- `test/unit/heightmap/test_heightmap_source.gd`
- `test/unit/heightmap/test_noise_heightmap_source.gd`
- `test/unit/heightmap/test_image_heightmap_source.gd`
- `test/unit/heightmap/test_composite_heightmap_source.gd`

**Test Coverage:**

#### `test_noise_heightmap_source.gd`
```gdscript
extends GutTest

# Test NoiseHeightmapSource
- test_generate_returns_image()
- test_generate_respects_context_size()
- test_seed_produces_different_results()
- test_same_seed_produces_same_results()
- test_get_metadata_returns_correct_info()
- test_export_to_png_creates_file()
```

#### `test_composite_heightmap_source.gd`
```gdscript
extends GutTest

# Test CompositeHeightmapSource
- test_generate_with_no_sources_returns_null()
- test_generate_with_single_source()
- test_generate_combines_multiple_sources()
- test_max_sources_limit_enforced()
- test_combiner_applied_correctly()
- test_signal_propagation_from_sources()
```

### 2.2 Heightmap Processors (P1)
**Files to create:**
- `test/unit/heightmap/test_blur_processor.gd`
- `test/unit/heightmap/test_normalization_processor.gd`
- `test/unit/heightmap/test_mask_processor.gd`

**Test Coverage:**

#### `test_blur_processor.gd`
```gdscript
extends GutTest

# Test BlurProcessor
- test_process_cpu_returns_blurred_image()
- test_blur_radius_affects_result()
- test_process_preserves_image_dimensions()
- test_edge_handling()
- test_gpu_fallback_to_cpu_when_unavailable()
```

#### `test_normalization_processor.gd`
```gdscript
extends GutTest

# Test NormalizationProcessor
- test_normalize_to_0_1_range()
- test_normalize_empty_image_handling()
- test_normalize_preserves_relative_values()
```

### 2.3 Heightmap Combiners (P1)
**Files to create:**
- `test/unit/heightmap/test_weighted_combiner.gd`
- `test/unit/heightmap/test_average_combiner.gd`
- `test/unit/heightmap/test_multiplication_combiner.gd`

**Test Coverage:**

#### `test_weighted_combiner.gd`
```gdscript
extends GutTest

# Test WeightedCombiner
- test_combine_with_equal_weights()
- test_combine_with_different_weights()
- test_combine_normalizes_weights()
- test_combine_with_missing_weights_uses_default()
- test_max_images_limit_enforced()
- test_combine_resizes_to_largest()
```

---

## Phase 3: Mesh Generation (P1)

### 3.1 Mesh Generators (P1)
**Files to create:**
- `test/unit/mesh/test_cpu_mesh_generator.gd`
- `test/unit/mesh/test_gpu_mesh_generator.gd` (if testable)

**Test Coverage:**

#### `test_cpu_mesh_generator.gd`
```gdscript
extends GutTest

# Test CPUMeshGenerator
- test_generate_mesh_creates_valid_result()
- test_vertex_positions_match_heightmap()
- test_height_scale_applied_correctly()
- test_uv_coordinates_preserved()
- test_grid_metadata_set_correctly()
- test_slope_normal_map_generated()
- test_vertex_to_uv_conversion()
- test_heightmap_sampling()
```

### 3.2 Mesh Calculators (P1)
**Files to create:**
- `test/unit/mesh/test_slope_computer.gd`
- `test/unit/mesh/test_mesh_normal_calculator.gd`
- `test/unit/mesh/test_mesh_tangent_calculator.gd`

**Test Coverage:**

#### `test_slope_computer.gd`
```gdscript
extends GutTest

# Test SlopeComputer
- test_compute_slope_normal_map_returns_image()
- test_flat_surface_has_zero_slope()
- test_steep_surface_has_high_slope()
- test_normal_calculation_accuracy()
- test_image_format_is_rgbaf()
- test_invalid_mesh_result_returns_null()
```

### 3.3 Mesh Utilities (P2)
**Files to create:**
- `test/unit/mesh/test_array_mesh_builder.gd`
- `test/unit/mesh/test_mesh_topology_modifier.gd`

---

## Phase 4: Mesh Modification Pipeline (P1)

### 4.1 Pipeline Core (P1)
**Files to create:**
- `test/unit/mesh_modifiers/test_mesh_modifier_pipeline.gd`
- `test/unit/mesh_modifiers/test_mesh_modifier_context.gd`
- `test/unit/mesh_modifiers/test_vertex_grid.gd`

**Test Coverage:**

#### `test_mesh_modifier_pipeline.gd`
```gdscript
extends GutTest

# Test MeshModifierPipeline orchestration
- test_execute_with_empty_stages()
- test_execute_with_single_stage()
- test_execute_with_multiple_stages()
- test_pipeline_validates_before_execution()
- test_disabled_stages_skipped()
- test_pipeline_signals_emit_correctly()
- test_pipeline_timeout_handling()
- test_stage_failure_handling()
- test_already_executing_error()
```

#### `test_vertex_grid.gd`
```gdscript
extends GutTest

# Test VertexGrid spatial indexing
- test_construction()
- test_build_from_mesh()
- test_get_moore_neighbours()
- test_get_von_neumann_neighbours()
- test_is_grid_vertex()
- test_get_grid_position()
- test_edge_vertices_have_fewer_neighbours()
- test_corner_vertices_handling()
```

### 4.2 Pipeline Stages (P1)
**Files to create:**
- `test/unit/mesh_modifiers/test_sequential_stage.gd`
- `test/unit/mesh_modifiers/test_parallel_stage.gd`
- `test/unit/mesh_modifiers/test_conditional_stage.gd`

**Test Coverage:**

#### `test_sequential_stage.gd`
```gdscript
extends GutTest

# Test SequentialStage execution
- test_executes_agents_in_order()
- test_context_passed_between_agents()
- test_failure_stops_execution()
- test_empty_agents_array()
```

### 4.3 Modification Agents (P2)
**Files to create:**
- `test/unit/mesh_modifiers/test_tunnel_boring_agent.gd`
- `test/unit/mesh_modifiers/test_terrain_raise_agent.gd`

**Test Coverage:**

#### `test_tunnel_boring_agent.gd`
```gdscript
extends GutTest

# Test TunnelBoringAgent
- test_validate_rejects_invalid_context()
- test_validate_rejects_invalid_dimensions()
- test_execute_finds_cliff_faces()
- test_tunnel_creation()
- test_placement_seed_determinism()
- test_min_cliff_height_filtering()
- test_min_cliff_angle_filtering()
```

### 4.4 Conditions (P2)
**Files to create:**
- `test/unit/mesh_modifiers/test_data_exists_condition.gd`

---

## Phase 5: Helpers & Utilities (P2)

### 5.1 Resource Helpers (P2)
**Files to create:**
- `test/unit/helpers/test_image_helper.gd`
- `test/unit/helpers/test_gpu_resource_helper.gd`
- `test/unit/helpers/test_gpu_texture_helper.gd`

**Test Coverage:**

#### `test_image_helper.gd`
```gdscript
extends GutTest

# Test ImageHelper utilities
- test_resize_images_to_largest()
- test_resize_with_single_image()
- test_resize_with_same_size_images()
- test_resize_with_different_sizes()
- test_interpolation_quality()
```

### 5.2 Debug Utilities (P3)
**Files to create:**
- `test/unit/debug/test_debug_image_exporter.gd`

---

## Phase 6: Integration & Edge Cases (P2-P3)

### 6.1 Integration Tests (P2)
**Files to create:**
- `test/unit/integration/test_end_to_end_generation.gd`
- `test/unit/integration/test_cpu_gpu_parity.gd`

**Test Coverage:**

#### `test_end_to_end_generation.gd`
```gdscript
extends GutTest

# Test complete generation pipeline
- test_simple_noise_terrain_generation()
- test_composite_heightmap_terrain()
- test_terrain_with_modifications()
- test_terrain_with_collision()
- test_caching_behavior()
```

#### `test_cpu_gpu_parity.gd`
```gdscript
extends GutTest

# Test CPU/GPU implementations produce similar results
- test_blur_processor_parity()
- test_mesh_generation_parity()
- test_slope_computation_parity()
```

### 6.2 Edge Cases & Error Handling (P3)
**Files to create:**
- `test/unit/edge_cases/test_null_inputs.gd`
- `test/unit/edge_cases/test_empty_data.gd`
- `test/unit/edge_cases/test_extreme_values.gd`

---

## Test Structure Template

Each test file should follow this structure:

```gdscript
extends GutTest

# Description of what this test suite covers
# File: path/to/tested/file.gd

# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

var test_subject  # The class/object being tested
var mock_context: ProcessingContext
var test_image: Image

func before_each():
	# Setup test fixtures
	test_subject = ClassUnderTest.new()
	mock_context = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
	test_image = Image.create(256, 256, false, Image.FORMAT_RF)
	# Initialize test data

func after_each():
	# Cleanup
	if mock_context:
		mock_context.dispose()
	test_subject = null

# ============================================================================
# CONSTRUCTION TESTS
# ============================================================================

func test_construction_creates_valid_object():
	assert_not_null(test_subject, "Should create valid object")

func test_default_values():
	assert_eq(test_subject.some_property, expected_value, "Should have default value")

# ============================================================================
# BEHAVIOR TESTS
# ============================================================================

func test_method_returns_expected_result():
	# Arrange
	var input = "test_input"
	
	# Act
	var result = test_subject.some_method(input)
	
	# Assert
	assert_eq(result, expected_output, "Should return correct result")

func test_method_handles_null_input():
	var result = test_subject.some_method(null)
	assert_null(result, "Should handle null gracefully")

# ============================================================================
# SIGNAL TESTS
# ============================================================================

func test_signal_emits_on_change():
	watch_signals(test_subject)
	test_subject.trigger_change()
	assert_signal_emitted(test_subject, "some_signal", "Should emit signal")

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

func test_error_handling_for_invalid_input():
	# This should log an error but not crash
	var result = test_subject.method_with_validation(invalid_input)
	assert_null(result, "Should return null for invalid input")
```

---

## Testing Utilities to Create

### Helper File: `test/unit/test_helpers.gd`

```gdscript
class_name TestHelpers

# Create a simple test heightmap with gradient
static func create_test_heightmap(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RF)
	for y in height:
		for x in width:
			var value := float(x) / width
			img.set_pixel(x, y, Color(value, 0, 0))
	return img

# Create a flat heightmap
static func create_flat_heightmap(width: int, height: int, value: float = 0.5) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RF)
	for y in height:
		for x in width:
			img.set_pixel(x, y, Color(value, 0, 0))
	return img

# Create simple mesh data for testing
static func create_test_mesh_data(grid_size: int = 10) -> MeshData:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	
	# Create simple grid
	for y in grid_size:
		for x in grid_size:
			vertices.append(Vector3(x, 0, y))
			uvs.append(Vector2(float(x) / grid_size, float(y) / grid_size))
	
	# Create indices for triangles
	for y in grid_size - 1:
		for x in grid_size - 1:
			var i := y * grid_size + x
			indices.append(i)
			indices.append(i + grid_size)
			indices.append(i + 1)
			indices.append(i + 1)
			indices.append(i + grid_size)
			indices.append(i + grid_size + 1)
	
	return MeshData.new(vertices, indices, uvs)

# Compare two images with tolerance
static func images_are_similar(img1: Image, img2: Image, tolerance: float = 0.01) -> bool:
	if img1.get_size() != img2.get_size():
		return false
	
	var width := img1.get_width()
	var height := img1.get_height()
	
	for y in height:
		for x in width:
			var color1 := img1.get_pixel(x, y)
			var color2 := img2.get_pixel(x, y)
			if abs(color1.r - color2.r) > tolerance:
				return false
	
	return true
```

---

## Execution Strategy

### Week 1-2: Foundation (Phase 1)
1. Set up test infrastructure
2. Create test helper utilities
3. Implement P0 data structure tests
4. Implement P0 core service tests
5. Target: ~8-10 test files

### Week 3-4: Heightmap System (Phase 2)
1. Implement heightmap source tests
2. Implement processor tests
3. Implement combiner tests
4. Target: ~9-12 test files

### Week 5-6: Mesh Generation (Phase 3)
1. Implement mesh generator tests
2. Implement calculator tests
3. Implement utility tests
4. Target: ~6-8 test files

### Week 7-8: Mesh Modification (Phase 4)
1. Implement pipeline core tests
2. Implement stage tests
3. Implement agent tests
4. Target: ~8-10 test files

### Week 9: Helpers & Integration (Phase 5-6)
1. Implement helper tests
2. Implement integration tests
3. Target: ~5-7 test files

### Week 10: Polish & Edge Cases
1. Implement edge case tests
2. Improve coverage
3. Fix any failing tests
4. Documentation

---

## Coverage Goals

- **Minimum Coverage**: 70% of critical paths
- **Target Coverage**: 85% of all code paths
- **Focus Areas**:
  - All public methods
  - Error handling paths
  - Edge cases (null, empty, extreme values)
  - Signal emissions
  - Resource cleanup

---

## Tools & Automation

### Running Tests
```bash
# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit

# Run specific test file
godot --headless -s addons/gut/gut_cmdln.gd -gtest=test_terrain_data.gd

# Run with output
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
```

### Continuous Integration
- Set up GitHub Actions or similar CI
- Run tests on every commit
- Fail builds on test failures
- Generate coverage reports

---

## Notes & Considerations

### GPU Testing Challenges
- GPU tests may not run in headless/CI environment
- Consider mocking GPU functionality for CI
- Test GPU fallback to CPU paths
- Mark GPU-specific tests with `skip_test_when_not_supported()`

### Resource Cleanup
- Always dispose ProcessingContext in `after_each()`
- Free GPU resources properly
- Watch for memory leaks

### Test Data
- Keep test images small (64x64 or 128x128)
- Use deterministic seeds for reproducibility
- Store expected results for regression testing

### Mock Objects
- Consider creating mock implementations for:
  - `HeightmapSource` (simple test patterns)
  - `MeshModifierAgent` (no-op or simple agents)
  - `ProcessingContext` (CPU-only for CI)

---

## Success Metrics

- [ ] All P0 tests implemented and passing
- [ ] All P1 tests implemented and passing
- [ ] Code coverage > 70%
- [ ] No memory leaks detected
- [ ] Tests run in < 5 minutes
- [ ] CI pipeline configured and green
- [ ] Documentation complete

---

## References

- [GUT Documentation](https://gut.readthedocs.io/en/latest/)
- [GutTest Class Reference](https://gut.readthedocs.io/en/latest/class_ref/class_guttest.html)
- [Godot Testing Best Practices](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html#testing)

---

**Last Updated**: December 11, 2025  
**Document Version**: 1.0
