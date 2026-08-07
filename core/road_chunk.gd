@tool
class_name RoadChunk
extends Node3D

var physics_needs_update: bool = false
var time_since_last_update: float = 0.0
var asphalt_attributes: Image
var asphalt_state: Texture
var asphalt_physics_state: Texture ## r: level height(terrain + asphalt), g: asphalt temperature, b: water waves

@export var roller: RollerController

@export_category("Level Data")
@export var level_data: RoadChunkData
@export var load_data: bool:
	set(v): _initialize(level_data)

@export_category("Physics")
@export_range(0.01, 1.0, 0.01) var physics_update_interval: float = 0.2
@export var height_unit: float = 0.5

enum DynamicSurfaces{ ASPHALT = 0, GRAVEL = 1, DIRT = 2 }
var DynamicSurfaceShyninessInverse: Array[float] = [10., 15., 50.]

@export_category("Display")
@export var call_update_materials: bool:
	set(v): update_materials()
@export var surface: DynamicSurfaces = DynamicSurfaces.ASPHALT:
	set(v):
		surface = v
		if level_data: level_data.surface = v
		asphalt_shyniness = DynamicSurfaceShyninessInverse[v]
		match v:
			DynamicSurfaces.ASPHALT:
				asphalt_texture = load("res://textures/asphalt_tile_seamless.png")
				asphalt_normals = load("res://textures/asphalt_tile_seamless_normal.png")
			DynamicSurfaces.GRAVEL:
				asphalt_texture = load("res://textures/gravel-seamless.png")
				asphalt_normals = load("res://textures/gravel-seamless-normal.png")
			DynamicSurfaces.DIRT:
				asphalt_texture = load("res://textures/dirt-seamless.png")
				asphalt_normals = load("res://textures/dirt-seamless-normal.png")
			_:
				asphalt_texture = load("res://textures/asphalt_tile_seamless.png")
				asphalt_normals = load("res://textures/asphalt_tile_seamless_normal.png")

@export var map_resolution: Vector2i = Vector2(512,512)
@export var asphalt_shyniness: float = 0.
@export var asphalt_tile_size_ratio: float = 20.

@onready var asphalt_shiny: float = DynamicSurfaceShyninessInverse[surface]
var asphalt_texture: Texture = load("res://textures/asphalt_tile_seamless.png")
var asphalt_normals: Texture = load("res://textures/asphalt_tile_seamless_normal.png")

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
	var asphalt_pixel:float = asphalt_attributes.get_pixelv(normalized_pos).get_luminance()
	asphalt_pixel = asphalt_pixel if asphalt_pixel >= 0. else 0. # Checking for out of bounds
	return 0.5 < asphalt_pixel

func get_deviation_from_target() -> float:
	var difference_image: Image = %AsphaltCheckerViewport.get_texture().get_image()
	difference_image.resize(1,1, Image.INTERPOLATE_LANCZOS)
	return difference_image.get_pixel(0,0).get_luminance()

#region update brushes
func configure_to(tool: RoadWorkTool) -> void:
	%AsphaltUpdater.material.set_shader_parameter("tool_angle_offset", tool.tool_angle)
	%AsphaltUpdater.material.set_shader_parameter("tool_size", tool.normalized_size)
	%AsphaltUpdater.material.set_shader_parameter("used_tool", tool.tool_enum)
	current_tool = tool.tool_enum

var current_tool: ToolPanel.Tools = ToolPanel.Tools.PAVER
func configure_tool_enum(tool: ToolPanel.Tools) -> void:
	%AsphaltUpdater.material.set_shader_parameter("used_tool", tool)
	current_tool = tool

func set_crazify_amount(amount: float):
	$Ground.get_active_material(0).set_shader_parameter("crazify_amount", amount)

func set_crazify_scale(amount: float):
	$Ground.get_active_material(0).set_shader_parameter("crazify_scale", amount)

func set_crazify_speed(amount: float):
	$Ground.get_active_material(0).set_shader_parameter("crazify_speed", amount)

var current_update_amount: float = 0.
func set_update_brush_amount(amount: float) -> void:
	current_update_amount = amount
	%AsphaltUpdater.material.set_shader_parameter("asphalt_delta", amount)

func set_update_brush_radius(amount: float) -> void:
	%AsphaltUpdater.material.set_shader_parameter("effect_radius", amount)

## Updates the brush based on the provided global coordinates
func set_update_brush_center(global_center: Vector3) -> void:
	%AsphaltUpdater.material.set_shader_parameter("tool_center", get_tex_position_from(global_center))

func set_update_brush_strength(strength: float) -> void:
	%AsphaltUpdater.material.set_shader_parameter("effect_strength", strength)

func set_paver_brush_height_by(paver_global_y: float) -> void:
	%AsphaltUpdater.material.set_shader_parameter(
		"paver_max_height", (paver_global_y - global_position.y) / height_unit
	)

func set_roller_brush(center: Vector2, angle: float, strength: float = 1.) -> void:
	%AsphaltUpdater.material.set_shader_parameter("tool_angle", angle)
	%AsphaltUpdater.material.set_shader_parameter("tool_center", center)
	if -1. < strength:
		%AsphaltUpdater.material.set_shader_parameter("effect_strength", strength)

func set_tool_angle(angle: float) -> void:
	%AsphaltUpdater.material.set_shader_parameter("tool_angle", angle)

