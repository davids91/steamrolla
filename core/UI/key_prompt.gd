extends Sprite3D

@export var action: String = "deploy_payload"
@export var time_to_disappear_sec: float = 1.7
@export var time_to_switch_frame_sec: float = 0.7
@export var frame_delta: Vector2 = Vector2(0., 128.)
@export var frame_count: int = 2
@export var show_tooltip_count: int = 2

@onready var original_region: Rect2 = texture.region
var displays_left: int = show_tooltip_count
func _ready() -> void:
	if LevelStructure.level_attribute_present("key_prompt", action):
		var readout = LevelStructure.level_attribute_data_read("key_prompt", action)
		if readout is int: displays_left = int(readout)
		if displays_left <= 0: queue_free()
	else: LevelStructure.level_attribute_store("key_prompt", action, displays_left)

var is_enabled: bool = false
var already_activated: bool = false
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(action) and not already_activated:
		already_activated = true
		displays_left = max(0, displays_left - 1)
		LevelStructure.level_attribute_store("key_prompt", action, displays_left)
		create_tween().tween_property(self, "modulate", Color.TRANSPARENT, time_to_disappear_sec).finished.connect(
			func(): queue_free()
		)

var current_frame: int = 0
var time_left_sec: float = 0.
func _process(delta: float) -> void:
	visible = is_enabled
	if not is_enabled: return
	time_left_sec -= delta
	if 0. > time_left_sec:
		time_left_sec = time_to_switch_frame_sec
		current_frame = (current_frame + 1) % frame_count
		texture.region.position = original_region.position + float(current_frame) * frame_delta
