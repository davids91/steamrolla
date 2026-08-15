@tool
extends Node3D

#region editor helper functionality
@export_file_path("*.res") var level_data: String:
	set(v):
		level_data = v
		if get_node_or_null("%RoadChunk"):
			%RoadChunk.initialize(level_data)

@export_tool_button("Load Level Data", "Load") var load_level_data: Callable = func():
		%RoadChunk.initialize(level_data)

@export_tool_button("Save Level Data", "Save") var save_level_data: Callable = func():
	if not get_node_or_null("%RoadChunk"): return
	var updated_start_state: bool = false
	var start_state_img_path: String = RoadChunk.asphalt_state_tex_path(level_data.get_base_dir())
	if %RoadChunk.asphalt_state:
		updated_start_state = true
		%RoadChunk.asphalt_state.get_image().save_png(start_state_img_path)
	var updated_target_state: bool = false
	var target_state_img_path: String = RoadChunk.asphalt_target_state_tex_path(level_data.get_base_dir())
	if %RoadChunk.level_data.target_asphalt_state:
		updated_target_state = true
		%RoadChunk.level_data.target_asphalt_state.get_image().save_png(target_state_img_path)
	if not updated_start_state and not updated_target_state: return
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan() #TechDebt: This makes itch export crash
	if updated_start_state: %RoadChunk.level_data.start_asphalt_state = load(start_state_img_path)
	if updated_target_state: %RoadChunk.level_data.target_asphalt_state = load(target_state_img_path)
	get_tree().create_timer(1.).timeout.connect(func():ResourceSaver.save(%RoadChunk.level_data, level_data))

@export var noise: FastNoiseLite = FastNoiseLite.new()
@export var starting_asphalt_level_normalized: float = 0.2
@export var starting_asphalt_distribution_normalized: float = 0.05
@export var height_unit: float = 0.5:
	set(v):
		height_unit = v
		if get_node_or_null("%RoadChunk"):
			%RoadChunk.height_unit = height_unit
			%RoadChunk.update_materials()

@export_tool_button("Update Materials", "Reload") var call_update_materials: Callable = func():
	%RoadChunk.update_materials()

@export_tool_button("Update Physics", "Reload") var call_update_physics: Callable = func():
	%RoadChunk.update_physics()

@export_tool_button("Update Asphalt", "CurveTexture") var update_asphalt: Callable = func():
	%RoadChunk.update_asphalt()
	%RoadChunk.update_physics()

@export_tool_button("Erase Asphalt", "GuiVsplitter") var empty_asphalt_image: Callable = func():
	%RoadChunk.set_asphalt_to_empty()
	%RoadChunk.update_physics()

@export_tool_button("Randomize Asphalt", "CurveXYZTexture") var regenerate_asphalt_image: Callable = func():
	noise.seed = randi()
	%RoadChunk.randomize_asphalt(noise, starting_asphalt_level_normalized, starting_asphalt_distribution_normalized)
	%RoadChunk.level_data.start_asphalt_state = %RoadChunk.asphalt_state
	%RoadChunk.update_physics()

@export_range(0., 1.) var reference_asphalt_height: float = starting_asphalt_level_normalized
@export_tool_button("Set Asphalt To Ref Height", "CurveConstant") var set_asphalt_to_reference_height: Callable = func():
	%RoadChunk.randomize_asphalt(noise, reference_asphalt_height, 0.)

@export_tool_button("Take Asphalt as Target", "CurveCenter") var take_current_asphalt_state_as_target: Callable = func():
	%RoadChunk.set_target()

@export var max_snap_value: float = 0.6
@export var snap_time_sec: float = 0.6
@export var snap_easing: float = 1.0
@export_tool_button("Snap to Reference", "CollapseTree") var start_snapping_to_ref: Callable = func():
	_snap_asphalt_to_reference()

@export_range(0., 10.) var reference_snap_strength: float = false:
	set(v):
		reference_snap_strength = v
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
		if get_node_or_null("%RoadChunk"):
			%RoadChunk.set_crazify_scale(crazify_scale)

@export var crazify_speed: float = 0:
	set(v):
		crazify_speed = v
		if get_node_or_null("%RoadChunk"):
			%RoadChunk.set_crazify_speed(crazify_speed)

@export var level_scan_range: float = 0.25
@export_tool_button("Scan Level", "ColorTrackVu") var scan_for_height: Callable = func():
	if not %RoadChunk: return
	%RoadChunk.initiate_scan(level_scan_range)

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
	snap.tween_method(func(w: float): reference_snap_strength = ease(w, snap_easing), 0., max_snap_value, snap_time_sec)
	snap.tween_callback(func(): reference_snap_strength = 0.)

@export var accepted_deviation: float = 0.001
var won_game: bool = false
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select") and not won_game and not %RoadChunk.scan_in_progress():
		%RoadChunk.initiate_scan(level_scan_range, func():
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

func _ready() -> void:
	%RoadChunk.initialize(level_data)
	%ToolPanel.call_deferred("select", ToolPanel.Tools.PAVER)
	for tool in $ToolController.get_children(): if tool is RoadworkTool:
		tool.set_color(Color.TRANSPARENT)
