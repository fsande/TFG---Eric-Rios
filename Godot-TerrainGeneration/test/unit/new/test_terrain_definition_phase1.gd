## @brief Unit tests for Phase 1 terrain definition system.
extends GutTest

var _terrain_definition: TerrainDefinition = null


func before_each() -> void:
	_terrain_definition = null


func after_each() -> void:
	if _terrain_definition:
		_terrain_definition.clear_cache()
		_terrain_definition = null


## Test HeightmapSampler bilinear interpolation
func test_heightmap_sampler_bilinear() -> void:
	var heightmap := Image.create(3, 3, false, Image.FORMAT_RF)
	heightmap.set_pixel(0, 0, Color(0.0, 0, 0))
	heightmap.set_pixel(1, 0, Color(0.5, 0, 0))
	heightmap.set_pixel(2, 0, Color(1.0, 0, 0))
	heightmap.set_pixel(0, 1, Color(0.25, 0, 0))
	heightmap.set_pixel(1, 1, Color(0.5, 0, 0))
	heightmap.set_pixel(2, 1, Color(0.75, 0, 0))
	heightmap.set_pixel(0, 2, Color(0.5, 0, 0))
	heightmap.set_pixel(1, 2, Color(0.5, 0, 0))
	heightmap.set_pixel(2, 2, Color(0.5, 0, 0))
	var h00 := HeightmapSampler._sample_bilinear(heightmap, 0.0, 0.0)
	var h10 := HeightmapSampler._sample_bilinear(heightmap, 1.0, 0.0)
	assert_almost_eq(h00, 0.0, 0.01, "Top-left corner should be 0.0")
	assert_almost_eq(h10, 1.0, 0.01, "Top-right corner should be 1.0")
	var h_center := HeightmapSampler._sample_bilinear(heightmap, 0.5, 0.5)
	assert_almost_eq(h_center, 0.5, 0.1, "Center should be around 0.5")

## Test HeightDeltaMap creation and sampling
func test_height_delta_map_creation() -> void:
	var bounds := AABB(Vector3(-50, 0, -50), Vector3(100, 50, 100))
	var delta := HeightDeltaMap.create(64, 64, bounds)
	assert_not_null(delta, "Delta map should be created")
	assert_not_null(delta.delta_texture, "Delta texture should exist")
	assert_eq(delta.delta_texture.get_width(), 64, "Width should be 64")
	assert_eq(delta.delta_texture.get_height(), 64, "Height should be 64")
	assert_eq(delta.world_bounds, bounds, "Bounds should match")

func test_height_delta_map_set_and_sample() -> void:
	var bounds := AABB(Vector3(0, 0, 0), Vector3(100, 50, 100))
	var delta := HeightDeltaMap.create(10, 10, bounds)
	delta.set_at(Vector2(50, 50), 10.0)
	var sampled := delta.sample_at(Vector2(50, 50))
	assert_gt(sampled, 0.0, "Sampled value at center should be greater than 0")
	var outside := delta.sample_at(Vector2(-100, -100))
	assert_eq(outside, 0.0, "Outside bounds should return 0")

func test_height_delta_map_blend_strategies() -> void:
	var delta := HeightDeltaMap.new()
	delta.blend_strategy = AdditiveBlendStrategy.new()
	var result_add := delta.apply_blend(10.0, 5.0)
	assert_eq(result_add, 15.0, "ADD should add values")
	delta.blend_strategy = MaxBlendStrategy.new()
	var result_max := delta.apply_blend(10.0, 8.0)
	assert_eq(result_max, 18.0, "MAX should take maximum of sum")

## Test VolumeDefinition base class
func test_volume_definition_lod_check() -> void:
	var volume := VolumeDefinition.new()
	volume.lod_min = 0
	volume.lod_max = 2
	volume.enabled = true
	assert_true(volume.should_apply_at_lod(0), "Should apply at LOD 0")
	assert_true(volume.should_apply_at_lod(1), "Should apply at LOD 1")
	assert_true(volume.should_apply_at_lod(2), "Should apply at LOD 2")
	assert_false(volume.should_apply_at_lod(3), "Should not apply at LOD 3")
	volume.enabled = false
	assert_false(volume.should_apply_at_lod(0), "Disabled volume should not apply")

## Test TunnelVolumeDefinition
func test_tunnel_volume_path() -> void:
	var tunnel := TunnelVolumeDefinition.new()
	tunnel.base_radius = 3.0
	var path := Curve3D.new()
	path.add_point(Vector3(0, 10, 0))
	path.add_point(Vector3(0, 10, 20))
	tunnel.path = path
	var inside := tunnel.point_is_inside(Vector3(0, 10, 10))
	assert_true(inside, "Point on path should be inside tunnel")
	var outside := tunnel.point_is_inside(Vector3(100, 100, 100))
	assert_false(outside, "Distant point should be outside tunnel")

