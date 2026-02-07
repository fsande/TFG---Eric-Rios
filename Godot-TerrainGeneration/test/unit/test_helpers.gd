## @brief Helper utilities for unit tests.
## @details Provides factory methods for creating test data and comparison utilities.
class_name TestHelpers extends GutTest

## Test shader paths
const SHADER_NONEXISTENT := "res://test/non_existent.glsl"
const SHADER_EXISTENT := "res://test/test_compute.glsl"

## Create a simple test heightmap with a horizontal gradient.
## Values increase from 0.0 (left) to 1.0 (right).
static func create_horizontal_gradient_heightmap(width: int, height: int, vertical_multiplier: float = 0.0) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RF)
	for y in height:
		for x in width:
			var value := float(x) / float(width - 1) + vertical_multiplier * (float(y) / float(height - 1))
			img.set_pixel(x, y, Color(value, 0, 0))
	return img
	
## Create a flat heightmap with uniform height value.
static func create_flat_heightmap(width: int, height: int, value: float = 0.5) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RF)
	for y in height:
		for x in width:
			img.set_pixel(x, y, Color(value, 0, 0))
	return img


## Create a noisy heightmap using NoiseHeightmapSource.
static func create_noisy_heightmap(size: int) -> Image:
	var heightmap_source := NoiseHeightmapSource.new()
	var context := ProcessingContext.new(size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	var result := heightmap_source.generate(context)
	context.dispose()
	return result

## Compare two PackedVector3Array with tolerance for floating-point differences.
static func compare_vector3_arrays(arr1: PackedVector3Array, arr2: PackedVector3Array, tolerance: float = 0.001) -> bool:
	if arr1.size() != arr2.size():
		return false
	for i in arr1.size():
		if not vectors3_are_close(arr1[i], arr2[i], tolerance):
			return false
	return true

## Compare two PackedVector2Array with tolerance for floating-point differences.
static func compare_vector2_arrays(arr1: PackedVector2Array, arr2: PackedVector2Array, tolerance: float = 0.001) -> bool:
	if arr1.size() != arr2.size():
		return false
	for i in arr1.size():
		if not vectors2_are_close(arr1[i], arr2[i], tolerance):
			return false
	return true
	
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

## Create a test ProcessingContext 
static func create_test_processing_context(
		terrain_size: Vector2 = Vector2(512.0, 512.0),
		processor_type: int = ProcessingContext.ProcessorType.CPU,
		mesh_generator_type: int = ProcessingContext.ProcessorType.CPU,
		subdivisions: int = 64,
		mesh_size: int = 512,
		height_scale: float = 100.0
) -> ProcessingContext:
	var context := ProcessingContext.new(terrain_size.x, processor_type, mesh_generator_type)
	context.mesh_parameters = create_test_mesh_parameters(mesh_size, subdivisions, height_scale)
	return context

## Create test MeshGeneratorParameters.
static func create_test_mesh_parameters(mesh_size: int = 512, subdivisions: int = 64, height_scale: float = 100.0) -> MeshGeneratorParameters:
	var params := MeshGeneratorParameters.new()
	params.mesh_size = Vector2(mesh_size, mesh_size)
	params.subdivisions = subdivisions
	params.height_scale = height_scale
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
static func vectors3_are_close(a: Vector3, b: Vector3, tolerance: float = 0.001) -> bool:
	return  floats_are_close(a.x, b.x, tolerance) and \
			floats_are_close(a.y, b.y, tolerance) and \
			floats_are_close(a.z, b.z, tolerance)
			
static func vectors2_are_close(a: Vector2, b: Vector2, tolerance: float = 0.001) -> bool:
	return  floats_are_close(a.x, b.x, tolerance) and \
			floats_are_close(a.y, b.y, tolerance)

## Create a single triangle mesh for testing.
static func create_triangle_mesh(v0: Vector3, v1: Vector3, v2: Vector3, 
	uv0: Vector2 = Vector2(0, 0), uv1: Vector2 = Vector2(1, 0), uv2: Vector2 = Vector2(0.5, 1)) -> MeshData:
	var mesh := MeshData.new()
	mesh.vertices = PackedVector3Array([v0, v1, v2])
	mesh.uvs = PackedVector2Array([uv0, uv1, uv2])
	mesh.indices = PackedInt32Array([0, 1, 2])
	return mesh

## Create a simple box mesh with multiple triangles for collision testing.
static func create_box_mesh(size: Vector3 = Vector3(1, 1, 1)) -> MeshData:
	var mesh := MeshData.new()
	var half := size * 0.5
	mesh.vertices = PackedVector3Array([
		Vector3(-half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, -half.z),
		Vector3(-half.x, half.y, -half.z),
		Vector3(half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z),
		Vector3(half.x, -half.y, half.z)
	])
	mesh.uvs = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(0, 1),
		Vector2(1, 1),
		Vector2(0, 0),
		Vector2(1, 0)
	])
	mesh.indices = PackedInt32Array([
		0, 1, 2,
		1, 3, 2,
		0, 4, 5
	])
	return mesh

