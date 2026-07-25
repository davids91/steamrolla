@tool
class_name RoadChunk
extends Node3D

var physics_needs_update: bool = false
var time_since_last_update: float = 0.0
var asphalt_attributes: Image
var asphalt_state: Texture
var asphalt_physics_state: Texture ## r: level height(terrain + asphalt), g: asphalt temperature, b: water waves

@export_category("Physics") 
@export_range(0.01, 1.0, 0.01) var physics_update_interval: float = 0.2

@export_category("General")
@export var map_resolution: Vector2i = Vector2(512,512)
@export var level_data: RoadChunkData
@export var height_unit: float = 0.5

@export var load_data: bool: 
	set(v): _initialize(level_data)

#region Asphalt setters
func set_asphalt_to_empty() -> void:
	var asphalt_state_image : Image = Image.create_empty(map_resolution.x, map_resolution.y, false, Image.FORMAT_RF)
	asphalt_state = ImageTexture.create_from_image(asphalt_state_image)
	update_materials()

func randomize_asphalt(noise: Noise, level: float = 0.2, distribution: float = 0.1) -> void:
	var asphalt_state_image: Image = Image.create_empty(map_resolution.x, map_resolution.y, false, Image.FORMAT_RF)
	for x in map_resolution.x: for y in map_resolution.y:
		var value: int = int(
			clamp(level + (noise.get_noise_2d(x, y) - 0.5) * 2.0 * distribution, 0., 1.)
			* 255.
		)
		asphalt_state_image.set_pixel(x,y, Color.from_rgba8(value, value, value, 255))
	asphalt_state = ImageTexture.create_from_image(asphalt_state_image)
	update_materials()

func set_target() -> void:
	level_data.target_asphalt_state = asphalt_state
	$Ground.get_active_material(0).set_shader_parameter("level_tool_reference", level_data.target_asphalt_state)

func snap_to_reference(amount: float) -> void:
	if not %AsphaltPhysicsViewport or not %AsphaltTransformer: return
	%AsphaltTransformer.material.set_shader_parameter("target_asphalt_state", level_data.target_asphalt_state)
	%AsphaltTransformer.material.set_shader_parameter("set_to_reference", amount)

#endregion Asphalt setters

func get_size() -> Vector3: return Vector3($Ground.mesh.size.x, height_unit, $Ground.mesh.size.y)

func get_tex_position_from(pos: Vector3) -> Vector2:
	var flat_chunk_size: Vector2 = Vector2($Ground.mesh.size.x, $Ground.mesh.size.y)
	return (
		Vector2(pos.x, pos.z) - Vector2(global_position.x, global_position.z) + flat_chunk_size * 0.5
	) / flat_chunk_size

func is_on_asphalt(global_pos: Vector3) -> bool:
	var normalized_pos: Vector2 = get_tex_position_from(global_pos)
	%AsphaltFilterPreview/PositionMarker.position = normalized_pos * %AsphaltFilterPreview.size
	if normalized_pos.x >= 1. or normalized_pos.y >= 1.: return false
	normalized_pos.x *= asphalt_attributes.get_width()
	normalized_pos.y *= asphalt_attributes.get_height()
	return 0.5 < asphalt_attributes.get_pixelv(normalized_pos).get_luminance()

func get_deviation_from_target() -> float:
	var difference_image: Image = %AsphaltCheckerViewport.get_texture().get_image()
	difference_image.resize(1,1, Image.INTERPOLATE_LANCZOS)
	return difference_image.get_pixel(0,0).get_luminance()

#region update brushes
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

func set_update_brush_strength(strength: float) -> void:
	%AsphaltUpdater.material.set_shader_parameter("effect_strength", strength)

func set_roller_brush(center: Vector2, angle: float, strength: float = 1.) -> void:
	%AsphaltUpdater.material.set_shader_parameter("roller_angle", angle)
	%AsphaltUpdater.material.set_shader_parameter("roller_center", center)
	if -1. < strength:
		%AsphaltUpdater.material.set_shader_parameter("effect_strength", strength)