func test_tunnel_volume_bounds_update() -> void:
	var tunnel := TunnelVolumeDefinition.new()
	tunnel.base_radius = 5.0
	var path := Curve3D.new()
	path.add_point(Vector3(0, 0, 0))
	path.add_point(Vector3(50, 0, 0))
	tunnel.path = path
	tunnel.update_bounds()
	assert_gt(tunnel.bounds.size.x, 40, "Bounds X should encompass path")
	assert_gt(tunnel.bounds.size.y, 5, "Bounds Y should include radius")

## Test OverhangVolumeDefinition
func test_overhang_volume_creation() -> void:
	var overhang := OverhangVolumeDefinition.new()
	overhang.attachment_point = Vector3(0, 20, 0)
	overhang.overhang_direction = Vector3(1, -0.2, 0).normalized()
	overhang.extent = 5.0
	overhang.width = 8.0
	overhang.thickness = 2.0
	overhang.update_bounds()
	assert_gt(overhang.bounds.size.x, 0, "Bounds should have positive size")
	assert_eq(overhang.volume_type, VolumeDefinition.VolumeType.ADDITIVE, "Overhang should be additive")

## Test TerrainDefinition
func test_terrain_definition_creation() -> void:
	var source := NoiseHeightmapSource.new()
	_terrain_definition = TerrainDefinition.create(
		source,
		Vector2(512, 512),
		64.0,
		12345
	)
	assert_not_null(_terrain_definition, "Definition should be created")
	assert_eq(_terrain_definition.terrain_size, Vector2(512, 512), "Size should match")
	assert_eq(_terrain_definition.height_scale, 64.0, "Height scale should match")
	assert_eq(_terrain_definition.generation_seed, 12345, "Seed should match")

func test_terrain_definition_add_delta() -> void:
	var source := NoiseHeightmapSource.new()
	_terrain_definition = TerrainDefinition.create(source, Vector2(256, 256), 32.0, 0)
	var delta := HeightDeltaMap.create(32, 32, AABB(Vector3(0, 0, 0), Vector3(100, 50, 100)))
	_terrain_definition.add_height_delta(delta)
	assert_eq(_terrain_definition.height_delta_maps.size(), 1, "Should have 1 delta map")


func test_terrain_definition_add_volume() -> void:
	var source := NoiseHeightmapSource.new()
	_terrain_definition = TerrainDefinition.create(source, Vector2(256, 256), 32.0, 0)
	var tunnel := TunnelVolumeDefinition.new()
	tunnel.base_radius = 3.0
	_terrain_definition.add_volume(tunnel)
	assert_eq(_terrain_definition.volume_definitions.size(), 1, "Should have 1 volume")


func test_terrain_definition_get_volumes_for_chunk() -> void:
	var source := NoiseHeightmapSource.new()
	_terrain_definition = TerrainDefinition.create(source, Vector2(256, 256), 32.0, 0)
	var tunnel := TunnelVolumeDefinition.new()
	tunnel.bounds = AABB(Vector3(0, 0, 0), Vector3(50, 50, 50))
	_terrain_definition.add_volume(tunnel)
	var overlapping := _terrain_definition.get_volumes_for_chunk(
		AABB(Vector3(10, 0, 10), Vector3(30, 30, 30))
	)
	assert_eq(overlapping.size(), 1, "Should find overlapping volume")
	var non_overlapping := _terrain_definition.get_volumes_for_chunk(
		AABB(Vector3(200, 0, 200), Vector3(30, 30, 30))
	)
	assert_eq(non_overlapping.size(), 0, "Should not find non-overlapping volume")

## Test TerrainGenerationContext
func test_generation_context_creation() -> void:
	var context := TerrainGenerationContext.new(
		Vector2(512, 512),
		64.0,
		12345,
		null
	)
	assert_eq(context.terrain_size, Vector2(512, 512), "Size should match")
	assert_eq(context.height_scale, 64.0, "Height scale should match")
	assert_eq(context.generation_seed, 12345, "Seed should match")

