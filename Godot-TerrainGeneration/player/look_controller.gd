extends Node3D
class_name LookController

@export var sensitivity: float = 0.002
@export var max_pitch: float = PI / 2
@export var min_pitch: float = -PI / 2

var pitch: float = 0.0  
var is_mouse_captured: bool = true

func _ready() -> void:
	_capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_cursor"):
		_toggle_mouse_mode()
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_mouse_captured:
			_capture_mouse()
	
	if event is InputEventMouseMotion and is_mouse_captured:
		rotate_camera(event.relative)

func rotate_camera(mouse_delta: Vector2) -> void:
	get_parent().rotate_y(-mouse_delta.x * sensitivity)

	pitch = clamp(pitch - mouse_delta.y * sensitivity, min_pitch, max_pitch)
	rotation.x = pitch

func get_basis_for_movement() -> Basis:
	return get_parent().global_transform.basis

func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_mouse_captured = true

func _free_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_mouse_captured = false

func _toggle_mouse_mode() -> void:
	if is_mouse_captured:
		_free_mouse()
	else:
		_capture_mouse()
