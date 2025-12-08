class_name MeshGenComparer extends Control

@export var heightmap: Image
@export var mesh_size := Vector2(100, 100)
@export var height_scale := 5.0
@export_range(4, 4096, 4) var mesh_subdivisions := 32

@onready var cpu_viewport: SubViewport = $CenterContainer/VBoxContainer/PanelContainer2/VBoxContainer/GridContainer/CPUViewportContainer/CPUViewport
@onready var gpu_viewport: SubViewport = $CenterContainer/VBoxContainer/PanelContainer2/VBoxContainer/GridContainer/GPUViewportContainer/GPUViewport
@onready var cpu_time_label: Label = $CenterContainer/VBoxContainer/PanelContainer2/VBoxContainer/HBoxContainer/CPUTimeValue
@onready var gpu_time_label: Label = $CenterContainer/VBoxContainer/PanelContainer2/VBoxContainer/HBoxContainer/GPUTimeValue

var base_mesh: ArrayMesh
var cpu_modifier: CPUMeshGenerator
var gpu_mesh_generator: GpuMeshGenerator

func _ready() -> void:
	cpu_modifier = CPUMeshGenerator.new()
	gpu_mesh_generator = GpuMeshGenerator.new()
	cpu_modifier.modification_completed.connect(_on_cpu_modification_completed)
	gpu_mesh_generator.modification_completed.connect(_on_gpu_modification_completed)

	var generate_cpu_button := $CenterContainer/VBoxContainer/PanelContainer/VBoxContainer/HBoxContainer/GenerateCPUButton
	var generate_gpu_button := $CenterContainer/VBoxContainer/PanelContainer/VBoxContainer/HBoxContainer/GenerateGPUButton
	generate_cpu_button.text += "\n" + OS.get_processor_name()
	generate_gpu_button.text += "\n" + RenderingServer.get_video_adapter_name()
	
	_setup_viewport_camera(cpu_viewport)
	_setup_viewport_camera(gpu_viewport)
	
	if (heightmap == null):
		return
	_create_base_mesh()

func _setup_viewport_camera(viewport: SubViewport) -> void:
	viewport.world_3d = World3D.new()
	var camera := Camera3D.new()
	var distance: float = max(mesh_size.x, mesh_size.y)
	var cam_position := Vector3(0, distance * 0.5, distance * 0.5)
	camera.position = cam_position
	viewport.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	
	var light := DirectionalLight3D.new()
	light.position = Vector3(50, 100, 50)
	light.rotation_degrees = Vector3(0, 0, 0)
	viewport.add_child(light)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup()
		
func _cleanup() -> void:
	cpu_modifier.cleanup()
	gpu_mesh_generator.cleanup()

func _create_base_mesh() -> void:
	base_mesh = ArrayMesh.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = mesh_size
	plane_mesh.subdivide_depth = mesh_subdivisions
	plane_mesh.subdivide_width = mesh_subdivisions
	
	var arrays := plane_mesh.get_mesh_arrays()
	base_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _on_generate_cpu_button_pressed() -> void:
	if heightmap == null or base_mesh == null:
		push_error("Heightmap or base mesh not assigned")
		return
	cpu_time_label.text = "Processing..."
	_generate_cpu_mesh.call_deferred()

func _generate_cpu_mesh() -> void:
	var base_arrays: Array = base_mesh.surface_get_arrays(0)
	var processing_context := ProcessingContext.new(mesh_size.x, 0, ProcessingContext.ProcessorType.CPU)
	var result := cpu_modifier.generate_mesh(base_arrays, heightmap, processing_context)
	_display_mesh_in_viewport(cpu_viewport, result.modified_mesh)
	cpu_time_label.text = "%s ms" % str(result.elapsed_time_ms).pad_decimals(1)

func _on_generate_gpu_button_pressed() -> void:
	if heightmap == null or base_mesh == null:
		push_error("Heightmap or base mesh not assigned")
		return
	gpu_time_label.text = "Processing..."
	_generate_gpu_mesh.call_deferred()

func _generate_gpu_mesh() -> void:
	var base_arrays: Array = base_mesh.surface_get_arrays(0)
	var processing_context := ProcessingContext.new(mesh_size.x, 0, ProcessingContext.ProcessorType.GPU)
	var result := gpu_mesh_generator.generate_mesh(base_arrays, heightmap, processing_context)
	_display_mesh_in_viewport(gpu_viewport, result.modified_mesh)
	gpu_time_label.text = "%s ms" % str(result.elapsed_time_ms).pad_decimals(1)

func _display_mesh_in_viewport(viewport: SubViewport, mesh: ArrayMesh) -> void:
	for child in viewport.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, 0, 0)
	
	var mesh_material := StandardMaterial3D.new()
	mesh_material.albedo_color = Color(1, 0, 0.8)
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh_instance.material_override = mesh_material
	viewport.add_child(mesh_instance)

func _on_cpu_modification_completed(result: MeshGenerationResult) -> void:
	cpu_time_label.text = "%s ms" % str(result.elapsed_time_ms).pad_decimals(1)

func _on_gpu_modification_completed(result: MeshGenerationResult) -> void:
	gpu_time_label.text = "%s ms" % str(result.elapsed_time_ms).pad_decimals(1)
