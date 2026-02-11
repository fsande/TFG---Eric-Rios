## @brief Simple fly camera for terrain exploration.
##
## @details WASD movement, mouse look, shift to speed up.
## Works in both editor and runtime.
@tool
class_name TerrainFlyCamera extends Camera3D

@export var move_speed: float = 50.0
@export var fast_speed: float = 150.0
@export var mouse_sensitivity: float = 0.002
@export var enabled: bool = true

var _velocity: Vector3 = Vector3.ZERO
var _rotation_x: float = 0.0
var _rotation_y: float = 0.0
var _mouse_captured: bool = false

func _ready() -> void:
	_rotation_x = rotation.x
	_rotation_y = rotation.y

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_mouse_captured = true
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_mouse_captured = false
	if event is InputEventMouseMotion and _mouse_captured:
		var mm := event as InputEventMouseMotion
		_rotation_y -= mm.relative.x * mouse_sensitivity
		_rotation_x -= mm.relative.y * mouse_sensitivity
		_rotation_x = clampf(_rotation_x, -PI / 2.0, PI / 2.0)
		rotation = Vector3(_rotation_x, _rotation_y, 0)

func _process(delta: float) -> void:
	if not enabled:
		return
	if Engine.is_editor_hint():
		return
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		input_dir.y -= 1
	input_dir = input_dir.normalized()
	var speed := fast_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
	var direction := (transform.basis * input_dir).normalized()
	_velocity = direction * speed
	position += _velocity * delta
