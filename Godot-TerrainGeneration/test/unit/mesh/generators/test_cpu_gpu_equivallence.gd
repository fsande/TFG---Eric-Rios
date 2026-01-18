extends GutTest

var cpu_generator: CpuMeshGenerator
var gpu_generator: GpuMeshGenerator
var plane: PlaneMesh

func before_each():
	cpu_generator = CpuMeshGenerator.new()
	gpu_generator = GpuMeshGenerator.new()
	plane = PlaneMesh.new()

func after_each():
	cpu_generator = null
	gpu_generator = null
	plane = null
	
func test_cpu_gpu_equivalence_small():
	parametric_equivalence_test(64, Vector2(256, 256), 256, 50.0, 16)
	
func test_cpu_gpu_equivalence_medium():
	parametric_equivalence_test(128, Vector2(512, 512), 512, 100.0, 32)

func test_cpu_gpu_equivalence_large():
	parametric_equivalence_test(256, Vector2(1024, 1024), 1024, 200.0, 64)

## Parametric test function to compare CPU and GPU mesh generation results.
## Default tolerance is reasonable for floating-point comparisons, especially as operations on CPU vs GPU may yield slightly different results.
func parametric_equivalence_test(heightmap_size: int, terrain_size: Vector2, mesh_size: int, height_scale: float, subdivisions: int, tolerance: float = 1e-2):
	var heightmap := TestHelpers.create_noisy_heightmap(heightmap_size)
	var context_cpu := TestHelpers.create_test_processing_context(
		terrain_size,
		ProcessingContext.ProcessorType.CPU,
		ProcessingContext.ProcessorType.CPU,
		subdivisions,
		mesh_size,
		height_scale
	)
	var context_gpu := TestHelpers.create_test_processing_context(
		terrain_size,
		ProcessingContext.ProcessorType.GPU,
		ProcessingContext.ProcessorType.GPU,
		subdivisions,
		mesh_size,
		height_scale
	)
	plane.subdivide_depth = subdivisions
	plane.subdivide_width = subdivisions
	plane.size = Vector2(mesh_size, mesh_size)
	var mesh_arrays := plane.get_mesh_arrays()
	var cpu_result := cpu_generator.generate_mesh(mesh_arrays, heightmap, context_cpu)
	var gpu_result := gpu_generator.generate_mesh(mesh_arrays, heightmap, context_gpu)
	assert_not_null(cpu_result, "CPU mesh generation should succeed")
	assert_not_null(gpu_result, "GPU mesh generation should succeed")
	assert_eq(cpu_result.width, gpu_result.width, "Mesh widths should match")
	assert_eq(cpu_result.height, gpu_result.height, "Mesh heights should match")
	assert_eq(cpu_result.mesh_size, gpu_result.mesh_size, "Mesh sizes should match")
	assert_eq(cpu_result.vertices.size(), gpu_result.vertices.size(), "Vertex counts should match")
	assert_eq(cpu_result.indices.size(), gpu_result.indices.size(), "Index counts should match")
	assert_true(TestHelpers.compare_vector3_arrays(cpu_result.vertices, gpu_result.vertices, tolerance), "Vertex arrays should be similar within tolerance %f" % tolerance)
	assert_true(TestHelpers.compare_vector2_arrays(cpu_result.uvs, gpu_result.uvs, tolerance), "UV arrays should be similar within tolerance %f" % tolerance)
	if cpu_result.slope_normal_map != null and gpu_result.slope_normal_map != null:
		assert_true(TestHelpers.images_are_similar(cpu_result.slope_normal_map, gpu_result.slope_normal_map, tolerance), "Slope normal maps should be similar within tolerance %f" % tolerance)
	for i in cpu_result.indices.size():
		var cpu_index := cpu_result.indices[i]
		var gpu_index := gpu_result.indices[i]
		assert_eq(cpu_index, gpu_index, "Index %d should match" % i)