class_name Player
extends CharacterBody3D

@export var speed: float = 5
@export var look_controller: LookController

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

func _physics_process(delta: float) -> void:
	add_gravity(delta)
	handle_input()
	move_and_slide()

func add_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

func handle_input() -> void:
	handle_movement_input()		
	hanlde_jump_input()	
	
func handle_movement_input() -> void:
	var input_direction := get_input_direction()
	
	if look_controller:
		var movement_basis := look_controller.get_basis_for_movement()
		var forward := movement_basis.z
		var right := movement_basis.x
		var direction: Vector3 = (right * input_direction.x 
		+ forward * input_direction.y).normalized()
		if is_sprinting():
			direction *= 2.0

		if direction != Vector3.ZERO:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = 0
			velocity.z = 0

func hanlde_jump_input() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 8.0

func is_sprinting() -> bool:
	return Input.is_action_pressed("sprint")

func get_input_direction() -> Vector2:
	var input_direction := Vector2.ZERO	
	if Input.is_action_pressed("move_right"):
		input_direction.x += 1
	if Input.is_action_pressed("move_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("move_back"):
		input_direction.y += 1
	if Input.is_action_pressed("move_forward"):
		input_direction.y -= 1
	
	return input_direction.normalized()
	
