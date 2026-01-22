## @brief Orchestrator agent that creates tunnels through terrain.
## @details Supports multiple tunnel shapes via polymorphic TunnelShapeParameters.
## Uses Strategy Pattern for shape creation and Factory Pattern for shape instantiation.
@tool
class_name TunnelBoringAgent extends MeshModifierAgent

@export_group("Tunnel Shape")
## Tunnel shape parameters (defines tunnel geometry)
## Supports: CylindricalShapeParameters, SplineShapeParameters, NaturalCaveParameters
@export var shape_parameters: TunnelShapeParameters = null

## Extra length to open tunnel entrance above terrain surface.
@export var tunnel_entrance_extra_length: float = 2.0

@export_group("Placement")
## Minimum cliff height to place tunnel entrance.
@export var min_cliff_height: float = 15.0

## Minimum slope angle (degrees) for cliff detection.
@export_range(5.0, 90.0, 5.0) var min_cliff_angle: float = 10.0

## Number of tunnels to create.
@export_range(1, 10, 1) var tunnel_count: int = 1

## Random seed for placement (0 = random).
@export var placement_seed: int = 0

@export_group("Generation Settings")
## Enable CSG boolean subtraction from terrain mesh
@export var enable_csg_subtraction: bool = true

## Enable interior mesh generation
@export var enable_interior_generation: bool = true

## Enable collision shape generation
@export var enable_collision: bool = true

@export_group("Visual")
## Material to apply to tunnel interior mesh (null = use default gray stone)
@export var tunnel_material: Material = null

@export_group("Debug")
## Show debug visualization cylinders
@export var show_debug_visualization: bool = true

## Debug cylinder color
@export var debug_color: Color = Color(1.0, 0.0, 0.0, 0.3)

## Specialized components (Dependency Injection)
var _shape_factory: TunnelShapeFactory
var _interior_generator: TunnelInteriorGenerator
var _scene_builder: TunnelSceneBuilder
var _csg_operator: CSGBooleanOperator

func _init() -> void:
	agent_name = "Tunnel Boring Agent"
	_initialize_components()
	_initialize_default_parameters()

## Initialize specialized components (Strategy Pattern)
func _initialize_components() -> void:
	_shape_factory = TunnelShapeFactory.new()
	_interior_generator = TunnelInteriorGenerator.new()
	_scene_builder = TunnelSceneBuilder.new()
	_csg_operator = CSGBooleanOperator.new()

## Initialize default shape parameters if not set
func _initialize_default_parameters() -> void:
	if not shape_parameters:
		shape_parameters = CylindricalShapeParameters.new()
		shape_parameters.radius = 3.0
		shape_parameters.length = 20.0
		shape_parameters.radial_segments = 16
		shape_parameters.length_segments = 8

func get_agent_type() -> String:
	return "TunnelBoring"

func modifies_mesh() -> bool:
	return enable_csg_subtraction

func generates_scene_nodes() -> bool:
	return enable_interior_generation

func get_produced_data_types() -> Array[String]:
	return ["tunnel_definitions", "tunnel_shapes", "tunnel_meshes"]

func validate(context: MeshModifierContext) -> bool:
	if not context.get_mesh_generation_result():
		push_error("TunnelBoringAgent: No mesh data in context")
		return false
	if not shape_parameters:
		push_error("TunnelBoringAgent: No shape parameters configured")
		return false
	if not shape_parameters.is_valid():
		var errors := shape_parameters.get_validation_errors()
		for error in errors:
			push_error("TunnelBoringAgent: %s" % error)
		return false
	return true

func execute(context: MeshModifierContext) -> MeshModifierResult:
	var start_time := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Finding cliff faces for tunnel placement")
	var entry_points := _find_tunnel_entry_points(context)
	if entry_points.is_empty():
		return MeshModifierResult.create_failure(
			"No suitable cliff faces found for tunnel placement",
			Time.get_ticks_msec() - start_time
		)
	progress_updated.emit(0.2, "Creating tunnel definitions")
	var definitions := _create_tunnel_definitions(entry_points)
	progress_updated.emit(0.3, "Building tunnel shapes")
	var shapes := _create_tunnel_shapes(definitions)
	var tunnel_meshes: Array[MeshData] = []
	if enable_interior_generation:
		progress_updated.emit(0.4, "Generating tunnel interior meshes")
		tunnel_meshes = _generate_interior_meshes(shapes, context)
	if enable_csg_subtraction:
		progress_updated.emit(0.6, "Subtracting tunnels from terrain mesh")
		_apply_csg_subtraction(shapes, context)
	var tunnels_added := 0
	if enable_interior_generation and not tunnel_meshes.is_empty():
		progress_updated.emit(0.8, "Building tunnel scene nodes")
		tunnels_added = _build_scene_nodes(tunnel_meshes, definitions, context)
	if show_debug_visualization:
		_create_debug_visualization(shapes, context.agent_node_root)
	var elapsed := Time.get_ticks_msec() - start_time
	var operations: Array[String] = []
	if enable_csg_subtraction:
		operations.append("CSG subtraction")
	if enable_interior_generation:
		operations.append("%d interior meshes" % tunnels_added)
	if enable_collision:
		operations.append("collision shapes")
	var shape_desc := shape_parameters.to_string() if shape_parameters else "unknown"
	var message := "Created %d tunnel(s) with: %s [%s]" % [
		shapes.size(),
		", ".join(operations) if not operations.is_empty() else "debug only",
		shape_desc
	]
	return MeshModifierResult.create_success(elapsed, message, get_metadata())