func test_generation_context_world_to_uv() -> void:
	var context := TerrainGenerationContext.new(
		Vector2(100, 100),
		32.0,
		0,
		null
	)
	var center_uv := context.world_to_uv(Vector2(0, 0))
	assert_almost_eq(center_uv.x, 0.5, 0.01, "Center X should be 0.5")
	assert_almost_eq(center_uv.y, 0.5, 0.01, "Center Y should be 0.5")
	var corner_uv := context.world_to_uv(Vector2(-50, -50))
	assert_almost_eq(corner_uv.x, 0.0, 0.01, "Corner X should be 0.0")
	assert_almost_eq(corner_uv.y, 0.0, 0.01, "Corner Y should be 0.0")


func test_generation_context_uv_to_world() -> void:
	var context := TerrainGenerationContext.new(
		Vector2(100, 100),
		32.0,
		0,
		null
	)
	var center_world := context.uv_to_world(Vector2(0.5, 0.5))
	assert_almost_eq(center_world.x, 0.0, 0.01, "Center X should be 0")
	assert_almost_eq(center_world.y, 0.0, 0.01, "Center Y should be 0")

## Test TerrainRaiseAgentV2
func test_terrain_raise_agent_v2_validation() -> void:
	var agent := TerrainRaiseAgentV2.new()
	agent.radius = 50.0
	agent.height = 10.0
	var context := TerrainGenerationContext.new(Vector2(256, 256), 32.0, 0, null)
	assert_true(agent.validate(context), "Agent with valid params should validate")
	agent.radius = 0 
	assert_false(agent.validate(context), "Agent with zero radius should fail validation")
	assert_push_error("TerrainRaiseAgentV2: radius must be positive")

func test_terrain_raise_agent_v2_generate() -> void:
	var agent := TerrainRaiseAgentV2.new()
	agent.center_position = Vector2(0, 0)
	agent.radius = 50.0
	agent.height = 15.0
	agent.delta_resolution = 64
	var context := TerrainGenerationContext.new(Vector2(256, 256), 32.0, 12345, null)
	var result := agent.generate(context)
	assert_true(result.success, "Generation should succeed")
	assert_eq(result.height_deltas.size(), 1, "Should produce one height delta")
	var delta := result.height_deltas[0]
	assert_not_null(delta, "Delta should not be null")
	assert_not_null(delta.delta_texture, "Delta texture should exist")
	var center_value := delta.sample_at(Vector2(0, 0))
	assert_gt(center_value, 10.0, "Center should have significant height")

## Test MountainAgentV2
func test_mountain_agent_v2_validation() -> void:
	var agent := MountainAgentV2.new()
	agent.tokens = 10
	agent.step_distance = 5.0
	var context := TerrainGenerationContext.new(Vector2(256, 256), 32.0, 0, null)
	assert_true(agent.validate(context), "Agent with valid params should validate")
	agent.tokens = 0 
	assert_false(agent.validate(context), "Agent with zero tokens should fail")
	assert_push_error("MountainAgentV2: tokens must be positive")

func test_mountain_agent_v2_generate_height_only() -> void:
	var agent := MountainAgentV2.new()
	agent.start_position = Vector2(0, 0)
	agent.tokens = 5
	agent.step_distance = 10.0
	agent.wedge_width = 15.0
	agent.elevation_height = 20.0
	agent.enable_overhangs = false
	agent.delta_resolution = 64
	var context := TerrainGenerationContext.new(Vector2(256, 256), 32.0, 12345, null)
	var result := agent.generate(context)
	assert_true(result.success, "Generation should succeed")
	assert_eq(result.height_deltas.size(), 1, "Should produce one height delta")
	assert_eq(result.volumes.size(), 0, "Should produce no volumes without overhangs")

func test_mountain_agent_v2_generate_with_overhangs() -> void:
	var agent := MountainAgentV2.new()
	agent.start_position = Vector2(0, 0)
	agent.tokens = 10
	agent.step_distance = 10.0
	agent.enable_overhangs = true
	agent.overhang_probability = 1.0
	agent.delta_resolution = 64
	var heightmap := Image.create(64, 64, false, Image.FORMAT_RF)
	heightmap.fill(Color(0.5, 0, 0))
	var context := TerrainGenerationContext.new(Vector2(256, 256), 32.0, 12345, heightmap)
	var result := agent.generate(context)
	assert_true(result.success, "Generation should succeed")
	assert_eq(result.height_deltas.size(), 1, "Should produce one height delta")
	assert_gt(result.volumes.size(), 0, "Should produce overhang volumes")

