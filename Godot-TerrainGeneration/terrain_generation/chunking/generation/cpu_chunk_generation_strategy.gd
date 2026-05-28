## @brief CPU-based chunk generation strategy.
##
## @details Hot path (height grid, mesh build, normals, tangents) runs in
## CpuChunkGeneratorNative (GDExtension). Volume application stays in GDScript
## since VolumeDefinition is a GDScript type.
## Thread-safe for concurrent chunk generation.
@tool
class_name CpuChunkGenerationStrategy extends ChunkGenerationStrategy

var _native_generator := CpuChunkGeneratorNative.new()

func _init(heightmap: Image) -> void:
	if heightmap:
		_native_generator.bake_heightmap(heightmap)

func get_processor_type() -> ProcessorType:
	return ProcessorType.CPU

func supports_async() -> bool:
	return true

## ChunkGenerator calls generate_height_grid first, then passes the result here.
## Deltas are already baked into height_grid by the time we receive it, so we
## only need to handle volumes on top of the pre-built grid.
func generate_chunk(
	terrain_definition: TerrainDefinition,
	chunk_bounds: AABB,
	lod_level: int,
	resolution: int,
	height_grid: PackedFloat32Array
) -> MeshData:
	if not terrain_definition or not terrain_definition.is_valid():
		push_error("CpuChunkGenerationStrategy: Invalid terrain definition")
		return null
	var volumes := terrain_definition.get_volumes_for_chunk(chunk_bounds, lod_level)
	if volumes.is_empty():
		return _native_generator.generate_chunk_from_grid(height_grid, chunk_bounds, resolution)
	if height_grid.is_empty():
		return null
	var current_time := Time.get_ticks_usec()
	var mesh_data: MeshData = _native_generator.generate_chunk_from_grid(
		height_grid, chunk_bounds, resolution
	)
	_emit_substep("mesh_build", (Time.get_ticks_usec() - current_time) / 1000.0)
	if not mesh_data:
		return null
	current_time = Time.get_ticks_usec()
	mesh_data = apply_volumes(mesh_data, volumes, chunk_bounds, resolution)
	_emit_substep("volumes", (Time.get_ticks_usec() - current_time) / 1000.0)
	return mesh_data

## Generates the height grid with delta maps applied entirely in native C++.
func generate_height_grid(
	terrain_definition: TerrainDefinition,
	chunk_bounds: AABB,
	resolution: int
) -> PackedFloat32Array:
	var deltas := terrain_definition.get_deltas_for_chunk(chunk_bounds)
	if deltas.is_empty():
		return _native_generator.generate_height_grid(
			chunk_bounds, resolution,
			terrain_definition.terrain_size.x,
			terrain_definition.height_scale
		)
	var packed: Array[Dictionary] = []
	for delta in deltas:
		if not delta.delta_texture:
			continue
		if delta.delta_texture.get_format() != Image.FORMAT_RF:
			push_warning("CpuChunkGenerationStrategy: delta texture is not FORMAT_RF, skipping")
			continue
		packed.append({
			"image": delta.delta_texture,
			"bounds": delta.world_bounds,
			"intensity": delta.intensity,
			"blend_mode": delta.blend_mode_int(),
		})
	return _native_generator.generate_height_grid_with_deltas(
		chunk_bounds, resolution,
		terrain_definition.terrain_size.x,
		terrain_definition.height_scale,
		packed
	)

func apply_volumes(
	mesh_data: MeshData,
	volumes: Array[VolumeDefinition],
	chunk_bounds: AABB,
	resolution: int
) -> MeshData:
	var result := mesh_data
	for volume in volumes:
		if volume.volume_type == VolumeDefinition.VolumeType.SUBTRACTIVE:
			result = _apply_subtractive_volume(result, volume, chunk_bounds)
		elif volume.volume_type == VolumeDefinition.VolumeType.ADDITIVE:
			result = _apply_additive_volume(result, volume, chunk_bounds, resolution)
	return result
 
