extends Node3D

@export_range(0., 0.9) var roller_strength: float = 0.15

func _ready() -> void:
	$RoadChunk.update_materials()

var elapsed_time: float = 0.
func _process(delta: float) -> void:
	elapsed_time += delta
	var flat_chunk_size: Vector2 = Vector2(%RoadChunk.get_size().x, %RoadChunk.get_size().z)
	var texture_coordinates: Vector2 = (
		Vector2($Roller.global_position.x, $Roller.global_position.z)
		 - Vector2(%RoadChunk.global_position.x, %RoadChunk.global_position.z)
		+ flat_chunk_size * 0.5
	) / flat_chunk_size
	var roller_angle = -$Roller.rotation.y + PI / 2.
	if $Roller.is_reversing: roller_angle -= PI
	$RoadChunk.set_roller_brush(texture_coordinates, roller_angle, roller_strength * roller_strength_from_movement)
	$RoadChunk.update_asphalt()

@export var level_scan_duration_sec: float = 0.7
@export var level_scan_range: float = 0.25
@export var accepted_deviation: float = 0.001
@export var asphalt_snap_to_target_speed: float = 0.05
func _on_check_btn_button_down() -> void:
	if not %RoadChunk.scan_in_progress():
		%RoadChunk.initiate_scan(level_scan_duration_sec, level_scan_range, func():
			var deviation: float = %RoadChunk.get_deviation_from_target()
			print(abs(deviation - 0.5)) #DEBUG: To see what would be the acepted level of deviation
			if(1. > accepted_deviation):
				var winning_animation: Tween = create_tween()
				create_tween().tween_method(
					func(w: float): %RoadChunk.snap_to_reference(w), 0., 0.15, 0.55
				).set_ease(Tween.EASE_IN_OUT).finished.connect(func(): %RoadChunk.snap_to_reference(0.))
				winning_animation.tween_callback(func(): $SuccessLevel.play())
				winning_animation.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 1.3)
				winning_animation.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 0.15)
				winning_animation.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 0.15)
				winning_animation.tween_callback(_have_road_paint_appear)
			else: $BotchLevel.play()
		)

@export var road_paint_animation_curve: Curve
func _have_road_paint_appear(animation_length: float = 0.7) -> void:
	create_tween().tween_method(
		func(w: float):
			$WalkWay1.mesh.size.x = road_paint_animation_curve.sample(w) * 3.
			$WalkWay1.mesh.size.y = road_paint_animation_curve.sample(w) * 1.
			$RoadPaint.mesh.size.x = road_paint_animation_curve.sample(w) * 0.1
			$RoadPaint.mesh.size.y = road_paint_animation_curve.sample(w) * 32.25,
		0., 1., animation_length
	).set_ease(Tween.EASE_IN_OUT)

var roller_strength_from_movement: float = 0.
func _on_roller_driver_intention_changed(is_moving: bool, _forward: bool) -> void:
	roller_strength_from_movement = 1. if is_moving else 0.