func set_roller_size(size: Vector2) -> void:
	%AsphaltUpdater.material.set_shader_parameter("roller_size", size)

func set_highlight(amount: float) -> void :
	$Ground.get_active_material(0).set_shader_parameter("hightlight_strength", amount)

func use_roller(should_use: bool) -> void:
	%AsphaltUpdater.material.set_shader_parameter("using_roller", should_use)

#endregion update brushes

var scan_tween: Tween
func scan_in_progress() -> bool: return scan_tween != null
func initiate_scan(level_scan_range: float = 0.25, run_when_finished: Callable = func(): pass) -> void:
	if scan_tween: return # Scanning is in progress! Do not initiate again!
	var material: Material = $Ground.get_active_material(0)
	scan_tween = create_tween()
	material.set_shader_parameter("level_tool_range", 0.01)
	scan_tween.tween_callback(func():
		material.set_shader_parameter("level_tool_scanning_strength", 1.)
		$ScanSoundShort.play()
	)
	scan_tween.tween_method(
		func(w: float): material.set_shader_parameter("level_tool_height", height_unit * w),
		0., 1., $ScanSoundShort.stream.get_length()
	).set_ease(Tween.EASE_IN)
	scan_tween.tween_callback(func(): $ScanSoundShort.play())
	scan_tween.tween_method(
		func(w: float): material.set_shader_parameter("level_tool_height", height_unit * w),
		1., 0., $ScanSoundShort.stream.get_length()
	).set_ease(Tween.EASE_OUT)
	scan_tween.tween_callback(func(): $ScanSoundShort.play())
	scan_tween.tween_method(
		func(w: float): material.set_shader_parameter("level_tool_height", height_unit * w),
		0., 1., $ScanSoundShort.stream.get_length()
	).set_ease(Tween.EASE_OUT_IN)
	scan_tween.tween_interval($ScanSoundShort.stream.get_length() / 2.)
	scan_tween.tween_callback(func():
		material.set_shader_parameter("level_tool_scanning_strength", 0.)
		material.set_shader_parameter("level_tool_range", level_scan_range)
		$ScanSoundLong.play()
	)
	scan_tween.tween_method(
		func(w: float): material.set_shader_parameter("level_tool_height", height_unit * w),
		1., -0.01, $ScanSoundLong.stream.get_length()
	).set_ease(Tween.EASE_OUT_IN)
	scan_tween.tween_method(
		func(w: float): material.set_shader_parameter("level_tool_range", w),
		level_scan_range, 0.0, $ScanSoundShort.stream.get_length()
	).set_ease(Tween.EASE_IN)
	scan_tween.tween_callback(func():
		scan_tween = null
		run_when_finished.call()
	)

#region Update functions
func update_asphalt() -> void:
	if scan_in_progress(): return
	%AsphaltTransformer.material.set_shader_parameter("asphalt_delta", %AsphaltUpdaterViewport.get_texture())
	%AsphaltPhysics.material.set_shader_parameter("asphalt_delta", %AsphaltUpdaterViewport.get_texture())
	asphalt_state = ImageTexture.create_from_image(%AsphaltTransformerViewport.get_texture().get_image())
	(func():
		await RenderingServer.frame_post_draw
		asphalt_state = ImageTexture.create_from_image(%AsphaltTransformerViewport.get_texture().get_image())
		asphalt_physics_state = ImageTexture.create_from_image(%AsphaltPhysicsViewport.get_texture().get_image())
		#TechDebt: Setting asphalt_physics_state only works in this exact function
		%AsphaltPhysics.material.set_shader_parameter("asphalt_state", asphalt_state)
		%AsphaltPhysics.material.set_shader_parameter("asphalt_physics_state", asphalt_physics_state)
		update_materials()
		$Ground.get_active_material(0).set_shader_parameter("asphalt_physics_state", asphalt_physics_state)
		$Ground.get_active_material(0).next_pass.set_shader_parameter("asphalt_physics_state", asphalt_physics_state)
		physics_needs_update = true
	).call_deferred()


