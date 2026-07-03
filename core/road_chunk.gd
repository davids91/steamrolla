@tool
class_name RoadChunk
extends Node3D

@export var map_resolution: Vector2i = Vector2(512,512)
@export var level_data: RoadChunkData
@export var height_unit: float = 0.5

@export var load_data: bool: 
	set(v): _initialize(level_data)

#region Asphalt setters
func set_asphalt_to_empty() -> void:
	var current_asphalt_level: Image = Image.create_empty(map_resolution.x, map_resolution.y, false, Image.FORMAT_RF)
	current_asphalt_level.convert(Image.FORMAT_RF)
	level_data.asphalt_quantity_texture = ImageTexture.create_from_image(current_asphalt_level)
	update_materials()

func randomize_asphalt(noise: Noise, level: float = 0.2, distribution: float = 0.1) -> void:
	var current_asphalt_level: Image = Image.create_empty(map_resolution.x, map_resolution.y, false, Image.FORMAT_RF)
	for x in map_resolution.x: for y in map_resolution.y:
		var value: int = int(
			clamp(level + (noise.get_noise_2d(x, y) - 0.5) * 2.0 * distribution, 0., 1.)
			* 255.
		)
		current_asphalt_level.set_pixel(x,y, Color.from_rgba8(value, value, value, 255))
	current_asphalt_level.convert(Image.FORMAT_RF)
	level_data.asphalt_quantity_texture = ImageTexture.create_from_image(current_asphalt_level)
	update_materials()
#endregion Asphalt setters

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
	if not %AsphaltPhysicsViewport or not %AsphaltTransformer: return
	%AsphaltTransformer.material.set_shader_parameter("target_height", level_data.target_height_texture)
	%AsphaltTransformer.material.set_shader_parameter("set_to_reference", amount)

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

#region Update functions
#TODO: Effect strength parameter in updater to be set to zero when shoveling!
#TODO: use ViewportTexture instead of manually setting it with ...Viewport.get_texture()
func update_asphalt() -> void:
	if scan_in_progress(): return
	ImageTexture.create_from_image(%AsphaltTransformerViewport.get_texture().get_image())
	%AsphaltTransformer.material.set_shader_parameter("asphalt_delta", %AsphaltUpdaterViewport.get_texture())
	%AsphaltPhysics.material.set_shader_parameter("asphalt_delta", %AsphaltUpdaterViewport.get_texture())
	(func():
		await RenderingServer.frame_post_draw
		level_data.asphalt_quantity_texture = ImageTexture.create_from_image(%AsphaltTransformerViewport.get_texture().get_image())
		%AsphaltPhysics.material.set_shader_parameter(
			"asphalt_meta", 
			ImageTexture.create_from_image(%AsphaltPhysicsViewport.get_texture().get_image())
		)
		update_materials()
		update_level_physics()
	).call_deferred()


const PHYSICS_SCALE_FOR_HEIGHT: float = 2. / (32. / 512.) ## Eplained below:
## Asphalt resolution(512x512) is double of the terrain resolution, so the resulting shape is double the size of the displayed map
## Additionally, the ground mesh is of size 32x32. and the physics mesh needs to be scaled down to it from its resolution(512x512) 
func update_level_physics() -> void:
	(func():
		await RenderingServer.frame_post_draw
		var physics_material: Image = %AsphaltPhysicsViewport.get_texture().get_image()
		physics_material.decompress()
		physics_material.convert(Image.FORMAT_RF)
		$GroundPhysicsFake/Shape.shape.update_map_data_from_image(physics_material, 0., height_unit * PHYSICS_SCALE_FOR_HEIGHT)
	).call_deferred()

#TODO: when morph to reference is not 0, and updater delta is also not zero there must be some kind of fight for the result?!
func update_materials() -> void:
	%AsphaltChecker.material.set_shader_parameter("terrain", level_data.terrain_heightmap)
	%AsphaltChecker.material.set_shader_parameter("asphalt", level_data.asphalt_quantity_texture)
	%AsphaltChecker.material.set_shader_parameter("asphalt_filter", level_data.asphalt_filter_image)
	%AsphaltChecker.material.set_shader_parameter("target_height", level_data.target_height_texture)
	
	%AsphaltUpdater.material.set_shader_parameter("terrain", level_data.terrain_heightmap)
	%AsphaltUpdater.material.set_shader_parameter("asphalt", level_data.asphalt_quantity_texture)
	%AsphaltUpdater.material.set_shader_parameter("asphalt_filter", level_data.asphalt_filter_image)
	%AsphaltUpdater.material.set_shader_parameter("target_height", level_data.target_height_texture)

	%AsphaltTransformer.material.set_shader_parameter("terrain", level_data.terrain_heightmap)
	%AsphaltTransformer.material.set_shader_parameter("asphalt", level_data.asphalt_quantity_texture)
	%AsphaltTransformer.material.set_shader_parameter("target_height", level_data.target_height_texture)

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

static func _asphalt_quantity_tex_path(base_dir: String)-> String:
	return base_dir + "/asphalt_quantity.png"

static func _asphalt_physics_tex_path(base_dir: String)-> String:
	return base_dir + "/asphalt_physics.png"

func _initialize(data: RoadChunkData, data_path: String = "") -> void:
	# Fallback for asphalt quantity image
	var asphalt_image_path: String = _asphalt_quantity_tex_path(data_path.get_base_dir())
	if not data.asphalt_quantity_texture and FileAccess.file_exists(asphalt_image_path):
		level_data.asphalt_quantity_texture = load(asphalt_image_path)
	
	# Handle asphalt physics starting values
	var no_asphalt_delta_image: Image = Image.create(512,512, false, Image.FORMAT_RGBF)
	no_asphalt_delta_image.fill(Color.from_rgba8(128,128,128,255))
	%AsphaltPhysics.material.set_shader_parameter(
		"asphalt_delta", ImageTexture.create_from_image(no_asphalt_delta_image)
	)
	if not level_data.asphalt_physics_texture:
		var physics_image_path: String = _asphalt_physics_tex_path(data_path.get_base_dir())
		if FileAccess.file_exists(physics_image_path): level_data.asphalt_physics_texture = load(physics_image_path)
		else: level_data.asphalt_physics_texture = ImageTexture.create_from_image(Image.create_empty(512,512, false, Image.FORMAT_RGBF))
	%AsphaltPhysics.material.set_shader_parameter("asphalt_meta", level_data.asphalt_physics_texture)

	# Initial update for materials and physics
	update_materials()
	update_level_physics()	

func initialize(data_path: String) -> void: 
	level_data = ResourceLoader.load(data_path)
	_initialize(level_data, data_path)

#endregion Update functions

func _ready() -> void:
	update_materials()
