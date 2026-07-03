@tool
extends Node3D

#region editor helper functionality
@export_file("*.res") var level_data: String:
	set(v):
		level_data = v
		if not %RoadChunk: return
		%RoadChunk.level_data = load(v)
		%RoadChunk.update_materials()

static func _asphalt_quantity_tex_path(base_dir: String)-> String:
	return base_dir + "/asphalt_quantity.png"

@export var load_level_data: bool = false:
	set(_v): # Fill up %RoadChunk with data
		%RoadChunk.level_data = ResourceLoader.load(level_data)
		var asphalt_image_path: String = _asphalt_quantity_tex_path(level_data.get_base_dir())
		if not %RoadChunk.level_data.asphalt_quantity_texture and FileAccess.file_exists(asphalt_image_path):
			%RoadChunk.level_data.asphalt_quantity_texture = load(asphalt_image_path)
		%RoadChunk.update_materials()

@export var save_level_data: bool = false:
	set(_v):
		if not Engine.is_editor_hint() or not %RoadChunk: return
		var asphalt_image_path = level_data.get_base_dir() + "/"
		%RoadChunk.current_asphalt_level.save_png(asphalt_image_path)
		EditorInterface.get_resource_filesystem().scan() # This makes itch export crash
		%RoadChunk.level_data.asphalt_quantity_texture = ResourceLoader.load(asphalt_image_path)
		get_tree().create_timer(1.).timeout.connect(func():ResourceSaver.save(%RoadChunk.level_data, level_data))

@export var noise: FastNoiseLite = FastNoiseLite.new()
@export var starting_asphalt_level_normalized: float = 0.2
@export var height_unit: float = 0.5:
	set(v):
		height_unit = v
		if Engine.is_editor_hint():
			%RoadChunk.height_unit = height_unit
			%RoadChunk.update_materials()

@export var call_update_materials: bool = false:
	set(_v): %RoadChunk.update_materials()

@export var call_update_physics: bool = false:
	set(_v): %RoadChunk.update_level_physics()

@export var update_asphalt: bool = false:
	set(_v):
		%RoadChunk.update_asphalt()
		%RoadChunk.update_level_physics()

@export var empty_asphalt_image: bool = false:
	set(_v):
		%RoadChunk.set_asphalt_to_empty()
		%RoadChunk.update_level_physics()

@export var regenerate_asphalt_image: bool = false:
	set(_v):
		noise.seed = randi()
		%RoadChunk.randomize_asphalt(noise, starting_asphalt_level_normalized)
		%RoadChunk.update_level_physics()

@export_range(0., 1.) var reference_asphalt_height: float = starting_asphalt_level_normalized
@export var set_asphalt_to_reference_height: bool = false:
	set(_v):
		%RoadChunk.randomize_asphalt(noise, reference_asphalt_height, 0.)

@export var take_current_asphalt_state_as_target: bool = false:
	set(_v):
		%RoadChunk.set_target()

@export var max_snap_value: float = 0.6
@export var snap_time_sec: float = 0.6
@export var start_snapping_to_ref: bool = false:
	set(_v): _snap_asphalt_to_reference()

@export_range(0., 1.) var snap_to_reference: float = false:
	set(v):
		snap_to_reference = v
		%RoadChunk.snap_to_reference(v)
		%RoadChunk.update_asphalt()

var crazify_tween: Tween
@export var crazify: bool = false:
	set(v):
		crazify = v
		if not %RoadChunk: return
		if crazify_tween: crazify_tween.kill()
		if not crazify:
			var _crazify_amount: float = crazify_amount
			create_tween().tween_method(func(w: float): crazify_amount = w, _crazify_amount, 0., 0.7)
		else:
			crazify_tween = create_tween()
			crazify_tween.tween_method(func(w: float): crazify_amount = w * crazify_amount, 0., 1., 0.45)
			crazify_tween.tween_method(func(w: float): crazify_amount = w * crazify_amount, 1., 0., 0.45)
			crazify_tween.set_loops(-1)

@export var crazify_amount: float = 0:
	set(v):
		crazify_amount = v
		if not %RoadChunk: return
		%RoadChunk.set_crazify_amount(crazify_amount)

@export var crazify_scale: float = 0:
	set(v):
		crazify_scale = v
		if not %RoadChunk: return
		%RoadChunk.set_crazify_scale(crazify_amount)

