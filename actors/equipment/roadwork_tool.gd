class_name RoadworkTool
extends Node3D

#region Common Interface For Roadwork Tools
enum ControlMethods{
	## Tool is Dragged by mouse
	DRAGGED,

	## Tool is controlled through a @Trajectory
	## the function trajectory_drawn should be connected to @Trajectory:trajectory_drawn
	DRAWN,

	## Tool is controlled by a custom controller
	PILOTED
}

@export var default_color: Color = Color.WHITE
@export var tool_enum: ToolPanel.Tools = ToolPanel.Tools.UNKNOWN
@export var normalized_size: Vector2 = Vector2(0.1, 0.1) ## The size of the tool active part within the update shaders
@export_range(0., TAU) var tool_angle: float = 0. ## The persistent angle offset of the tool active part within the update shaders
@export_range(-1., 1.) var tool_strength: float = 0.5 ## The strength of the tool active part within the update shaders
@export_range(0., 1.) var tool_radius: float = 0.1 ## May not always be used
@export_range(0., 1.) var tool_responsiveness: float = 0.9 ## How sharp the tool updates the level
@export var controlled_by: ControlMethods = ControlMethods.DRAGGED

func prepare_for_runway() -> void: pass
func entered_runway() -> void: pass
func exited_runway() -> void: pass
func set_color(_color: Color) -> void: pass
func reset_color() -> void: set_color(default_color)
func set_angle_from_prev_pos(_prev_pos: Vector3) -> void: pass
func set_transform_based_on(target_position: Vector3) -> void:
	global_position = target_position
	set_angle_from_prev_pos(previous_position)

func start_working() -> void:
	is_working = true

func stop_working() -> void:
	is_working = false

#endregion

#region Interface for Roadwork tools dragged by the mouse
func work_at_cursor(target_position: Vector3) -> void:
	if controlled_by != ControlMethods.DRAGGED: return
	is_working = true
	set_transform_based_on(target_position)
#endregion

#region Interface for Roadwork tools moved by a drawn trajectory
var trajectory_tween: Tween
var trajectory_reference_pos: Vector3
func trajectory_drawn(trajectory: PathFollow3D, duration_sec: float, call_when_done: Callable) -> void:
	# Do not start when not configured for this control, or multiple times at once
	if controlled_by != ControlMethods.DRAWN or trajectory_tween: return

	trajectory.progress_ratio = 0.
	global_position = trajectory.global_position
	set_color(default_color)
	start_working()
	trajectory_reference_pos = global_position
	get_tree().create_timer(0.0).timeout.connect(func():
		trajectory_tween = create_tween()
		trajectory_tween.tween_method(
			func(w: float):
				trajectory.progress_ratio = w
				trajectory_reference_pos = lerp(global_position, trajectory_reference_pos, inv_turn_responsiveness)
				global_position = trajectory.global_position
				set_angle_from_prev_pos(trajectory_reference_pos),
			0., 1., duration_sec
		).set_ease(Tween.EASE_IN_OUT).finished.connect(func():
			stop_working()
			set_color(Color.TRANSPARENT)
			trajectory_tween = null
			call_when_done.call()
		)
	)
#endregion

#region Piloted Roadwork tools
signal driver_intention_changed(is_moving: bool, forward: bool)

@export_category("Piloted Locomotion")
@export var speed: float = 5.0
@export var steering_angle: float = 1.0
@export var steering_epsilon: float = 0.001
@export var turning_speed: float = 0.25

var is_reversing: bool = false
var is_moving: bool = false
var movement_intent: Vector2
var direction: Vector3

func handle_movement(delta: float) -> void:
	if abs(movement_intent.y) > 0:
		global_position += basis.z * speed * -movement_intent.y * delta

func handle_turning(delta: float) -> void:
	if(abs(movement_intent.x) <= steering_epsilon or abs(direction.z) <= 0.1): return
	rotate(Vector3.UP, signf(direction.z) * steering_angle * movement_intent.x * turning_speed * delta)

func _physics_process(delta: float) -> void:
	if controlled_by != ControlMethods.PILOTED and not is_working: return
	movement_intent = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backwards")
	direction = Vector3(movement_intent.x, 0, movement_intent.y).normalized()

	handle_turning(delta)
	handle_movement(delta) 

	if is_reversing != (direction.z > 0.0) or is_moving != (direction.z != 0.0):
		driver_intention_changed.emit(direction.z != 0.0, direction.z > 0.0)

	is_reversing = direction.z > 0.0
	is_moving = direction.z != 0.0
#endregion

@onready var previous_position: Vector3 = global_position
@onready var was_working: bool = is_working
@onready var is_working: bool = false:
	set(v):
		is_working = v
		previous_position = global_position

@export_range(0., 1.) var inv_turn_responsiveness: float = 0.25

func _process(_delta: float) -> void:
	previous_position = lerp(previous_position, global_position, inv_turn_responsiveness)