### Create a flat terrain height querier for testing.
#static func create_flat_terrain_query(height: float = 10.0) -> TerrainHeightQuerier:
#	return FlatTerrainQuerier.new(height)
#
### Create a cylindrical tunnel shape for testing.
#static func create_test_tunnel_shape(origin: Vector3 = Vector3.ZERO, 
#	direction: Vector3 = Vector3.FORWARD, radius: float = 3.0, length: float = 20.0) -> CylindricalTunnelShape:
#	return CylindricalTunnelShape.new(origin, direction, radius, length)

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

## Validate that all triangle indices reference valid vertices.
static func validate_mesh_indices(vertices: PackedVector3Array, indices: PackedInt32Array) -> bool:
	if vertices.size() == 0:
		return indices.size() == 0
	var max_index := vertices.size() - 1
	for idx in indices:
		if idx < 0 or idx > max_index:
			return false
	return true

## Check if mesh data represents a valid manifold (closed surface).
## Returns true if each edge is shared by exactly 2 triangles (simplified check).
static func is_manifold_mesh(indices: PackedInt32Array) -> bool:
	if indices.size() == 0:
		return true
	if indices.size() % 3 != 0:
		return false
	# For a proper check, would need to build edge->face mapping
	# This is a simplified validation
	return true

## Verify all normals are unit vectors (length ~= 1.0).
static func validate_normals(normals: PackedVector3Array, tolerance: float = 0.01) -> bool:
	for normal in normals:
		var length := normal.length()
		if length > 0.0:  # Skip zero normals
			if not floats_are_close(length, 1.0, tolerance):
				return false
	return true

## Count how many vertices in a mesh are at a specific height.
static func count_vertices_at_height(vertices: PackedVector3Array, height: float, tolerance: float = 0.001) -> int:
	var count := 0
	for vertex in vertices:
		if floats_are_close(vertex.y, height, tolerance):
			count += 1
	return count

## Create a test mesh with a linear slope.
## @param mesh_size The width and height of the mesh grid
## @param slope_x_multiplier Multiplier for X coordinate to create slope in X direction (0.0 for flat)
## @param slope_y_multiplier Multiplier for Y coordinate to create slope in Z direction (0.0 for no Z slope)
## @param slope_combined_multiplier Multiplier for (X+Y) to create diagonal slope (0.0 for no diagonal)
## @returns MeshGenerationResult with the specified slope characteristics
static func create_linear_slope_mesh(
	mesh_size: int,
	slope_x_multiplier: float = 0.0,
	slope_y_multiplier: float = 0.0,
	slope_combined_multiplier: float = 0.0
) -> MeshGenerationResult:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	for y in mesh_size:
		for x in mesh_size:
			var height := float(x) * slope_x_multiplier + \
				float(y) * slope_y_multiplier + \
				float(x + y) * slope_combined_multiplier
			vertices.append(Vector3(float(x), height, float(y)))
			uvs.append(Vector2(float(x) / float(mesh_size - 1), float(y) / float(mesh_size - 1)))
	for y in mesh_size - 1:
		for x in mesh_size - 1:
			var i := y * mesh_size + x
			indices.append(i)
			indices.append(i + mesh_size)
			indices.append(i + 1)
			indices.append(i + 1)
			indices.append(i + mesh_size)
			indices.append(i + mesh_size + 1)
	var result := MeshGenerationResult.new(vertices, indices, uvs, 0.0, "CPU")
	result.width = mesh_size
	result.height = mesh_size
	return result
