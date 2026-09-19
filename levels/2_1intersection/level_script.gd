extends Node3D

var level_attributes: Dictionary[String, String] = {
	"asphalt_done": "Fix the pothole"
}

@onready var base_dir: String = LevelStructure.get_base_dir_for_scene(self)
func _ready() -> void:
	$HUD.set_objectives(level_attributes, base_dir)
	LevelStructure.level_attribute_list_overwrite(base_dir, level_attributes)

var victory_tween: Tween:
	set(v):
		if victory_tween: victory_tween.kill()
		victory_tween = v

@export var road_paint_display_pause_sec: float = 0.01
@export var max_snap_value: float = 0.6
@export var snap_time_sec: float = 0.6
@export var snap_easing: float = 1.0
func _on_hud_objective_completed(objective_name: String) -> void:
	%RoadChunk.save_user_data()
	if objective_name == "asphalt_done":
		victory_tween = create_tween()

		# Start asphalt snappinmg to reference and lighting up the road
		victory_tween.tween_callback(func():
			var snap_tween: Tween = create_tween()
			snap_tween.tween_method(func(w: float):
				%RoadChunk.snap_to_reference(ease(w, snap_easing))
				%RoadChunk.update_asphalt(),
				0., max_snap_value, snap_time_sec
			)
			snap_tween.tween_callback(func(): %RoadChunk.snap_to_reference(0.))
			var flash_tween: Tween = create_tween()
			flash_tween.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 1.3)
			flash_tween.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 0.15)
			flash_tween.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 0.15)
		)
		victory_tween.tween_callback(func():
			while ($RoadPaint.show_random()):
				await get_tree().create_timer(road_paint_display_pause_sec).timeout
		)