@export var crazify_speed: float = 0:
	set(v):
		crazify_speed = v
		if not %RoadChunk: return
		%RoadChunk.set_crazify_speed(crazify_amount)

@export var level_scan_duration_sec: float = 1.3
@export var level_scan_range: float = 0.25
@export var scan_for_height: bool = false:
	set(_v):
		if not %RoadChunk: return
		%RoadChunk.initiate_scan(level_scan_duration_sec, level_scan_range)

@export_range(0., 1.) var draw_radius: float = 0.03
@export_range(0., 0.9) var compacting_strength: float = 0.015
@export_range(0., 10.) var draw_strength: float = 0.15
@export_range(0., 10.) var asphalt_addition: float = 0.25
@export_range(0., 10.) var asphalt_removal: float = 0.25

#endregion editor helper functionality

@export var road_paint_animation_curve: Curve
func _have_road_paint_appear(animation_length: float = 0.7) -> void:
	create_tween().tween_method(
		func(w: float):
			$RoadPaint.mesh.size.x = road_paint_animation_curve.sample(w) * 20.
			$RoadPaint.mesh.size.y = road_paint_animation_curve.sample(w) * 0.5,
		0., 1., animation_length
	).set_ease(Tween.EASE_IN_OUT)

func _snap_asphalt_to_reference() -> void:
	var snap: Tween = create_tween() # snap_to_reference setter includes logic for shader updates
	snap.tween_method(func(w: float): snap_to_reference = w, 0., max_snap_value, snap_time_sec).set_ease(Tween.EASE_IN)
	snap.tween_method(func(w: float): snap_to_reference = w, max_snap_value, 0.0, snap_time_sec).set_ease(Tween.EASE_OUT)
	snap.tween_callback(func(): snap_to_reference = 0.)

var dragging: bool = false
var smoothing: bool = false:
	set(v):
		if smoothing != v and not Engine.is_editor_hint():
			if v: $Compactor.set_color(Color.WHITE)
			else: $Compactor.set_color(Color.TRANSPARENT)
		smoothing = v

@export var accepted_deviation: float = 0.001
@export var asphalt_snap_to_target_speed: float = 0.05
var won_game: bool = false
var asphalt_delta: float = 0.
var shoveling_asphalt: bool = false
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select") and not won_game and not %RoadChunk.scan_in_progress():
		%RoadChunk.initiate_scan(level_scan_duration_sec, level_scan_range, func():
			var deviation: float = %RoadChunk.get_deviation_from_target()
			if(abs(deviation - 0.5) < accepted_deviation):
				won_game = true
				var winning_animation: Tween = create_tween()
				_snap_asphalt_to_reference()
				winning_animation.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 1.3)
				winning_animation.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 0.15)
				winning_animation.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 0.15)
				winning_animation.tween_callback(_have_road_paint_appear)
		)
	elif event.is_action_pressed("ui_select"):
		won_game = false
		$RoadPaint.mesh.size.x = 0.
		$RoadPaint.mesh.size.y = 0.

	# Cast mouse position on click to world coordinates
	if event is InputEventMouseButton:
		dragging = event.is_pressed() or asphalt_delta != 0.
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			asphalt_delta = asphalt_addition
			$ShovelSound.play()
			shoveling_asphalt = true
		if event.button_index == MOUSE_BUTTON_RIGHT and event.double_click:
			asphalt_delta = -asphalt_removal
			$ShovelSound.play()
			shoveling_asphalt = true
		if not event.pressed: 
			dragging = false
			smoothing = false

func _ready() -> void:
	$RoadChunk.use_roller(false)
	%RoadChunk.set_update_brush_radius(draw_radius)
	%RoadChunk.update_materials()

