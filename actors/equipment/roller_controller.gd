class_name RollerController
extends RoadworkTool

signal driver_intention_changed(is_moving: bool, forward: bool)
signal roller_has_moved(position: Vector3, angle: float, strength: float, strength_from_movement: float)

@export var color_responsiveness: float = 0.075
@export_category("Locomotion")
@export var speed: float = 5.0
@export var steering_angle: float = 1.0
@export var steering_epsilon: float = 0.001
@export var turning_speed: float = 0.25
@export_range(0., 0.9) var strength: float = 0.15
var strength_from_movement: float = 0.

var is_reversing: bool = false
var is_moving: bool = false
var movement_intent: Vector2
var direction: Vector3
var target_color: Color = default_color
var current_color: Color = default_color

@onready var skin: MeshInstance3D = $roller/Roller
#region Common Interface For Roadwork Tools
#TODO: play squeeze sound when RoadworkTool work_at_cursor is called
func set_color(color: Color) -> void:
	target_color = color

func set_angle_from_prev_pos(prev_pos: Vector3) -> void:
	var corrected_prev_pos = Vector3(prev_pos.x, global_position.y, prev_pos.z)
	look_at(global_position + (global_position - corrected_prev_pos))

func start_working() -> void:
	super()
	$OrbitCamera.make_current()

#endregion Common Interface For Roadwork Tools

var is_on_asphalt: bool = false
var was_on_asphalt: bool = is_on_asphalt
var connected_chunk: RoadChunkBody
func _on_asphalt_detector_body_entered(body: Node3D) -> void:
	if not connected_chunk or body is RoadChunkBody:
		connected_chunk = body as RoadChunkBody

func _on_asphalt_detector_body_exited(body: Node3D) -> void:
	if body == connected_chunk: connected_chunk = null

var moving_transparency_modifier: float = 0.
func _physics_process(delta: float) -> void:
	if controlled_by != ControlMethods.PILOTED and not is_working: return
	movement_intent = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backwards")
	direction = Vector3(movement_intent.x, 0, movement_intent.y).normalized()

	_handle_turning(delta)
	_handle_movement(delta) 

	if is_reversing != (direction.z > 0.0) or is_moving != (direction.z != 0.0):
		driver_intention_changed.emit(direction.z != 0.0, direction.z > 0.0)

	if connected_chunk: is_on_asphalt = connected_chunk.is_on_asphalt(global_position)
	if(
		is_reversing != (direction.z > 0.0) or is_moving != (direction.z != 0.0)
		or was_on_asphalt != is_on_asphalt
	):
		var sound_should_be_playing: bool = (direction.z != 0.0) and is_on_asphalt
		if sound_should_be_playing: # Play from a random time within the length of the audio stream if not already playing
			if not $SqueezeSound.playing:
				$SqueezeSound.play(randf() * 1.89)
		else: $SqueezeSound.stop()

	# Takes a Vector2 and use it in 3D space
	is_reversing = direction.z > 0.0
	is_moving = direction.z != 0.0

	was_on_asphalt = is_on_asphalt

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var raycast_result: Dictionary = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, 100., 0.0), global_position - Vector3(0.0, 100., 0.0)
	))
	if "position" in raycast_result:
		global_position.y = raycast_result.position.y

func _process(_delta: float) -> void:
	var movement_direction: Vector3 = (basis.z * -movement_intent.y).normalized()
	var camera_direction: Vector3 = ($OrbitCamera.get_view_origin() - global_position)
	if 0. > movement_direction.dot(camera_direction): moving_transparency_modifier = -1.
	else: moving_transparency_modifier = 0.
	current_color = lerp(
		current_color, Color(target_color.r, target_color.g, target_color.b, target_color.a + moving_transparency_modifier),
		color_responsiveness
	)
	skin.get_active_material(0).albedo_color = current_color

func _handle_movement(delta: float) -> void:
	if abs(movement_intent.y) > 0:
		global_position += basis.z * speed * -movement_intent.y * delta
		var angle: float = -rotation.y + PI / 2.0 * (-1.0 if is_reversing else 1.0)
		roller_has_moved.emit(global_position, angle, strength, strength_from_movement)

func _handle_turning(delta: float) -> void:
	if(abs(movement_intent.x) <= steering_epsilon or abs(direction.z) <= 0.1): return
	rotate(Vector3.UP, signf(direction.z) * steering_angle * movement_intent.x * turning_speed * delta)

func _on_roller_driver_intention_changed(_is_moving: bool, _forward: bool) -> void:
	strength_from_movement = 1. if _is_moving else 0.
