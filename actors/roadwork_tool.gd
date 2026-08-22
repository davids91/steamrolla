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

func trajectory_drawn(_trajectory: PathFollow3D, _duration_sec: float, _call_when_done: Callable) -> void: pass
func prepare_for_runway() -> void: pass
func entered_runway() -> void: pass
func exited_runway() -> void: pass
func set_color(_color: Color) -> void: pass
func set_angle_from_prev_pos(_prev_pos: Vector3) -> void: pass
func set_transform_based_on(target_position: Vector3) -> void:
	global_position = target_position
	set_angle_from_prev_pos(previous_position)

func start_working() -> void:
	is_working = true

func stop_working() -> void:
	is_working = false

func work_at_cursor(target_position: Vector3) -> void:
	is_working = true
	set_transform_based_on(target_position)

@export var default_color: Color = Color.WHITE
@export var tool_enum: ToolPanel.Tools = ToolPanel.Tools.UNKNOWN
@export var normalized_size: Vector2 = Vector2(0.1, 0.1) ## The size of the tool active part within the update shaders
@export_range(0., TAU) var tool_angle: float = 0. ## The persistent angle offset of the tool active part within the update shaders
@export_range(-1., 1.) var tool_strength: float = 0.5 ## The strength of the tool active part within the update shaders
@export_range(0., 1.) var tool_radius: float = 0.1 ## May not always be used
@export_range(0., 1.) var tool_responsiveness: float = 0.9 ## How sharp the tool updates the level
@export var controlled_by: ControlMethods = ControlMethods.DRAGGED

#endregion Common Interface For Roadwork Tools

func reset_color() -> void: set_color(default_color)

@onready var previous_position: Vector3 = global_position
@onready var was_working: bool = is_working
@onready var is_working: bool = false:
	set(v):
		is_working = v
		previous_position = global_position

@export_range(0., 1.) var inv_turn_responsiveness: float = 0.25
func _process(_delta: float) -> void:
	previous_position = lerp(previous_position, global_position, inv_turn_responsiveness)