## Clips the mesh against a subtractive volume.
##
## @details Triangles fully outside are kept intact. Triangles fully inside are
## discarded. Straddling triangles are clipped: new vertices are inserted at the
## exact volume boundary using volume.exit_t(), with UVs, normals and tangents
## interpolated at the crossing point.
##
## Canonical winding for clipping:
##   1 inside / 2 outside → outside quad = 2 triangles
##   2 inside / 1 outside → outside triangle = 1 triangle
func _apply_subtractive_volume(
	mesh_data: MeshData,
	volume: VolumeDefinition,
	chunk_bounds: AABB
) -> MeshData:
	var chunk_center := Vector3(
		chunk_bounds.position.x + chunk_bounds.size.x * 0.5,
		0.0,
		chunk_bounds.position.z + chunk_bounds.size.z * 0.5
	)
	var out_verts := mesh_data.vertices.duplicate()
	var out_uvs := mesh_data.uvs.duplicate()
	var out_indices := PackedInt32Array()
	var has_normals := mesh_data.cached_normals.size() == mesh_data.vertices.size()
	var has_tangents := mesh_data.cached_tangents.size() == mesh_data.vertices.size()
	var out_normals: PackedVector3Array = mesh_data.cached_normals.duplicate() if has_normals else PackedVector3Array()
	var out_tangents: PackedVector4Array = mesh_data.cached_tangents.duplicate() if has_tangents else PackedVector4Array()
	var modified := false
 
	for tri_base in range(0, mesh_data.indices.size(), 3):
		var i := [
			mesh_data.indices[tri_base],
			mesh_data.indices[tri_base + 1],
			mesh_data.indices[tri_base + 2]
		]
		var w := [
			mesh_data.vertices[i[0]] + chunk_center,
			mesh_data.vertices[i[1]] + chunk_center,
			mesh_data.vertices[i[2]] + chunk_center
		]
		var inside := [
			volume.point_is_inside(w[0]),
			volume.point_is_inside(w[1]),
			volume.point_is_inside(w[2])
		]
		var n_inside: int = int(inside[0]) + int(inside[1]) + int(inside[2])
 
		if n_inside == 0:
			out_indices.append(i[0]); out_indices.append(i[1]); out_indices.append(i[2])
			continue
 
		modified = true
 
		if n_inside == 3:
			continue
 
		# Rotate so: n_inside==1 → inside vertex at [0]; n_inside==2 → outside vertex at [2]
		if n_inside == 1:
			while not inside[0]:
				w = [w[1], w[2], w[0]]; i = [i[1], i[2], i[0]]; inside = [inside[1], inside[2], inside[0]]
		else:
			while inside[2]:
				w = [w[1], w[2], w[0]]; i = [i[1], i[2], i[0]]; inside = [inside[1], inside[2], inside[0]]
 
		if n_inside == 1:
			# v[0]=inside, v[1] and v[2]=outside
			# Crossing points on edges 0→1 and 0→2
			var t01 := volume.exit_t(w[0], w[1])
			var t02 := volume.exit_t(w[0], w[2])
			var ni01 := _emit_crossing(out_verts, out_uvs, out_normals, out_tangents,
				i[0], i[1], w[0], w[1], t01, chunk_center, has_normals, has_tangents)
			var ni02 := _emit_crossing(out_verts, out_uvs, out_normals, out_tangents,
				i[0], i[2], w[0], w[2], t02, chunk_center, has_normals, has_tangents)
			out_indices.append(ni01); out_indices.append(i[1]);  out_indices.append(i[2])
			out_indices.append(ni01); out_indices.append(i[2]);  out_indices.append(ni02)
		else:
			# v[0] and v[1]=inside, v[2]=outside
			# Crossing points on edges 0→2 and 1→2
			var t02 := volume.exit_t(w[0], w[2])
			var t12 := volume.exit_t(w[1], w[2])
			var ni02 := _emit_crossing(out_verts, out_uvs, out_normals, out_tangents,
				i[0], i[2], w[0], w[2], t02, chunk_center, has_normals, has_tangents)
			var ni12 := _emit_crossing(out_verts, out_uvs, out_normals, out_tangents,
				i[1], i[2], w[1], w[2], t12, chunk_center, has_normals, has_tangents)
			out_indices.append(ni02); out_indices.append(ni12); out_indices.append(i[2])
 
	if not modified:
		return mesh_data
 
	var result := MeshData.new()
	result.initialize(out_verts, out_indices, out_uvs)
	result.width = mesh_data.width
	result.height = mesh_data.height
	result.mesh_size = mesh_data.mesh_size
	result.cached_normals = out_normals
	result.cached_tangents = out_tangents
	return result
 
## Appends one interpolated crossing vertex and returns its index.
func _emit_crossing(
	verts: PackedVector3Array,
	uvs: PackedVector2Array,
	normals: PackedVector3Array,
	tangents: PackedVector4Array,
	ia: int, ib: int,
	wa: Vector3, wb: Vector3,
	t: float,
	chunk_center: Vector3,
	has_normals: bool,
	has_tangents: bool
) -> int:
	var idx := verts.size()
	verts.append(wa.lerp(wb, t) - chunk_center)
	uvs.append(uvs[ia].lerp(uvs[ib], t))
	if has_normals:
		normals.append(normals[ia].lerp(normals[ib], t).normalized())
	if has_tangents:
		var ta := tangents[ia]; var tb := tangents[ib]
		var tw := Vector3(ta.x, ta.y, ta.z).lerp(Vector3(tb.x, tb.y, tb.z), t).normalized()
		tangents.append(Vector4(tw.x, tw.y, tw.z, ta.w))
	return idx
 
func _apply_additive_volume(
	mesh_data: MeshData,
	volume: VolumeDefinition,
	chunk_bounds: AABB,
	resolution: int
) -> MeshData:
	var volume_mesh := volume.generate_mesh(chunk_bounds, resolution)
	if not volume_mesh or volume_mesh.vertices.is_empty():
		return mesh_data
	var chunk_center := Vector3(
		chunk_bounds.position.x + chunk_bounds.size.x * 0.5,
		0.0,
		chunk_bounds.position.z + chunk_bounds.size.z * 0.5
	)
	var base_count := mesh_data.vertices.size()
	var new_verts := mesh_data.vertices.duplicate()
	var new_uvs := mesh_data.uvs.duplicate()
	var new_indices := mesh_data.indices.duplicate()
	for vertex in volume_mesh.vertices:
		new_verts.append(vertex - chunk_center)
	for uv in volume_mesh.uvs:
		new_uvs.append(uv)
	for idx in volume_mesh.indices:
		new_indices.append(idx + base_count)
	var result := MeshData.new()
	result.initialize(new_verts, new_indices, new_uvs)
	result.width = mesh_data.width
	result.height = mesh_data.height
	result.mesh_size = mesh_data.mesh_size
	return result
