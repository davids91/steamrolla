class_name BaseLevel
extends Node3D

@export var accepted_asphalt_deviation: float = 0.005
@export var level_objectives: Dictionary[String, String] = {
	"asphalt_done": "Fix road surface", "traffic_ok": "No crashed cars",
}
@export var level_objective_photos: Array[Texture] = []
@export var transition_time_sec: float = 0.5
@export var max_cars_count: int = 30

@onready var base_dir: String = LevelStructure.get_base_dir_for_scene(self)
func _ready() -> void:
	# Handle permanent objects
	var car_transform_readouts = LevelStructure.level_attribute_data_read(base_dir,"contained_cars")
	if car_transform_readouts is Array[Transform3D]:
		for t in car_transform_readouts:
			var car: MovingCar = preload("res://actors/moving_car.tscn").instantiate()
			add_child(car)
			car.global_transform = t
			car.crashed = true

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

var contained_traffic: Array[MovingCar] = []
func _on_hud_exit_scene() -> void: # Exit the scene when there's no active tool
	if(
		$ToolController.active_tool != ToolPanel.Tools.UNKNOWN
		and $ToolController.tool_nodes[$ToolController.active_tool].controlled_by == RoadworkTool.ControlMethods.DRAGGED
	): return

	# Save permanent objects
	var car_transforms: Array[Transform3D] = []
	for car in contained_traffic: car_transforms.push_back(car.global_transform)
	LevelStructure.level_attribute_store(base_dir, "contained_cars", car_transforms)

	# Start exit transition
	var transition = create_tween()
	transition.tween_property(%ScreenBlocker, "modulate", Color.WHITE, transition_time_sec)
	transition.tween_callback(SceneManager.return_to_level_select.bind(base_dir))

func _on_out_of_bounds_checker_body_entered(body: Node3D) -> void:
	if body is MovingCar:
		contained_traffic.push_back(body)
		for m in get_tree().get_nodes_in_group("TrafficMakers"):
			m.is_active = max_cars_count > contained_traffic.size()

func _on_out_of_bounds_checker_body_exited(body: Node3D) -> void:
	if body is MovingCar:
		contained_traffic.erase(body)
		body.queue_free()
		for m in get_tree().get_nodes_in_group("TrafficMakers"):
			m.is_active = max_cars_count > contained_traffic.size()
	elif body is RoadworkTool:
		$ToolController/Runway.may_be_outside_bounds(body)