const asphalt_removal_delay_sec: float = 0.25
const smoothing_click_length_needed_sec: float = 0.25
var time_left_for_smoothing_click_sec: float = smoothing_click_length_needed_sec
var time_to_remove_asphalt_sec: float = asphalt_removal_delay_sec
func _process(delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		time_left_for_smoothing_click_sec -= delta
	else: time_left_for_smoothing_click_sec = smoothing_click_length_needed_sec
	smoothing = 0. >= time_left_for_smoothing_click_sec
	
	# Handle Asphalt addition/removal
	if 0. != asphalt_delta:
		if 0. > asphalt_delta and time_to_remove_asphalt_sec > 0.:
			time_to_remove_asphalt_sec -= delta
		else:
			asphalt_delta *= 0.85
			if abs(asphalt_delta) < 0.1: asphalt_delta = 0.
			if 0. == asphalt_delta: dragging = false
		%RoadChunk.set_update_brush_amount(asphalt_delta * delta)
	else:
		%RoadChunk.set_update_brush_radius(draw_radius)
		time_to_remove_asphalt_sec = asphalt_removal_delay_sec

# The asphalt level modified by the user
@onready var last_smoothed_position: Vector3 = $Compactor.global_position
@export_range(0., 1.) var smush_responsiveness: float = 0.25
@export_range(0., 5.) var shovel_icon_duration_sec: float = 1.
@export var shovel_icon_travel_distance: float = 2.
@export var shovel_icon_y_offset: float = 2.
@export var shovel_icon_dig_travel_y: Curve
@export var shovel_icon_fill_travel_y: Curve
var was_smoothing: bool = smoothing
func _physics_process(_delta: float) -> void:
	if smoothing or dragging or 0. != asphalt_delta:
		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var mouse_screen_position: Vector2 = get_viewport().get_mouse_position()
		var origin_global_pos: Vector3 = $Camera3D.project_ray_origin(mouse_screen_position)
		var ray_direction: Vector3 = $Camera3D.project_ray_normal(mouse_screen_position)
		var raycast_result: Dictionary = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			origin_global_pos, origin_global_pos + ray_direction * 50.
		))
		if "position" in raycast_result:
			if shoveling_asphalt:
				$ShovelIcon.modulate = Color.WHITE
				if asphalt_delta < 0.: # Digging
					var shovel_icon_start_position: Vector3 = raycast_result.position + Vector3(0., shovel_icon_y_offset, 0.)
					$ShovelIcon.global_position = shovel_icon_start_position
					create_tween().tween_method(
						func(w: float):
							$ShovelIcon.global_position = (
								shovel_icon_start_position
								+ Vector3(0., shovel_icon_dig_travel_y.sample(w) * shovel_icon_travel_distance, 0.)
							),
						0., 1., shovel_icon_duration_sec
					).set_ease(Tween.EASE_IN_OUT)
				else:
					var shovel_icon_start_position: Vector3 = (
						raycast_result.position
						+ Vector3(0., shovel_icon_travel_distance + shovel_icon_y_offset, 0.)
					)
					$ShovelIcon.global_position = shovel_icon_start_position
					create_tween().tween_method(
						func(w: float):
							$ShovelIcon.global_position = (
								shovel_icon_start_position
								+ Vector3(0., shovel_icon_fill_travel_y.sample(w) * shovel_icon_travel_distance, 0.)
							),
						0., 1., shovel_icon_duration_sec
					).set_ease(Tween.EASE_IN_OUT)
				create_tween().tween_property(
					$ShovelIcon, "modulate", Color.TRANSPARENT,
					shovel_icon_duration_sec
				)
				shoveling_asphalt = false
				return
			if not was_smoothing: last_smoothed_position = raycast_result.position
			else: last_smoothed_position = lerp(last_smoothed_position, raycast_result.position, smush_responsiveness)
			if 2.5 > (last_smoothed_position- $consty.global_position).length(): $consty.smoosh()
			elif $consty.is_being_smooshed(): $consty.unsmoosh()
			var flat_chunk_size: Vector2 = Vector2(%RoadChunk.get_size().x, %RoadChunk.get_size().z)
			var texture_coordinates: Vector2 = (
				Vector2(last_smoothed_position.x, last_smoothed_position.z)
				 - Vector2(%RoadChunk.global_position.x, %RoadChunk.global_position.z)
				+ flat_chunk_size * 0.5
			) / flat_chunk_size

			# Set roller position and udpate brush
			var roller_delta_pos: Vector3 = last_smoothed_position - $Compactor.global_position
			%RoadChunk.set_roller_brush(
				texture_coordinates,
				Vector2(roller_delta_pos.x, roller_delta_pos.z).angle(),
				compacting_strength
			)
			$Compactor.look_at(roller_delta_pos)
			$Compactor.global_position = last_smoothed_position
			%RoadChunk.update_asphalt()
		else: shoveling_asphalt = false
	was_smoothing = smoothing
