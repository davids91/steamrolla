class_name SteamRollerController extends Node3D


signal driver_intention_changed(is_moving: bool, forward: bool)

@export var opacity: float = 0.4:
	set(v):
		opacity = v
		if $Skin: $Skin.get_active_material(0).albedo_color.a = opacity
@export var speed: float = 1.
@export var steering_angle: float = 1.
@export var steering_epsilon: float = 0.001

var is_reversing: bool = false
var is_moving: bool = false
var movement_intent: Vector2


func _unhandled_input(_event: InputEvent) -> void:
	movement_intent = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backwards")
	
	if is_reversing != (movement_intent.y < 0.) or is_moving != (movement_intent.length() > 0.):
		driver_intention_changed.emit(0. != movement_intent.length(), movement_intent.y < 0.)
	
	is_reversing = (movement_intent.y < 0.)
	is_moving = (movement_intent.length() > 0.)


func _process(delta: float) -> void:
	if abs(movement_intent.x) > steering_epsilon:
		rotate(Vector3.UP, -steering_angle * movement_intent.x * delta)

	if abs(movement_intent.y) > 0:
		global_position -= basis.z * speed * movement_intent.y


func _physics_process(_delta: float) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var raycast_result: Dictionary = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0., 100., 0.), global_position - Vector3(0., 100., 0.)
	))

	if "position" in raycast_result:
		global_position = raycast_result.position
	