## Test TunnelBoringAgentV2
func test_tunnel_boring_agent_v2_validation() -> void:
	var agent := TunnelBoringAgentV2.new()
	agent.tunnel_radius = 3.0
	agent.tunnel_length = 20.0
	var context := TerrainGenerationContext.new(Vector2(256, 256), 32.0, 0, null)
	assert_true(agent.validate(context), "Agent with valid params should validate")
	agent.tunnel_radius = 0
	assert_false(agent.validate(context), "Agent with zero radius should fail")
	assert_push_error("TunnelBoringAgentV2: tunnel_radius must be positive")

## Test TerrainDefinitionGenerator
func test_definition_generator_basic() -> void:
	var generator := TerrainDefinitionGenerator.new()
	generator.verbose = false
	var source := NoiseHeightmapSource.new()
	source.resolution = 64
	var agents: Array[TerrainModifierAgent] = []
	var raise_agent := TerrainRaiseAgentV2.new()
	raise_agent.center_position = Vector2(0, 0)
	raise_agent.radius = 30.0
	raise_agent.height = 10.0
	raise_agent.delta_resolution = 32
	agents.append(raise_agent)
	var stage := SequentialModifierStage.new()
	stage.agents = agents
	_terrain_definition = generator.generate(
		source,
		Vector2(128, 128),
		32.0,
		[stage],
		12345
	)
	assert_not_null(_terrain_definition, "Definition should be generated")
	assert_eq(_terrain_definition.height_delta_maps.size(), 1, "Should have 1 delta from raise agent")
	assert_true(_terrain_definition.is_valid(), "Definition should be valid")

func test_definition_generator_multiple_agents() -> void:
	var generator := TerrainDefinitionGenerator.new()
	generator.verbose = false
	var source := NoiseHeightmapSource.new()
	source.resolution = 64
	var agents: Array[TerrainModifierAgent] = []
	var raise_agent := TerrainRaiseAgentV2.new()
	raise_agent.center_position = Vector2(-20, -20)
	raise_agent.radius = 20.0
	raise_agent.height = 8.0
	raise_agent.delta_resolution = 32
	agents.append(raise_agent)
	var mountain_agent := MountainAgentV2.new()
	mountain_agent.start_position = Vector2(20, 20)
	mountain_agent.tokens = 5
	mountain_agent.step_distance = 8.0
	mountain_agent.enable_overhangs = false
	mountain_agent.delta_resolution = 32
	agents.append(mountain_agent)
	var stage := SequentialModifierStage.new()
	stage.agents = agents
	_terrain_definition = generator.generate(
		source,
		Vector2(128, 128),
		32.0,
		[stage],
		12345
	)
	assert_not_null(_terrain_definition, "Definition should be generated")
	assert_eq(_terrain_definition.height_delta_maps.size(), 2, "Should have 2 deltas from both agents")

## Integration test: Full pipeline
func test_integration_full_pipeline() -> void:
	var generator := TerrainDefinitionGenerator.new()
	generator.verbose = false
	var source := NoiseHeightmapSource.new()
	source.resolution = 128
	source.frequency = 3.0
	var agents: Array[TerrainModifierAgent] = []
	var mountain := MountainAgentV2.new()
	mountain.start_position = Vector2(0, -50)
	mountain.initial_direction_degrees = 0.0
	mountain.tokens = 8
	mountain.step_distance = 12.0
	mountain.wedge_width = 25.0
	mountain.elevation_height = 25.0
	mountain.enable_overhangs = true
	mountain.overhang_probability = 0.5
	mountain.delta_resolution = 64
	agents.append(mountain)
	var raise := TerrainRaiseAgentV2.new()
	raise.center_position = Vector2(50, 50)
	raise.radius = 40.0
	raise.height = 15.0
	raise.delta_resolution = 64
	agents.append(raise)
	var sequential_stage := SequentialModifierStage.new()
	sequential_stage.agents = agents
	_terrain_definition = generator.generate(
		source,
		Vector2(256, 256),
		64.0,
		[sequential_stage],
		42
	)
	assert_not_null(_terrain_definition, "Definition should exist")
	assert_true(_terrain_definition.is_valid(), "Definition should be valid")
	assert_eq(_terrain_definition.height_delta_maps.size(), 2, "Should have 2 height deltas")
	print("Generated %d overhang volumes" % _terrain_definition.volume_definitions.size())
	var base_heightmap := _terrain_definition.get_base_heightmap()
	assert_not_null(base_heightmap, "Should get base heightmap")
	var chunk_bounds := AABB(Vector3(-50, 0, -50), Vector3(100, 100, 100))
	var deltas := _terrain_definition.get_deltas_for_chunk(chunk_bounds)
	assert_gt(deltas.size(), 0, "Should find deltas for central chunk")
	print(_terrain_definition.get_summary())