const PHYSICS_SCALE_FOR_HEIGHT: float = 2. / (32. / 64.) ## Eplained below:
## Asphalt resolution(512x512) is double of the terrain resolution, so the resulting shape is double the size of the displayed map
## Additionally, the ground mesh is of size 32x32. and the physics mesh needs to be scaled down to it from its resolution(512x512) 
func update_physics() -> void:
	(func():
		await RenderingServer.frame_post_draw
		var physics_material: Image = %MiniAsphaltPhysicsViewport.get_texture().get_image()
		physics_material.decompress()
		physics_material.convert(Image.FORMAT_RF)
		$GroundPhysicsFake/Shape.shape.update_map_data_from_image(physics_material, 0., height_unit * PHYSICS_SCALE_FOR_HEIGHT)
	).call_deferred()

func update_materials() -> void:
	%AsphaltChecker.material.set_shader_parameter("terrain", level_data.terrain_heightmap)
	%AsphaltChecker.material.set_shader_parameter("asphalt_state", asphalt_state)
	%AsphaltChecker.material.set_shader_parameter("asphalt_attributes", level_data.asphalt_attributes)
	%AsphaltChecker.material.set_shader_parameter("target_asphalt_state", level_data.target_asphalt_state)
	
	%AsphaltUpdater.material.set_shader_parameter("terrain", level_data.terrain_heightmap)
	%AsphaltUpdater.material.set_shader_parameter("asphalt_state", asphalt_state)
	%AsphaltUpdater.material.set_shader_parameter("asphalt_attributes", level_data.asphalt_attributes)
	%AsphaltUpdater.material.set_shader_parameter("target_asphalt_state", level_data.target_asphalt_state)

	%AsphaltTransformer.material.set_shader_parameter("asphalt_state", asphalt_state)
	%AsphaltTransformer.material.set_shader_parameter("target_asphalt_state", level_data.target_asphalt_state)

	%AsphaltPhysics.material.set_shader_parameter("terrain", level_data.terrain_heightmap)
	%AsphaltPhysics.material.set_shader_parameter("asphalt_state", asphalt_state)
	%AsphaltPhysics.material.set_shader_parameter("asphalt_attributes", level_data.asphalt_attributes)

	var mat: Material = $Ground.get_active_material(0)
	mat.set_shader_parameter("level_tool_reference", level_data.target_asphalt_state)
	mat.set_shader_parameter("asphalt_state", asphalt_state)
	mat.set_shader_parameter("asphalt_attributes",  level_data.asphalt_attributes)
	mat.set_shader_parameter("height_unit",  height_unit)
	mat.set_shader_parameter("terrain_heightmap", level_data.terrain_heightmap)
	mat.set_shader_parameter("terrain_normalmap", level_data.terrain_normalmap)
	mat.set_shader_parameter("road_colormap", level_data.terrain_albedo_image)

	var water_mat: Material = $Ground.get_active_material(0).next_pass
	water_mat.set_shader_parameter("height_unit",  height_unit)
	water_mat.set_shader_parameter("asphalt_attributes",  level_data.asphalt_attributes)
	water_mat.set_shader_parameter("road_colormap", level_data.terrain_albedo_image)
	water_mat.set_shader_parameter("terrain_heightmap", level_data.terrain_heightmap)
	water_mat.set_shader_parameter("terrain_normalmap", level_data.terrain_normalmap)

static func asphalt_state_tex_path(base_dir: String)-> String:
	return base_dir + "/asphalt_state.png"

