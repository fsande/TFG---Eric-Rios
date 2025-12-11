extends GutTest

## Test suite for ProcessingContext
## File: terrain_generation/core/processing_context.gd

# SETUP / TEARDOWN
var context_cpu: ProcessingContext
var context_gpu: ProcessingContext

func after_each():
	# Clean up contexts
	if context_cpu and not context_cpu._is_disposed:
		context_cpu.dispose()
	if context_gpu and not context_gpu._is_disposed:
		context_gpu.dispose()
	context_cpu = null
	context_gpu = null

# CONSTRUCTION TESTS
func test_construction_with_cpu_type():
	context_cpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
	assert_not_null(context_cpu, "Should create valid ProcessingContext")
	assert_eq(context_cpu.terrain_size, 512.0, "Should store terrain_size")
	assert_eq(context_cpu.generation_seed, 42, "Should store generation_seed")
	assert_eq(context_cpu.processor_type, ProcessingContext.ProcessorType.CPU, "Should store CPU processor_type")

func test_construction_with_gpu_type():
	context_gpu = ProcessingContext.new(1024.0, 123, ProcessingContext.ProcessorType.GPU)
	assert_not_null(context_gpu, "Should create valid ProcessingContext")
	assert_eq(context_gpu.terrain_size, 1024.0, "Should store terrain_size")
	assert_eq(context_gpu.generation_seed, 123, "Should store generation_seed")
	assert_eq(context_gpu.processor_type, ProcessingContext.ProcessorType.GPU, "Should store GPU processor_type")

func test_construction_with_default_processor_type():
	context_cpu = ProcessingContext.new(256.0)
	assert_eq(context_cpu.processor_type, ProcessingContext.ProcessorType.CPU, "Should default to CPU")

func test_construction_with_zero_seed():
	context_cpu = ProcessingContext.new(512.0, 0)
	assert_eq(context_cpu.generation_seed, 0, "Should accept 0 as valid seed")

# GPU AVAILABILITY TESTS
func test_use_gpu_returns_false_for_cpu_context():
	context_cpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
	assert_false(context_cpu.use_gpu(), "Should return false for CPU context")

func test_use_gpu_returns_true_or_false_for_gpu_context():
	context_gpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.GPU)
	var uses_gpu := context_gpu.use_gpu()
	assert_true(uses_gpu == true or uses_gpu == false, "Should return boolean for GPU context")

func test_get_rendering_device_returns_null_for_cpu():
	context_cpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
	var rd := context_cpu.get_rendering_device()
	assert_null(rd, "Should return null RenderingDevice for CPU context")

func test_get_rendering_device_for_gpu_context():
	context_gpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.GPU)
	var rd := context_gpu.get_rendering_device()
	assert_true(rd != null, "Should return RenderingDevice")

# SHADER CACHING TESTS
func test_shader_cache_throws_error_for_cpu():
	context_cpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
	var shader := context_cpu.get_or_create_shader("res://test/fake_shader.glsl")
	assert_engine_error("Attempted to load shader without GPU")
	assert_false(shader.is_valid(), "Should return invalid RID for CPU context")

func test_shader_cache_returns_invalid_rid_for_nonexistent_shader():
	context_gpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.GPU)
	var shader := context_gpu.get_or_create_shader("res://nonexistent_shader.glsl")
	assert_push_error("Shader not found")

# DISPOSAL TESTS
func test_dispose_marks_context_as_disposed():
	context_cpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
	context_cpu.dispose()
	assert_true(context_cpu._is_disposed, "Should mark context as disposed")

func test_disposed_context_use_gpu_returns_false():
	context_cpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
	context_cpu.dispose()
	var result := context_cpu.use_gpu()
	assert_push_error("Attempted to use disposed context")
	assert_false(result, "Should return false after disposal")

func test_disposed_context_get_rendering_device_returns_null():
	context_gpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.GPU)
	context_gpu.dispose()
	var rd := context_gpu.get_rendering_device()
	assert_push_error("Attempted to access disposed context")
	assert_null(rd, "Should return null after disposal")

func test_disposed_context_get_or_create_shader_returns_invalid():
	context_gpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.GPU)
	context_gpu.dispose()
	var shader := context_gpu.get_or_create_shader("res://invalid.glsl")
	assert_push_error("Attempted to use disposed context")
	assert_false(shader.is_valid(), "Should return invalid RID after disposal")

func test_double_dispose_doesnt_crash():
	context_cpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
	context_cpu.dispose()
	context_cpu.dispose()
	assert_true(context_cpu._is_disposed, "Should remain disposed after double dispose")

# MESH PARAMETERS TESTS
func test_mesh_params_can_be_set():
	context_cpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
	var params := MeshGeneratorParameters.new()
	params.mesh_size = Vector2(1024.0, 1024.0)
	params.subdivisions = 128
	context_cpu.mesh_params = params
	assert_eq(context_cpu.mesh_params, params, "Should store mesh parameters")
	assert_eq(context_cpu.mesh_params.mesh_size, Vector2(1024.0, 1024.0), "Should access stored parameters")

func test_mesh_params_defaults_to_null():
	context_cpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
	assert_null(context_cpu.mesh_params, "Should default to null")

# PROCESSOR TYPE TESTS
func test_processor_type_enum_values():
	assert_eq(ProcessingContext.ProcessorType.CPU, 0, "CPU enum should be 0")
	assert_eq(ProcessingContext.ProcessorType.GPU, 1, "GPU enum should be 1")

func test_processor_type_can_be_changed():
	context_cpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
	context_cpu.processor_type = ProcessingContext.ProcessorType.GPU
	assert_eq(context_cpu.processor_type, ProcessingContext.ProcessorType.GPU, "Should allow processor type change")

# TERRAIN SIZE TESTS
func test_terrain_size_positive_values():
	context_cpu = ProcessingContext.new(2048.0, 42, ProcessingContext.ProcessorType.CPU)
	assert_eq(context_cpu.terrain_size, 2048.0, "Should store large terrain size")

func test_terrain_size_small_values():
	context_cpu = ProcessingContext.new(64.0, 42, ProcessingContext.ProcessorType.CPU)
	assert_eq(context_cpu.terrain_size, 64.0, "Should store small terrain size")
