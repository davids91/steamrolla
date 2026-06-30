@tool
class_name RoadChunk
extends Node3D

@export var map_resolution: Vector2i = Vector2(512,512)
@export var level_data: RoadChunkData
@export var height_unit: float = 0.5

var current_asphalt_level: Image
func load_asphalt() -> void:
	current_asphalt_level = level_data.asphalt_quantity_texture.get_image()
	update_materials()

func set_asphalt_to_empty() -> void:
	current_asphalt_level = Image.create_empty(map_resolution.x, map_resolution.y, false, Image.FORMAT_RF)
	current_asphalt_level.convert(Image.FORMAT_RF)
	level_data.asphalt_quantity_texture = ImageTexture.create_from_image(current_asphalt_level)
	update_materials()

func randomize_asphalt(noise: Noise, level: float = 0.2, distribution: float = 0.1) -> void:
	current_asphalt_level = Image.create_empty(map_resolution.x, map_resolution.y, false, Image.FORMAT_RF)
	for x in map_resolution.x: for y in map_resolution.y:
		var value: int = int(
			clamp(level + (noise.get_noise_2d(x, y) - 0.5) * 2.0 * distribution, 0., 1.)
			* 255.
		)
		current_asphalt_level.set_pixel(x,y, Color.from_rgba8(value, value, value, 255))
	current_asphalt_level.convert(Image.FORMAT_RF)
	level_data.asphalt_quantity_texture = ImageTexture.create_from_image(current_asphalt_level)
	update_materials()

#TODO: useless function
func load_terrain(set_height_unit: float = 0.) -> void:
	if 0. != set_height_unit: height_unit = set_height_unit
	update_level_physics()
	update_materials()

func get_size() -> Vector3: return Vector3($Ground.mesh.size.x, height_unit, $Ground.mesh.size.y)

func set_target() -> void:
	var target_image: Image = %AsphaltPhysicsViewport.get_texture().get_image()
	level_data.target_height_texture = ImageTexture.create_from_image(target_image)
	$Ground.get_active_material(0).set_shader_parameter("level_tool_reference", level_data.target_height_texture)

func get_deviation_from_target() -> float:
	var difference_image: Image = %AsphaltCheckerViewport.get_texture().get_image()
	difference_image.resize(1,1, Image.INTERPOLATE_LANCZOS)
	return difference_image.get_pixel(0,0).get_luminance()

func snap_to_reference(amount: float) -> void:
	if not %AsphaltPhysicsViewport or not %AsphaltPhysics or not %AsphaltUpdater: return
	%AsphaltUpdater.material.set_shader_parameter("input_reference", %AsphaltPhysicsViewport.get_texture())
	%AsphaltUpdater.material.set_shader_parameter("set_to_reference", amount)

func update_asphalt(overwrite_level_data: bool = false) -> void:
	if scan_in_progress(): return
	current_asphalt_level = %AsphaltUpdaterViewport.get_texture().get_image()
	if overwrite_level_data: 
		level_data.asphalt_quantity_texture = ImageTexture.create_from_image(current_asphalt_level)
	update_materials()

func set_crazify_amount(amount: float):
	$Ground.get_active_material(0).set_shader_parameter("crazify_amount", amount)

func set_crazify_scale(amount: float):
	$Ground.get_active_material(0).set_shader_parameter("crazify_scale", amount)

func set_crazify_speed(amount: float):
	$Ground.get_active_material(0).set_shader_parameter("crazify_speed", amount)

func set_update_brush_amount(amount: float) -> void:
	%AsphaltUpdater.material.set_shader_parameter("asphalt_delta", amount)

func set_update_brush_radius(amount: float) -> void:
	%AsphaltUpdater.material.set_shader_parameter("effect_radius", amount)

func set_update_brush_center(center: Vector2) -> void:
	%AsphaltUpdater.material.set_shader_parameter("roller_center", center)

func set_roller_brush(center: Vector2, angle: float, strength: float = 1.) -> void:
	%AsphaltUpdater.material.set_shader_parameter("roller_angle", angle)
	%AsphaltUpdater.material.set_shader_parameter("roller_center", center)
	if -1. < strength: %AsphaltUpdater.material.set_shader_parameter("effect_strength", strength)

func set_highlight(amount: float) -> void :
	$Ground.get_active_material(0).set_shader_parameter("hightlight_strength", amount)

func use_roller(should_use: bool) -> void:
	%AsphaltUpdater.material.set_shader_parameter("using_roller", should_use)

