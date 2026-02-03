## @brief Unit tests for Phase 2 chunk generation system.
extends GutTest

var _terrain_definition: TerrainDefinition = null
var _generator: ChunkGenerator = null

func before_each() -> void:
	var source := NoiseHeightmapSource.new()
	source.resolution = 64
	source.frequency = 2.0
	_terrain_definition = TerrainDefinition.create(
		source,
		Vector2(256, 256),
		32.0,
		12345
	)
	_generator = ChunkGenerator.new(_terrain_definition, 32)

func after_each() -> void:
	if _terrain_definition:
		_terrain_definition.clear_cache()
		_terrain_definition = null
	_generator = null

func test_chunk_generator_creation() -> void:
	assert_not_null(_generator, "Generator should be created")

func test_generate_single_chunk() -> void:
	var chunk := _generator.generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	assert_not_null(chunk, "Chunk should be generated")
	assert_not_null(chunk.mesh_data, "Chunk should have mesh data")
	assert_gt(chunk.mesh_data.vertices.size(), 0, "Chunk should have vertices")
	assert_gt(chunk.mesh_data.indices.size(), 0, "Chunk should have indices")
	assert_eq(chunk.chunk_coord, Vector2i(0, 0), "Chunk coord should match")

func test_generate_chunk_at_different_lods() -> void:
	var chunk_lod0 := _generator.generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	var chunk_lod1 := _generator.generate_chunk(Vector2i(0, 0), Vector2(64, 64), 1)
	var chunk_lod2 := _generator.generate_chunk(Vector2i(0, 0), Vector2(64, 64), 2)
	assert_not_null(chunk_lod0, "LOD 0 chunk should exist")
	assert_not_null(chunk_lod1, "LOD 1 chunk should exist")
	assert_not_null(chunk_lod2, "LOD 2 chunk should exist")
	assert_gt(chunk_lod0.mesh_data.vertices.size(), chunk_lod1.mesh_data.vertices.size(),
		"LOD 0 should have more vertices than LOD 1")
	assert_gt(chunk_lod1.mesh_data.vertices.size(), chunk_lod2.mesh_data.vertices.size(),
		"LOD 1 should have more vertices than LOD 2")

func test_generate_multiple_chunks() -> void:
	var chunks: Array[ChunkMeshData] = []
	for z in range(2):
		for x in range(2):
			var chunk := _generator.generate_chunk(Vector2i(x, z), Vector2(64, 64), 0)
			assert_not_null(chunk, "Chunk at (%d, %d) should exist" % [x, z])
			chunks.append(chunk)
	assert_eq(chunks.size(), 4, "Should have 4 chunks")
	for i in range(chunks.size()):
		for j in range(i + 1, chunks.size()):
			assert_ne(chunks[i].chunk_coord, chunks[j].chunk_coord,
				"Chunks should have different coords")

func test_chunk_has_correct_grid_structure() -> void:
	var chunk := _generator.generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	assert_not_null(chunk, "Chunk should exist")
	var expected_vertices := chunk.mesh_data.width * chunk.mesh_data.height
	assert_eq(chunk.mesh_data.vertices.size(), expected_vertices,
		"Vertex count should match grid dimensions")
	var expected_triangles := (chunk.mesh_data.width - 1) * (chunk.mesh_data.height - 1) * 2
	assert_eq(chunk.mesh_data.get_triangle_count(), expected_triangles,
		"Triangle count should match grid")

func test_chunk_vertices_are_in_local_space() -> void:
	var chunk := _generator.generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	assert_not_null(chunk, "Chunk should exist")
	var half_size := chunk.chunk_size.x / 2.0
	for vertex in chunk.mesh_data.vertices:
		assert_true(vertex.x >= -half_size - 0.1 and vertex.x <= half_size + 0.1,
			"Vertex X should be within chunk bounds")
		assert_true(vertex.z >= -half_size - 0.1 and vertex.z <= half_size + 0.1,
			"Vertex Z should be within chunk bounds")

func test_chunk_with_height_delta() -> void:
	var delta := HeightDeltaMap.create(32, 32, AABB(Vector3(-128, 0, -128), Vector3(256, 100, 256)))
	for y in range(32):
		for x in range(32):
			delta.delta_texture.set_pixel(x, y, Color(10.0, 0, 0, 1))
	_terrain_definition.add_height_delta(delta)
	var chunk := _generator.generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	assert_not_null(chunk, "Chunk should exist")
	var has_elevated := false
	for vertex in chunk.mesh_data.vertices:
		if vertex.y > 5.0:
			has_elevated = true
			break
	assert_true(has_elevated, "Chunk should have elevated vertices from delta")

