@tool
class_name RoadChunk
extends Node3D

var physics_needs_update: bool = false
var time_since_last_update: float = 0.0
var asphalt_attributes: Image
var asphalt_state: Texture
var asphalt_physics_state: Texture ## r: level height(terrain + asphalt), g: asphalt temperature, b: water waves

@export_category("Level Data")
@export var level_data: RoadChunkData
@export_tool_button("Load data", "Reload") var load_data: Callable = func(): _initialize(level_data)

@export_category("Physics")
@export_range(0.01, 1.0, 0.01) var physics_update_interval: float = 0.2
@export var height_unit: float = 0.5

enum DynamicSurfaces{ ASPHALT = 0, GRAVEL = 1, DIRT = 2 }
var DynamicSurfaceShyniness: Array[float] = [0.05, 0., 0.]

@export_category("Display")
@export_tool_button("Update Materials", "Reload") var call_update_materials: Callable = update_materials
@export_tool_button("Update Physics", "Reload") var call_update_physics: Callable = update_physics
@export var surface: DynamicSurfaces = DynamicSurfaces.ASPHALT:
	set(v):
		surface = v
		if level_data: level_data.surface = v
		asphalt_shyniness = DynamicSurfaceShyniness[v]
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

@onready var asphalt_shiny: float = DynamicSurfaceShyniness[surface]
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
	if get_node_or_null("%AsphaltFilterPreview/PositionMarker"):
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
var update_config_stack: Array[Dictionary]
func push_config() -> void:
	update_config_stack.push_back({
		"tool_radius": tool_radius,
		"tool_strength": tool_strength,
		"asphalt_delta": asphalt_delta,
		"tool_center": tool_center,
		"tool_size": tool_size,
		"tool_angle": tool_angle,
		"tool_angle_offset": tool_angle_offset,
		"used_tool": used_tool
	})

func pop_config() -> void:
	if update_config_stack.is_empty():
		push_warning("Popped empty config stack!")
		return
	tool_radius = update_config_stack[-1]["tool_radius"]
	tool_strength = update_config_stack[-1]["tool_strength"]
	asphalt_delta = update_config_stack[-1]["asphalt_delta"]
	tool_center = update_config_stack[-1]["tool_center"]
	tool_size = update_config_stack[-1]["tool_size"]
	tool_angle = update_config_stack[-1]["tool_angle"]
	tool_angle_offset = update_config_stack[-1]["tool_angle_offset"]
	used_tool = update_config_stack[-1]["used_tool"]
	update_config_stack.pop_back()

func configure_to(tool: RoadworkTool) -> void:
	tool_angle_offset = tool.tool_angle
	used_tool = tool.tool_enum
	tool_size = tool.normalized_size
	tool_strength = tool.tool_strength
	tool_radius = tool.tool_radius

func set_crazify_amount(amount: float):
	$Ground.get_active_material(0).set_shader_parameter("crazify_amount", amount)

func set_crazify_scale(amount: float):
	$Ground.get_active_material(0).set_shader_parameter("crazify_scale", amount)

func set_crazify_speed(amount: float):
	$Ground.get_active_material(0).set_shader_parameter("crazify_speed", amount)

## The tool identifier used to udpate the level
var used_tool: ToolPanel.Tools = ToolPanel.Tools.UNKNOWN:
	set(t):
		used_tool = t
		%AsphaltUpdater.material.set_shader_parameter("used_tool", t)

## current addition/removal of asphalt under tool active area
var asphalt_delta: float = 0.:
	set(amount):
		asphalt_delta = amount
		%AsphaltUpdater.material.set_shader_parameter("asphalt_delta", amount)

## normalized value for tools without a defined tool shape ( e.g. a rectangle )
var tool_radius: float = 0.:
	set(amount):
		tool_radius = amount
		%AsphaltUpdater.material.set_shader_parameter("tool_radius", amount)

## Updates the brush based on the provided global coordinates
var tool_center: Vector2 = Vector2.ONE * 0.5:
	set(pos):
		tool_center = pos
		%AsphaltUpdater.material.set_shader_parameter("tool_center", pos)

func set_update_brush_center(global_center: Vector3) -> void:
	tool_center = get_tex_position_from(global_center)

## Normalized size of the tool updating the level: width and height
var tool_size: Vector2 = Vector2.ONE * 0.5:
	set(size):
		tool_size = size
		%AsphaltUpdater.material.set_shader_parameter("tool_size", size)

## How much the equipped tool affects the level
var tool_strength: float = 0.:
	set(amount):
		tool_strength = amount
		%AsphaltUpdater.material.set_shader_parameter("tool_strength", amount)