var scan_tween: Tween
func scan_in_progress() -> bool: return scan_tween != null
func initiate_scan(level_scan_duration_sec: float = 0.75, level_scan_range: float = 0.25, run_when_finished: Callable = func(): pass) -> void:
	if scan_tween: return # Scanning is in progress! Do not initiate again!
	var material: Material = $Ground.get_active_material(0)
	scan_tween = create_tween()
	material.set_shader_parameter("level_tool_range", 0.01)
	scan_tween.tween_callback(func(): material.set_shader_parameter("level_tool_scanning_strength", 1.))
	scan_tween.tween_method(
		func(w: float): material.set_shader_parameter("level_tool_height", height_unit * w),
		0., 1., level_scan_duration_sec
	).set_ease(Tween.EASE_IN)
	scan_tween.tween_method(
		func(w: float): material.set_shader_parameter("level_tool_height", height_unit * w),
		1., 0., level_scan_duration_sec
	).set_ease(Tween.EASE_OUT)
	scan_tween.tween_method(
		func(w: float): material.set_shader_parameter("level_tool_height", height_unit * w),
		0., 1., level_scan_duration_sec
	).set_ease(Tween.EASE_OUT_IN)
	scan_tween.tween_interval(level_scan_duration_sec / 2.)
	scan_tween.tween_callback(func():
		material.set_shader_parameter("level_tool_scanning_strength", 0.)
		material.set_shader_parameter("level_tool_range", level_scan_range)
	)
	scan_tween.tween_method(
		func(w: float): material.set_shader_parameter("level_tool_height", height_unit * w),
		1., -0.01, level_scan_duration_sec * 5.
	).set_ease(Tween.EASE_OUT_IN)
	scan_tween.tween_method(
		func(w: float): material.set_shader_parameter("level_tool_range", w),
		level_scan_range, 0.0, level_scan_duration_sec
	).set_ease(Tween.EASE_IN)
	scan_tween.tween_callback(func():
		scan_tween = null
		run_when_finished.call()
	)

const PHYSICS_SCALE_FOR_HEIGHT: float = 2. / (32. / 512.) ## Eplained below:
## Asphalt resolution(512x512) is double of the terrain resolution, so the resulting shape is double the size of the displayed map
## Additionally, the ground mesh is of size 32x32. and the physics mesh needs to be scaled down to it from its resolution(512x512) 
func update_level_physics() -> void:
	await RenderingServer.frame_post_draw
	var physics_material: Image = %AsphaltPhysicsViewport.get_texture().get_image()
	physics_material.decompress()
	physics_material.convert(Image.FORMAT_RF)
	$GroundPhysicsFake/Shape.shape.update_map_data_from_image(physics_material, 0., height_unit * PHYSICS_SCALE_FOR_HEIGHT)

func update_materials() -> void:
	level_data.asphalt_quantity_texture = ImageTexture.create_from_image(current_asphalt_level)
	%AsphaltUpdater.material.set_shader_parameter("terrain", level_data.terrain_heightmap)
	%AsphaltUpdater.material.set_shader_parameter("asphalt", level_data.asphalt_quantity_texture)
	#TODO: Maybe this should be used?
	#%AsphaltUpdater.material.set_shader_parameter("asphalt_filter", level_data.asphalt_filter_image)
	%AsphaltUpdater.material.set_shader_parameter("target_height", level_data.target_height_texture)

	%AsphaltChecker.material.set_shader_parameter("terrain", level_data.terrain_heightmap)
	%AsphaltChecker.material.set_shader_parameter("asphalt", level_data.asphalt_quantity_texture)
	%AsphaltChecker.material.set_shader_parameter("asphalt_filter", level_data.asphalt_filter_image)
	%AsphaltUpdater.material.set_shader_parameter("target_height", level_data.target_height_texture)

	%AsphaltPhysics.material.set_shader_parameter("terrain", level_data.terrain_heightmap)
	%AsphaltPhysics.material.set_shader_parameter("asphalt", level_data.asphalt_quantity_texture)
	%AsphaltPhysics.material.set_shader_parameter("asphalt_filter", level_data.asphalt_filter_image)

	var mat: Material = $Ground.get_active_material(0)
	mat.set_shader_parameter("level_tool_reference", level_data.target_height_texture)
	mat.set_shader_parameter("asphalt_quantity", level_data.asphalt_quantity_texture)
	mat.set_shader_parameter("asphalt_filter",  level_data.asphalt_filter_image)
	mat.set_shader_parameter("height_unit",  height_unit)
	mat.set_shader_parameter("terrain_heightmap", level_data.terrain_heightmap)
	mat.set_shader_parameter("terrain_normalmap", level_data.terrain_normalmap)
	mat.set_shader_parameter("road_colormap", level_data.terrain_albedo_image)
