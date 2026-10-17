class_name BaseLevel
extends Node3D

@export var accepted_asphalt_deviation: float = 0.005
@export var level_objectives: Dictionary[String, String] = {
	"asphalt_done": "Fix road surface",
}
@export var level_objective_photos: Array[Texture] = []
@export var transition_time_sec: float = 0.5

@onready var base_dir: String = LevelStructure.get_base_dir_for_scene(self)
func _ready() -> void:
	# Handle Objectives
	LevelStructure.level_attribute_list_overwrite(base_dir, level_objectives)
	%RoadChunk.deviation_threshold = accepted_asphalt_deviation

	# Setup HUD
	$HUD.base_dir = base_dir
	$HUD.set_objectives(level_objectives, level_objective_photos)

	# Handle Screen blocker
	%ScreenBlocker.modulate = Color.WHITE
	create_tween().tween_property(%ScreenBlocker, "modulate", Color.TRANSPARENT, transition_time_sec)

func periodic_objective_check() -> void: pass # For levels to overwrite!

@export var objective_check_interval_sec : float = 0.5
var time_left_to_check_sec: float = objective_check_interval_sec
func _process(delta: float) -> void:
	time_left_to_check_sec -= delta
	if 0. > time_left_to_check_sec:
		time_left_to_check_sec = objective_check_interval_sec
		periodic_objective_check()

var victory_tween: Tween:
	set(v):
		if victory_tween: victory_tween.kill()
		victory_tween = v

@export var road_paint_display_pause_sec: float = 0.01
@export var max_snap_value: float = 0.6
@export var snap_time_sec: float = 0.6
@export var snap_easing: float = 1.0
func _on_hud_objective_completed(objective_name: String) -> void:
	if objective_name == "asphalt_done":
		victory_tween = create_tween()

		# Start asphalt snapping to reference and lighting up the road
		victory_tween.tween_callback(func():
			var snap_tween: Tween = create_tween()
			snap_tween.tween_method(func(w: float):
				%RoadChunk.snap_to_reference(ease(w, snap_easing))
				%RoadChunk.update_asphalt(),
				0., max_snap_value, snap_time_sec
			)
			snap_tween.tween_callback(func():
				%RoadChunk.snap_to_reference(0.)
				%RoadChunk.save_user_data()
				%RoadChunk.asphalt_editable = false
			)
			var flash_tween: Tween = create_tween()
			flash_tween.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 1.3)
			flash_tween.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 0.15)
			flash_tween.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 0.15)
		)
		victory_tween.tween_callback(func():
			while ($RoadPaint.show_random()):
				await get_tree().create_timer(road_paint_display_pause_sec).timeout
		)

const LEVEL_SELECT_SCENE_TEMPLATE: PackedScene = preload("res://core/scenes/menus/level_select.tscn")
@onready var level_container: Node = get_node("/root/Main/LevelContainer")
func _on_hud_exit_scene() -> void: # Exit the scene when there's no active tool
	if $ToolController.active_tool != ToolPanel.Tools.UNKNOWN: return
	create_tween().tween_property(%ScreenBlocker, "modulate", Color.WHITE, transition_time_sec)
	get_tree().create_timer(transition_time_sec).timeout.connect(func():
		for c in level_container.get_children(): c.queue_free()
		var level_select_scene: LevelSelectScene = LEVEL_SELECT_SCENE_TEMPLATE.instantiate()
		level_select_scene.coming_from = base_dir.get_file()
		level_container.add_child(level_select_scene)
	)
