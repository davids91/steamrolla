class_name RollerController extends CrewMember


signal driver_intention_changed(is_moving: bool, forward: bool)

@export var debug: bool

@export_category("Opacity")
@export var opacity: float = 0.4:
	set(v):
		opacity = v
		if skin: skin.get_active_material(0).albedo_color.a = opacity
@export var trasparency_responsiveness: float = 0.075

@export var normalized_roller_size: Vector2 = Vector2(0.115, 0.075) ## The size of the roller within the update shaders

@export_category("Locomotion")
@export var speed: float = 5.0
@export var steering_angle: float = 1.0
@export var steering_epsilon: float = 0.001
@export var turning_speed: float = 0.25

var is_reversing: bool = false
var is_moving: bool = false
var movement_intent: Vector2
var direction: Vector3
var target_transparency: float = 1.
var current_transparency: float = 1.

@onready var camera_3d: Camera3D = $Camera3D
@onready var skin: MeshInstance3D = $roller/Roller

var is_on_asphalt: bool = false
var was_on_asphalt: bool = is_on_asphalt
func _on_asphalt_detector_body_entered(body: Node3D) -> void:
	if body.has_method("is_on_asphalt"): # and body.is_on_asphalt(global_position):
		is_on_asphalt = true

func _on_asphalt_detector_body_exited(body: Node3D) -> void:
	if body.has_method("is_on_asphalt") and not body.is_on_asphalt(global_position):
		is_on_asphalt = false

func _process(delta: float) -> void:
	target_transparency = 1.
	if Input.is_action_just_pressed(&"debug"):
		debug = !debug

	# Making the camera current for testing
	if debug: camera_3d.make_current()

	movement_intent = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backwards")
	direction = Vector3(movement_intent.x, 0, movement_intent.y).normalized()

	_handle_turning(delta)
	_handle_movement(delta) 

	if is_reversing != (direction.z > 0.0) or is_moving != (direction.z != 0.0):
		driver_intention_changed.emit(direction.z != 0.0, direction.z > 0.0)

	if(
		is_reversing != (direction.z > 0.0) or is_moving != (direction.z != 0.0)
		or was_on_asphalt != is_on_asphalt
	):
		var sound_should_be_playing: bool = direction.z != 0.0 and is_on_asphalt
		if sound_should_be_playing: # Play from a random time within the length of the audio stream if not already playing
			if not $SqueezeSound.playing: $SqueezeSound.play(randf() * 1.89)
		else: $SqueezeSound.stop()

	# Takes a Vector2 and use it in 3D space
	is_reversing = direction.z > 0.0
	is_moving = direction.z != 0.0

	was_on_asphalt = is_on_asphalt

	if 0. < movement_intent.length(): target_transparency = 0.
	current_transparency = lerp(current_transparency, target_transparency, trasparency_responsiveness)
	skin.get_active_material(0).albedo_color.a = current_transparency


func _physics_process(_delta: float) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var raycast_result: Dictionary = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, 100., 0.0), global_position - Vector3(0.0, 100., 0.0)
	))

	if "position" in raycast_result:
		global_position = raycast_result.position


func _handle_movement(delta: float) -> void:
	if abs(movement_intent.y) > 0 and 0 == front_blocking_object_count:
		global_position += basis.z * speed * -movement_intent.y * delta


func _handle_turning(delta: float) -> void:
	if(
		abs(movement_intent.x) <= steering_epsilon
		or (movement_intent.x < 0. and 0 < left_blocking_object_count)
		or (movement_intent.x > 0. and 0 < right_blocking_object_count)
		or abs(direction.z) <= 0.1
	): return
	rotate(Vector3.UP, signf(direction.z) * steering_angle * movement_intent.x * turning_speed * delta)

var front_blocking_object_count: int = 0
func _on_blocker_detector_front_body_entered(_body: Node3D) -> void:
	front_blocking_object_count += 1

func _on_blocker_detector_front_body_exited(_body: Node3D) -> void:
	front_blocking_object_count -= 1

var left_blocking_object_count: int = 0
func _on_blocker_detector_left_body_entered(_body: Node3D) -> void:
	left_blocking_object_count += 1

func _on_blocker_detector_left_body_exited(_body: Node3D) -> void:
	left_blocking_object_count -= 1

var right_blocking_object_count: int = 0
func _on_blocker_detector_right_body_entered(_body: Node3D) -> void:
	right_blocking_object_count += 1

func _on_blocker_detector_right_body_exited(_body: Node3D) -> void:
	right_blocking_object_count -= 1