func set_highlight(amount: float) -> void :
	$Ground.get_active_material(0).set_shader_parameter("hightlight_strength", amount)

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
		physics_needs_update = true
		update_materials()
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
	asphalt_shyniness = DynamicSurfaceShyninessInverse[surface]

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

	%AsphaltPhysics.material.set_shader_parameter("asphalt_physics_state", asphalt_physics_state)
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
	mat.set_shader_parameter("asphalt_texture", asphalt_texture)
	mat.set_shader_parameter("asphalt_normals", asphalt_normals)
	mat.set_shader_parameter("asphalt_tile_size_ratio", asphalt_tile_size_ratio)
	mat.set_shader_parameter("asphalt_physics_state", asphalt_physics_state)
	mat.set_shader_parameter("asphalt_shiny", asphalt_shiny)

	var water_mat: Material = $Ground.get_active_material(0).next_pass
	water_mat.set_shader_parameter("height_unit",  height_unit)
	water_mat.set_shader_parameter("asphalt_attributes",  level_data.asphalt_attributes)
	water_mat.set_shader_parameter("road_colormap", level_data.terrain_albedo_image)
	water_mat.set_shader_parameter("terrain_heightmap", level_data.terrain_heightmap)
	water_mat.set_shader_parameter("terrain_normalmap", level_data.terrain_normalmap)
	water_mat.set_shader_parameter("asphalt_physics_state", asphalt_physics_state)
	water_mat.set_shader_parameter("water_detail", level_data.water_detail_count)
	water_mat.set_shader_parameter("water_scale", level_data.water_scale)
	water_mat.set_shader_parameter("water_speed", level_data.water_speed)
	water_mat.set_shader_parameter("water_shiny", level_data.water_shinyness)
	water_mat.set_shader_parameter("water_directionality_angle", level_data.water_angle)
	water_mat.set_shader_parameter("water_direction_dominance", level_data.water_angle_dominance)
	water_mat.set_shader_parameter("water_detail_strength", level_data.water_detail_strength)
	water_mat.set_shader_parameter("water_height", level_data.water_height)
	water_mat.set_shader_parameter("water_color", level_data.water_color)
	water_mat.set_shader_parameter("water_transparency", level_data.water_transparency)

static func asphalt_state_tex_path(base_dir: String)-> String:
	return base_dir + "/asphalt_state.png"

static func user_asphalt_state_tex_path(base_dir: String)-> String:
	return base_dir.replace("res://", "user:##").replace("/", "_").replace("##", "//") + "_asphalt_state.png"

func _initialize(data: RoadChunkData, data_path: String = "") -> void:
	# Check if there's an asphalt state in user storage or a fallback in case data is not available
	var user_asphalt_state_path: String = user_asphalt_state_tex_path(data_path.get_base_dir())
	var fallback_asphalt_state_path: String = asphalt_state_tex_path(data_path.get_base_dir())
	var save_resource: bool = false
	if data_path.length() > 0 and FileAccess.file_exists(user_asphalt_state_path):
		level_data.start_asphalt_state = load(user_asphalt_state_path)
	elif not data.start_asphalt_state and FileAccess.file_exists(fallback_asphalt_state_path):
		level_data.start_asphalt_state = load(fallback_asphalt_state_path)
		save_resource = true

	if( # Save the resource if it doesn't exist, or updated
		(data_path.length() > 0 and not FileAccess.file_exists(data_path))
		or save_resource
	): ResourceSaver.save(level_data, data_path)

	if not level_data.start_asphalt_state:
		set_asphalt_to_empty()
		level_data.start_asphalt_state = asphalt_state
		ResourceSaver.save(level_data, data_path)

	# Set node state based on level data
	asphalt_state = level_data.start_asphalt_state
	asphalt_physics_state = level_data.start_asphalt_state
	asphalt_attributes = level_data.asphalt_attributes.get_image()
	asphalt_attributes.decompress()

	# Handle asphalt state starting values
	surface = level_data.surface
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

	var mesh_size = $Ground.mesh.size
	var tool_to_restore: ToolPanel.Tools = current_tool
	var amount_to_restore: float = current_update_amount

	set_update_brush_center(explosion_pos)
	set_update_brush_radius(explode_radius / mesh_size.x)
	set_update_brush_amount(amount_of_asphalt_to_add)
	configure_tool_enum(ToolPanel.Tools.SHOVEL) #TechDebt: Bomb should be configured instead

	update_asphalt()
	(func():
		await get_tree().process_frame
		set_update_brush_amount(amount_to_restore)
		configure_tool_enum(tool_to_restore)
	).call_deferred()
#endregion Bomb Explode

func _on_roller_has_moved(roller_position: Vector3, roller_angle: float, roller_strength: float, roller_strength_from_movement: float) -> void:
	var flat_chunk_size: Vector2 = Vector2(%RoadChunk.get_size().x, %RoadChunk.get_size().z)
	var texture_coordinates: Vector2 = (
		Vector2(roller_position.x, roller_position.z)
		 - Vector2(global_position.x, global_position.z)
		+ flat_chunk_size * 0.5
	) / flat_chunk_size
	
	set_roller_brush(texture_coordinates, roller_angle, roller_strength * roller_strength_from_movement)
	update_asphalt()

func _ready() -> void:
	if not roller:
		push_warning("%s is not assigning roller. Please check." % name)
	if roller and not roller.roller_has_moved.is_connected(_on_roller_has_moved):
		roller.roller_has_moved.connect(_on_roller_has_moved)
	
	asphalt_state = level_data.start_asphalt_state
	asphalt_physics_state = level_data.start_asphalt_state
	asphalt_attributes = level_data.asphalt_attributes.get_image()
	asphalt_attributes.decompress()
	update_materials()

func _process(delta: float) -> void:
	time_since_last_update += delta
	if not physics_needs_update: return
	if time_since_last_update >= physics_update_interval:
		update_physics()
		physics_needs_update = false
		time_since_last_update = 0.0