func test_chunk_cache_basic() -> void:
	var cache := ChunkCache.new(10.0)
	var chunk := _generator.generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	assert_false(cache.has_chunk(Vector2i(0, 0), 0), "Cache should be empty initially")
	cache.store_chunk(Vector2i(0, 0), 0, chunk)
	assert_true(cache.has_chunk(Vector2i(0, 0), 0), "Cache should have chunk after store")
	var retrieved := cache.get_chunk(Vector2i(0, 0), 0)
	assert_eq(retrieved, chunk, "Retrieved chunk should match stored")

func test_chunk_cache_lru_eviction() -> void:
	var cache := ChunkCache.new(0.1)
	for i in range(10):
		var chunk := _generator.generate_chunk(Vector2i(i, 0), Vector2(64, 64), 0)
		cache.store_chunk(Vector2i(i, 0), 0, chunk)
	assert_lt(cache.get_cached_count(), 10, "Cache should have evicted some chunks")

func test_chunk_cache_invalidation() -> void:
	var cache := ChunkCache.new(10.0)
	var chunk := _generator.generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	cache.store_chunk(Vector2i(0, 0), 0, chunk)
	cache.store_chunk(Vector2i(0, 0), 1, chunk)
	cache.invalidate_coord(Vector2i(0, 0))
	assert_false(cache.has_chunk(Vector2i(0, 0), 0), "LOD 0 should be invalidated")
	assert_false(cache.has_chunk(Vector2i(0, 0), 1), "LOD 1 should be invalidated")

func test_chunk_generation_service_basic() -> void:
	var service := ChunkGenerationService.new(_terrain_definition, 32, 50.0)
	var chunk := service.get_or_generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	assert_not_null(chunk, "Service should return chunk")
	assert_true(service.has_cached_chunk(Vector2i(0, 0), 0), "Chunk should be cached")
	var cached := service.get_or_generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	assert_eq(cached, chunk, "Should return cached chunk")

func test_chunk_generation_service_invalidation() -> void:
	var service := ChunkGenerationService.new(_terrain_definition, 32, 50.0)
	service.get_or_generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	service.invalidate_chunk(Vector2i(0, 0), 0)
	assert_false(service.has_cached_chunk(Vector2i(0, 0), 0), "Chunk should be invalidated")

func test_chunk_generation_with_tunnel_volume() -> void:
	var tunnel := TunnelVolumeDefinition.new()
	tunnel.base_radius = 5.0
	var path := Curve3D.new()
	path.add_point(Vector3(0, 16, -50))
	path.add_point(Vector3(0, 16, 50))
	tunnel.path = path
	tunnel.update_bounds()
	_terrain_definition.add_volume(tunnel)
	var chunk := _generator.generate_chunk(Vector2i(2, 2), Vector2(64, 64), 0)
	assert_not_null(chunk, "Chunk should exist even with volume")

func test_multiple_chunks_cover_terrain() -> void:
	var chunk_size := Vector2(64, 64)
	var chunks_per_side := int(_terrain_definition.terrain_size.x / chunk_size.x)
	var total_chunks := 0
	for z in range(chunks_per_side):
		for x in range(chunks_per_side):
			var chunk := _generator.generate_chunk(Vector2i(x, z), chunk_size, 0)
			if chunk:
				total_chunks += 1
	assert_eq(total_chunks, chunks_per_side * chunks_per_side, 
		"Should generate all chunks for terrain")

func test_chunk_mesh_can_build_array_mesh() -> void:
	var chunk := _generator.generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	assert_not_null(chunk, "Chunk should exist")
	var array_mesh := ArrayMeshBuilder.build_mesh(chunk.mesh_data)
	assert_not_null(array_mesh, "Should build ArrayMesh")
	assert_gt(array_mesh.get_surface_count(), 0, "Mesh should have surfaces")

func test_cache_stats() -> void:
	var cache := ChunkCache.new(50.0)
	var chunk := _generator.generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	cache.store_chunk(Vector2i(0, 0), 0, chunk)
	var stats := cache.get_stats()
	assert_eq(stats["cached_chunks"], 1, "Should have 1 cached chunk")
	assert_gt(stats["memory_usage_mb"], 0.0, "Should have non-zero memory usage")
	assert_lt(stats["utilization"], 1.0, "Utilization should be less than 100%")