static func user_asphalt_state_tex_path(base_dir: String)-> String:
	return base_dir.replace("res://", "user:##").replace("/", "_").replace("##", "//") + "_asphalt_state.png"

func _initialize(data: RoadChunkData, data_path: String = "") -> void:
	# Check if there's an asphalt state in user storage or a fallback in case data is not available
	var user_asphalt_state_path: String = user_asphalt_state_tex_path(data_path.get_base_dir())
	var fallback_asphalt_state_path: String = asphalt_state_tex_path(data_path.get_base_dir())
	if data_path.length() > 0 and FileAccess.file_exists(user_asphalt_state_path):
		level_data.start_asphalt_state = load(user_asphalt_state_path)
	elif not data.start_asphalt_state and FileAccess.file_exists(fallback_asphalt_state_path):
		level_data.start_asphalt_state = load(fallback_asphalt_state_path)
		ResourceSaver.save(level_data, data_path)

	# Set node state based on level data
	asphalt_state = level_data.start_asphalt_state
	asphalt_physics_state = level_data.start_asphalt_state
	asphalt_attributes = level_data.asphalt_attributes.get_image()
	asphalt_attributes.decompress()

	# Handle asphalt state starting values
	var no_asphalt_delta_image: Image = Image.create(512,512, false, Image.FORMAT_RGBF)
	no_asphalt_delta_image.fill(Color.from_rgba8(128,128,128,255))
	%AsphaltPhysics.material.set_shader_parameter("asphalt_delta", ImageTexture.create_from_image(no_asphalt_delta_image))
	%AsphaltPhysics.material.set_shader_parameter("asphalt_state", asphalt_state)
	%AsphaltPhysics.material.set_shader_parameter("asphalt_physics_state", asphalt_physics_state)

	# Initial update for materials and physics
	update_materials()
	update_physics()

func initialize(data_path: String) -> void: 
	level_data = ResourceLoader.load(data_path)
	_initialize(level_data, data_path)

func save_user_data(data_path: String) -> void:
	var base_dir: String = data_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_absolute(base_dir)
	asphalt_state.get_image().save_png(user_asphalt_state_tex_path(base_dir))

func reset_user_data(data_path: String) -> void:
	var user_data_path: String = user_asphalt_state_tex_path(data_path.get_base_dir())
	if  FileAccess.file_exists(user_data_path):
		DirAccess.remove_absolute(user_data_path)

#endregion Update functions
#region Bomb Explode
func _on_asphalt_bomb_explode(explosion_pos: Vector3, explode_radius: float, amount_of_asphalt_to_add: float):
	var local_pos = to_local(explosion_pos)
	
	var mesh_size = $Ground.mesh.size
	
	var uv_x = (local_pos.x / mesh_size.x) + 0.5
	var uv_z = (local_pos.z / mesh_size.y) + 0.5
	var center_uv = Vector2(uv_x, uv_z)
	
	if uv_x < 0.0 or uv_x > 1.0 or uv_z < 0.0 or uv_z > 1.0:
		return
		
	use_roller(false)

	set_update_brush_center(center_uv)
	# effect_radius is in texture UV space (0..1), explode_radius is in world units
	set_update_brush_radius(explode_radius / mesh_size.x)
	set_update_brush_amount(amount_of_asphalt_to_add)

	update_asphalt()
	await get_tree().process_frame
	set_update_brush_amount(0.0)
	use_roller(true)
#endregion Bomb Explode

func _ready() -> void:
	update_materials()

	# Set node state based on level data
	asphalt_state = level_data.start_asphalt_state
	asphalt_physics_state = level_data.start_asphalt_state
	asphalt_attributes = level_data.asphalt_attributes.get_image()
	asphalt_attributes.decompress()

func _process(delta: float) -> void:
	time_since_last_update += delta
	if not physics_needs_update: return
	if time_since_last_update >= physics_update_interval:
		update_physics()
		physics_needs_update = false
		time_since_last_update = 0.0
