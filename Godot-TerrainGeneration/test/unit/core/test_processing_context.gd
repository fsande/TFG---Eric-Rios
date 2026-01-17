extends GutTest

var context_cpu: ProcessingContext
var context_gpu: ProcessingContext

func after_each():
	if context_cpu and not context_cpu._is_disposed:
		context_cpu.dispose()
	if context_gpu and not context_gpu._is_disposed:
		context_gpu.dispose()
	context_cpu = null
	context_gpu = null

func test_construction_with_valid_parameters():
	context_cpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 42)
	assert_not_null(context_cpu, "Should create valid ProcessingContext")
	assert_eq(context_cpu.terrain_size, 512.0, "Should store terrain_size")
	assert_eq(context_cpu.generation_seed, 42, "Should store generation_seed")
	assert_eq(context_cpu.heightmap_processor_type, ProcessingContext.ProcessorType.CPU, "Should store CPU processor_type")

func test_construction_rejects_negative_terrain_size():
	context_cpu = ProcessingContext.new(-100.0, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 42)
	assert_push_error("terrain_size must be positive")
	assert_eq(context_cpu.terrain_size, 256.0, "Should default to 256.0 for invalid input")

func test_construction_rejects_zero_terrain_size():
	context_cpu = ProcessingContext.new(0.0, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 42)
	assert_push_error("terrain_size must be positive")
	assert_eq(context_cpu.terrain_size, 256.0, "Should default to 256.0 for zero")

func test_construction_rejects_negative_seed():
	context_cpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, -1)
	assert_push_error("generation_seed must be non-negative")
	assert_eq(context_cpu.generation_seed, 0, "Should default to 0 for negative seed")

func test_use_gpu_returns_false_for_cpu_context():
	context_cpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 42)
	assert_false(context_cpu.heightmap_use_gpu(), "Should return false for CPU context")
	assert_null(context_cpu.rendering_device, "CPU context should not have RenderingDevice")

func test_gpu_context_initializes_rendering_device_or_falls_back():
	context_gpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.GPU, ProcessingContext.ProcessorType.GPU, 42)
	if context_gpu.heightmap_use_gpu():
		assert_not_null(context_gpu.rendering_device, "GPU context should have RenderingDevice when available")
		assert_eq(context_gpu.heightmap_processor_type, ProcessingContext.ProcessorType.GPU, "Should remain GPU type")
	else:
		assert_eq(context_gpu.heightmap_processor_type, ProcessingContext.ProcessorType.CPU, "Should fallback to CPU when GPU unavailable")

func test_shader_operations_fail_gracefully_on_cpu():
	context_cpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 42)
	var shader := context_cpu.get_or_create_shader(TestHelpers.SHADER_EXISTENT)
	assert_engine_error("Attempted to load shader without GPU")
	assert_false(shader.is_valid(), "Should return invalid RID for CPU context")
	assert_false(context_cpu.heightmap_use_gpu(), "Should still report CPU mode after shader error")

func test_shader_cache_handles_missing_files():
	context_gpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.GPU, ProcessingContext.ProcessorType.GPU, 42)
	if not context_gpu.heightmap_use_gpu():
		pass_test("GPU not available, skipping GPU shader test")
		return
	var shader := context_gpu.get_or_create_shader(TestHelpers.SHADER_NONEXISTENT)
	assert_push_error("Shader not found")
	assert_false(shader.is_valid(), "Should return invalid RID for nonexistent shader")
	assert_eq(context_gpu._shader_cache.size(), 0, "Failed shaders should not be cached")

func test_shader_cache_reuses_compiled_shaders():
	context_gpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.GPU, ProcessingContext.ProcessorType.GPU, 42)
	if not context_gpu.heightmap_use_gpu():
		pass_test("GPU not available, skipping shader cache test")
		return
	var initial_size := context_gpu._shader_cache.size()
	var shader1 := context_gpu.get_or_create_shader(TestHelpers.SHADER_EXISTENT)
	var shader2 := context_gpu.get_or_create_shader(TestHelpers.SHADER_EXISTENT)
	assert_eq(shader1.get_id(), shader2.get_id(), "Should return same RID from cache")
	assert_eq(context_gpu._shader_cache.size(), initial_size + 1, "Should cache exactly one shader")

func test_dispose_prevents_further_operations():
	context_cpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 42)
	context_cpu.dispose()
	assert_true(context_cpu._is_disposed, "Should mark context as disposed")
	var result := context_cpu.heightmap_use_gpu()
	assert_false(result, "use_gpu should return false")
	var rd := context_cpu.get_rendering_device()
	assert_push_error("Attempted to access disposed context")
	assert_null(rd, "get_rendering_device should return null")
	var shader := context_cpu.get_or_create_shader(TestHelpers.SHADER_EXISTENT)
	assert_push_error(3, "Attempted to use disposed context")
	assert_false(shader.is_valid(), "get_or_create_shader should return invalid RID")

func test_dispose_is_idempotent():
	context_cpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 42)
	context_cpu.dispose()
	context_cpu.dispose()
	context_cpu.dispose()
	assert_true(context_cpu._is_disposed, "Multiple disposals should not crash")

func test_dispose_cleans_up_gpu_resources():
	context_gpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.GPU, ProcessingContext.ProcessorType.GPU, 42)
	if context_gpu.heightmap_use_gpu():
		var shader := context_gpu.get_or_create_shader(TestHelpers.SHADER_EXISTENT)
		assert_gt(context_gpu._shader_cache.size(), 0, "Should have cached shaders")
	context_gpu.dispose()
	assert_eq(context_gpu._shader_cache.size(), 0, "Should clear shader cache on disposal")
	assert_null(context_gpu.rendering_device, "Should clear rendering device")

func test_context_tracks_mesh_parameters():
	context_cpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 42)
	var params := MeshGeneratorParameters.new()
	params.mesh_size = Vector2(1024.0, 1024.0)
	params.subdivisions = 128
	context_cpu.mesh_parameters = params
	assert_same(context_cpu.mesh_parameters, params, "Should store exact parameter reference")
	context_cpu.heightmap_use_gpu()
	assert_same(context_cpu.mesh_parameters, params, "Parameters should survive operations")

func test_context_tracks_gpu_memory_allocation():
	context_cpu = ProcessingContext.new(512.0, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 42)
	assert_eq(context_cpu.get_gpu_memory_usage(), 0, "Should start with zero GPU memory")
	context_cpu.track_gpu_allocation(1024)
	assert_eq(context_cpu.get_gpu_memory_usage(), 1024, "Should track allocations")
	context_cpu.track_gpu_allocation(2048)
	assert_eq(context_cpu.get_gpu_memory_usage(), 3072, "Should accumulate allocations")