## The volatile angle of the tool updating the level
var tool_angle: float = 0.:
	set(amount):
		tool_angle = amount
		%AsphaltUpdater.material.set_shader_parameter("tool_angle", amount)

## The stable(r) relative angle offset of the tool active part updating the level
## final angle is given by both @tool_angle and @tool_angle_offset
var tool_angle_offset: float = 0.:
	set(amount):
		tool_angle_offset = amount
		%AsphaltUpdater.material.set_shader_parameter("tool_angle_offset", amount)

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

func update_physics() -> void:
	(func():
		await RenderingServer.frame_post_draw
		var physics_material: Image = %MiniAsphaltPhysicsViewport.get_texture().get_image()
		physics_material.decompress()
		physics_material.convert(Image.FORMAT_RF)
		$GroundPhysicsFake/Shape.shape.update_map_data_from_image(physics_material, 0., height_unit * 2.)
	).call_deferred()

func update_materials() -> void:
	asphalt_shyniness = DynamicSurfaceShyniness[surface]
	height_unit = level_data.height_unit

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

@onready var used_base_dir: String = get_parent().scene_file_path.get_base_dir()
func _initialize(data: RoadChunkData, data_path: String = "") -> void:
	# Check if there's an asphalt state in user storage or a fallback in case data is not available
	var save_resource: bool = false
	if data_path.length() > 0: # The resource is supposed to exist in res:// somewhere!
		used_base_dir = data_path.get_base_dir()
		var user_asphalt_state_path: String = LevelStructure.user_asphalt_state_tex_path(data_path.get_base_dir())
		var fallback_asphalt_state_path: String = LevelStructure.asphalt_state_tex_path(data_path.get_base_dir())
		var fallback_asphalt_target_path: String = LevelStructure.asphalt_target_state_tex_path(data_path.get_base_dir())

		# Load user or fallback asphalt state image: always overwrite resource data with user state image when available!
		if FileAccess.file_exists(user_asphalt_state_path):
			level_data.start_asphalt_state = ImageTexture.create_from_image(Image.load_from_file(user_asphalt_state_path))
		elif not data.start_asphalt_state and FileAccess.file_exists(fallback_asphalt_state_path):
			level_data.start_asphalt_state = load(fallback_asphalt_state_path)
			save_resource = true

		# Load fallback asphalt target image
		if not data.target_asphalt_state and FileAccess.file_exists(fallback_asphalt_target_path):
			level_data.target_asphalt_state = load(fallback_asphalt_target_path)
			save_resource = true

	# Save the resource if it doesn't exist, or updated
	if((data_path.length() > 0 and not FileAccess.file_exists(data_path)) or save_resource):
		ResourceSaver.save(level_data, data_path)

	# Generate an empty asphalt state if nothing is provided either from res:// or user://
	if not level_data.start_asphalt_state:
		set_asphalt_to_empty()
		level_data.start_asphalt_state = asphalt_state
		ResourceSaver.save(level_data, data_path)

	# Set node state based on level data
	asphalt_state = level_data.start_asphalt_state
	asphalt_physics_state = level_data.start_asphalt_state

	if level_data.asphalt_attributes:
		asphalt_attributes = level_data.asphalt_attributes.get_image()
		asphalt_attributes.decompress()
	else: asphalt_attributes = Image.create_empty(map_resolution.x, map_resolution.y, false, Image.FORMAT_RGBF)

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

## Saves user data into the specified folder
func save_user_data(base_dir: String = used_base_dir) -> void:
	assert(0 < base_dir.length())
	asphalt_state.get_image().save_png(LevelStructure.user_asphalt_state_tex_path(base_dir))

func reset_user_data(base_dir: String = used_base_dir) -> void:
	var user_data_path: String = LevelStructure.user_asphalt_state_tex_path(base_dir)
	if  FileAccess.file_exists(user_data_path): DirAccess.remove_absolute(user_data_path)
	initialize(LevelStructure.resource_path_in_dir(base_dir))
	update_materials()

func _on_asphalt_bomb_explode(explosion_pos: Vector3, explode_radius: float, amount_of_asphalt_to_add: float):
	push_config()
	set_update_brush_center(explosion_pos)
	tool_radius = explode_radius / $Ground.mesh.size.x
	asphalt_delta = amount_of_asphalt_to_add
	used_tool = ToolPanel.Tools.SHOVEL #TechDebt: Bomb as a tool should be configured instead
	update_asphalt()
	(func():
		await get_tree().process_frame
		pop_config()
	).call_deferred()
#endregion 

func _ready() -> void:
	_initialize(level_data, LevelStructure.resource_path_in_dir(used_base_dir))
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
