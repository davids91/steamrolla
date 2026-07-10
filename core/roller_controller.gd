class_name RollerController extends Node3D


signal driver_intention_changed(is_moving: bool, forward: bool)

@export var debug: bool

@export_category("Opacity")
@export var opacity: float = 0.4:
	set(v):
		opacity = v
		if $Skin: $Skin.get_active_material(0).albedo_color.a = opacity

@export_category("Locomotion")
@export var speed: float = 5.0
@export var steering_angle: float = 1.0
@export var steering_epsilon: float = 0.001
@export var turning_speed: float = 0.25

var is_reversing: bool = false
var is_moving: bool = false
var movement_intent: Vector2
var direction: Vector3

@onready var camera_3d: Camera3D = $Camera3D


func _process(delta: float) -> void:
	if Input.is_action_pressed(&"debug"):
		debug = !debug

	# Making the camera current for testing
	if debug: camera_3d.make_current()

	movement_intent = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backwards")
	direction = Vector3(movement_intent.x, 0, movement_intent.y).normalized()

	_handle_turning(delta)
	_handle_movement(delta) 
	
	if is_reversing != (movement_intent.y < 0.0) or is_moving != (movement_intent.length() > 0.0):
		driver_intention_changed.emit(0.0 != movement_intent.length(), movement_intent.y < 0.0)

	# Takes a Vector2 and use it in 3D space
	is_reversing = direction.z > 0.0
	is_moving = direction.z != 0.0


func _physics_process(_delta: float) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var raycast_result: Dictionary = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, 100., 0.0), global_position - Vector3(0.0, 100., 0.0)
	))

	if "position" in raycast_result:
		global_position = raycast_result.position


func _handle_movement(delta: float) -> void:
	if abs(movement_intent.y) > 0:
		global_position += basis.z * speed * -movement_intent.y * delta


func _handle_turning(delta: float) -> void:
	if Input.is_action_pressed(&"move_left") and direction.z < -0.1:
		if abs(movement_intent.x) > steering_epsilon:
			rotate(Vector3.UP, -(steering_angle * movement_intent.x * turning_speed) * delta)
	if Input.is_action_pressed(&"move_right") and direction.z < -0.1:
		if abs(movement_intent.x) > steering_epsilon:
			rotate(Vector3.UP, -(steering_angle * movement_intent.x * turning_speed) * delta)
	if Input.is_action_pressed(&"move_left") and direction.z > 0.1:
		if abs(movement_intent.x) > steering_epsilon:
			rotate(Vector3.UP, (steering_angle * movement_intent.x * turning_speed) * delta)
	if Input.is_action_pressed(&"move_right") and direction.z > 0.1:
		if abs(movement_intent.x) > steering_epsilon:
			rotate(Vector3.UP, (steering_angle * movement_intent.x * turning_speed) * delta)