## Find valid tunnel entry points on cliff faces
func _find_tunnel_entry_points(context: MeshModifierContext) -> Array[TunnelEntryPoint]:
	var sample_count := tunnel_count * 2
	var entry_points := context.sample_cliff_positions(
		min_cliff_angle,
		min_cliff_height,
		sample_count,
		placement_seed
	)
	print("Found %d cliff positions (image-based sampling)" % entry_points.size())
	var filtered := _filter_entry_points(entry_points, context)
	print("Filtered to %d valid entry points" % filtered.size())
	return filtered.slice(0, tunnel_count)

## Create tunnel definitions from entry points
func _create_tunnel_definitions(entry_points: Array[TunnelEntryPoint]) -> Array[TunnelDefinition]:
	var definitions: Array[TunnelDefinition] = []
	for entry in entry_points:
		entry.position -= entry.surface_normal * tunnel_entrance_extra_length
		var params := shape_parameters.duplicate_parameters()
		if params is CylindricalShapeParameters:
			var cylindrical_params := params as CylindricalShapeParameters
			cylindrical_params.length += tunnel_entrance_extra_length
		var definition := TunnelDefinition.new(entry, params)
		definition.generate_collision = enable_collision
		definition.debug_visualization = show_debug_visualization
		definition.debug_color = debug_color
		definition.tunnel_material = tunnel_material
		definitions.append(definition)
	print("Created %d tunnel definitions" % definitions.size())
	return definitions

## Create tunnel shapes from definitions
func _create_tunnel_shapes(definitions: Array[TunnelDefinition]) -> Array[TunnelShape]:
	var shapes: Array[TunnelShape] = []
	for definition in definitions:
		var shape := TunnelShapeFactory.create_from_definition(definition)
		if shape != null:
			shapes.append(shape)
		else:
			push_warning("TunnelBoringAgent: Failed to create shape from definition")
	print("Created %d tunnel shapes" % shapes.size())
	return shapes
	
## Generate interior meshes for tunnels
func _generate_interior_meshes(shapes: Array[TunnelShape], context: MeshModifierContext) -> Array[MeshData]:
	var meshes: Array[MeshData] = []
	var terrain_querier := BasicTerrainHeightQuery.new(context)
	for i in range(shapes.size()):
		var shape := shapes[i]
		progress_updated.emit(0.4 + (0.2 * float(i) / shapes.size()), 
			"Generating interior mesh %d/%d" % [i + 1, shapes.size()])
		var mesh := _interior_generator.generate(shape, terrain_querier)
		meshes.append(mesh)
	return meshes
	
## Apply CSG boolean subtraction to terrain mesh
func _apply_csg_subtraction(shapes: Array[TunnelShape], context: MeshModifierContext) -> void:
	var original_mesh := context.get_mesh_generation_result().mesh_data
	var modified_mesh := original_mesh
	for i in range(shapes.size()):
		var shape := shapes[i]
		modified_mesh = _csg_operator.subtract_volume_from_mesh(modified_mesh, shape)
	_replace_mesh_in_context(context, modified_mesh)
	
## Build scene nodes for tunnel interiors
func _build_scene_nodes(
	tunnel_meshes: Array[MeshData],
	definitions: Array[TunnelDefinition],
	context: MeshModifierContext
) -> int:
	return _scene_builder.build_batch(
		tunnel_meshes,
		definitions,
		context.agent_node_root
	)
	
## Create debug visualization
func _create_debug_visualization(shapes: Array[TunnelShape], root: Node3D) -> void:
	var container_name := "TunnelDebugCylinders"
	var container := NodeCreationHelper.get_or_create_node(root, container_name, Node3D) as Node3D
	for child in container.get_children():
		child.queue_free()
	for i in range(shapes.size()):
		var shape := shapes[i]
		var debug_data := shape.get_debug_mesh()
		var mesh: Mesh = debug_data[0]
		var transform: Transform3D = debug_data[1]
		var mi := MeshInstance3D.new()
		mi.name = "DebugTunnel_%d" % i
		mi.mesh = mesh
		mi.global_transform = transform
		var mat := StandardMaterial3D.new()
		mat.albedo_color = debug_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		container.add_child(mi)
		mi.owner = root.owner if root.owner != null else root
	print("Created %d debug visualization nodes" % shapes.size())
	
## Helper: Replace mesh data in context
func _replace_mesh_in_context(context: MeshModifierContext, new_mesh_data: MeshData) -> void:
	var mesh_result := context.get_mesh_generation_result()
	mesh_result.mesh_data = new_mesh_data
	mesh_result.mark_dirty()

## Helper: Filter entry points by tunnel geometry constraints
func _filter_entry_points(entry_points: Array[TunnelEntryPoint], context: MeshModifierContext) -> Array[TunnelEntryPoint]:
	var valid_points: Array[TunnelEntryPoint] = []
	var terrain_size := context.terrain_size()

	var tunnel_length := shape_parameters.get_length()
	for entry in entry_points:
		if not entry.has_valid_direction():
			continue
		if not entry.is_within_bounds(tunnel_length, terrain_size):
			continue

		valid_points.append(entry)
	return valid_points
	
## Get metadata about this agent
func get_metadata() -> Dictionary:
	var base := super.get_metadata()
	if shape_parameters:
		base["shape_type"] = TunnelShapeType.get_display_name(shape_parameters.get_shape_type())
		base["shape_summary"] = shape_parameters.to_string()
		base["tunnel_length"] = shape_parameters.get_length()
		if shape_parameters is CylindricalShapeParameters:
			var cyl_params := shape_parameters as CylindricalShapeParameters
			base["tunnel_radius"] = cyl_params.radius
			base["tunnel_radial_segments"] = cyl_params.radial_segments
			base["tunnel_length_segments"] = cyl_params.length_segments
	base["enable_csg_subtraction"] = enable_csg_subtraction
	base["enable_interior_generation"] = enable_interior_generation
	base["enable_collision"] = enable_collision
	return base
