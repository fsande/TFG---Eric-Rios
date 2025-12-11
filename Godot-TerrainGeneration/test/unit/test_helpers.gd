## @brief Helper utilities for unit tests.
## @details Provides factory methods for creating test data and comparison utilities.
class_name TestHelpers

## Create a simple test heightmap with a horizontal gradient.
## Values increase from 0.0 (left) to 1.0 (right).
static func create_test_heightmap(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RF)
	for y in height:
		for x in width:
			var value := float(x) / float(width - 1) if width > 1 else 0.5
			img.set_pixel(x, y, Color(value, 0, 0))
	return img

## Create a flat heightmap with uniform height value.
static func create_flat_heightmap(width: int, height: int, value: float = 0.5) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RF)
	for y in height:
		for x in width:
			img.set_pixel(x, y, Color(value, 0, 0))
	return img

## Create a test heightmap with a diagonal gradient from bottom-left to top-right.
static func create_diagonal_heightmap(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RF)
	for y in height:
		for x in width:
			var value := (float(x + y) / float(width + height - 2)) if (width + height > 2) else 0.5
			img.set_pixel(x, y, Color(value, 0, 0))
	return img

## Create simple mesh data for testing with a regular grid.
static func create_test_mesh_data(grid_size: int = 10) -> MeshData:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	for y in grid_size:
		for x in grid_size:
			vertices.append(Vector3(float(x), 0.0, float(y)))
			uvs.append(Vector2(float(x) / float(grid_size - 1), float(y) / float(grid_size - 1)))
	for y in (grid_size - 1):
		for x in (grid_size - 1):
			var i := y * grid_size + x
			indices.append(i)
			indices.append(i + grid_size)
			indices.append(i + 1)
			indices.append(i + 1)
			indices.append(i + grid_size)
			indices.append(i + grid_size + 1)
	var mesh_data := MeshData.new(vertices, indices, uvs)
	mesh_data.width = grid_size
	mesh_data.height = grid_size
	return mesh_data

## Create a test MeshGenerationResult with specified dimensions.
static func create_test_mesh_generation_result(width: int = 10, height: int = 10) -> MeshGenerationResult:
	var mesh_data := create_test_mesh_data(width)
	var result := MeshGenerationResult.new(
		mesh_data.vertices,
		mesh_data.indices,
		mesh_data.uvs,
		0.0,
		"CPU"
	)
	result.width = width
	result.height = height
	result.mesh_size = Vector2(100.0, 100.0)
	return result

## Create a test ProcessingContext for CPU processing.
static func create_test_context_cpu(terrain_size: float = 512.0, p_seed: int = 42) -> ProcessingContext:
	return ProcessingContext.new(terrain_size, p_seed, ProcessingContext.ProcessorType.CPU)

## Create a test ProcessingContext for GPU processing (may fall back to CPU if GPU unavailable).
static func create_test_context_gpu(terrain_size: float = 512.0, p_seed: int = 42) -> ProcessingContext:
	return ProcessingContext.new(terrain_size, p_seed, ProcessingContext.ProcessorType.GPU)

## Create test MeshGeneratorParameters with reasonable defaults.
static func create_test_mesh_parameters() -> MeshGeneratorParameters:
	var params := MeshGeneratorParameters.new()
	params.mesh_size = Vector2(512.0, 512.0)
	params.subdivisions = 64
	params.height_scale = 100.0
	return params

## Compare two images with tolerance for floating-point differences.
## Returns true if images are similar within the given tolerance.
static func images_are_similar(img1: Image, img2: Image, tolerance: float = 0.01) -> bool:
	if img1 == null or img2 == null:
		return false
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

## Compare two float values with tolerance.
static func floats_are_close(a: float, b: float, tolerance: float = 0.001) -> bool:
	return abs(a - b) <= tolerance

## Compare two Vector3 values with tolerance.
static func vectors_are_close(a: Vector3, b: Vector3, tolerance: float = 0.001) -> bool:
	return floats_are_close(a.x, b.x, tolerance) and \
		   floats_are_close(a.y, b.y, tolerance) and \
		   floats_are_close(a.z, b.z, tolerance)

## Get the average value of all pixels in a heightmap.
static func get_average_height(heightmap: Image) -> float:
	if heightmap == null:
		return 0.0
	var sum := 0.0
	var width := heightmap.get_width()
	var height := heightmap.get_height()
	for y in height:
		for x in width:
			sum += heightmap.get_pixel(x, y).r
	return sum / float(width * height)

## Get the minimum value in a heightmap.
static func get_min_height(heightmap: Image) -> float:
	if heightmap == null:
		return 0.0
	var min_val := INF
	var width := heightmap.get_width()
	var height := heightmap.get_height()
	for y in height:
		for x in width:
			var val := heightmap.get_pixel(x, y).r
			if val < min_val:
				min_val = val
	return min_val

## Get the maximum value in a heightmap.
static func get_max_height(heightmap: Image) -> float:
	if heightmap == null:
		return 0.0
	var max_val := -INF
	var width := heightmap.get_width()
	var height := heightmap.get_height()
	for y in height:
		for x in width:
			var val := heightmap.get_pixel(x, y).r
			if val > max_val:
				max_val = val
	return max_val
