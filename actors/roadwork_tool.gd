class_name RoadWorkTool
extends Node3D

#region Common Interface For Roadwork Tools
func set_color(_color: Color) -> void: pass
func set_angle_from_prev_pos(_prev_pos: Vector3) -> void: pass
func set_transform_based_on(target_position: Vector3) -> void:
	global_position = target_position
	set_angle_from_prev_pos(previous_position)

func stop_working() -> void:
	is_working = false
	set_color(Color.TRANSPARENT)

func work_at(target_position: Vector3) -> void:
	if not is_working:
		is_working = true
		set_color(Color.WHITE)
	set_transform_based_on(target_position)

@export var tool_enum: ToolPanel.Tools = ToolPanel.Tools.UNKNOWN
@export var normalized_size: Vector2 = Vector2(0.1, 0.1) ## The size of the tool active part within the update shaders
@export var tool_angle: float = 0. ## The persistent angle offset of the tool active part within the update shaders
@export var tool_strength: float = 0.5 ## The strength of the tool active part within the update shaders
@export var tool_radius: float = 0.1 ## May not always be used
#endregion Common Interface For Roadwork Tools

@onready var previous_position: Vector3 = global_position
@onready var was_working: bool = is_working
@onready var is_working: bool = false:
	set(v):
		is_working = v
		previous_position = global_position

func _ready() -> void:
	set_color(Color.TRANSPARENT)

@export_range(0., 1.) var inv_turn_responsiveness: float = 0.25
func _process(_delta: float) -> void:
	previous_position = lerp(previous_position, global_position, inv_turn_responsiveness)
