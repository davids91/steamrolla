@tool
extends Node3D

func _validate_property(property: Dictionary) -> void:
	if (
		property.name == "create_level_data"
		or property.name == "save_level_data"
		or property.name == "load_level_data"
		or property.name == "change_data_mode"
	):
		$RoadChunk.visible = false
		if _level_folder_exists():
			if property.name == "create_level_data": property.usage &= ~PROPERTY_USAGE_EDITOR
			if _is_level_data_in_packaged_format(): $RoadChunk.visible = true
			else:
				if property.name == "save_level_data": property.usage |= PROPERTY_USAGE_READ_ONLY
				if property.name == "save_level_data": property.usage |= PROPERTY_USAGE_READ_ONLY
				elif property.name == "load_level_data": property.usage |= PROPERTY_USAGE_READ_ONLY
		else:
			if property.name == "create_level_data": property.usage |= PROPERTY_USAGE_EDITOR
			elif property.name == "save_level_data": property.usage &= ~PROPERTY_USAGE_EDITOR
			elif property.name == "load_level_data": property.usage &= ~PROPERTY_USAGE_EDITOR
			elif property.name == "change_data_mode": property.usage &= ~PROPERTY_USAGE_EDITOR
			elif property.name == "level_data_mode": property.usage &= ~PROPERTY_USAGE_EDITOR

@export_category("Level Data")
@export var map_overview: Image = preload("res://textures/map_overview_concept/map_file.png").get_image()
@export var one_level_within_the_overview: Vector2i = Vector2i(256, 256) ## What resolution part of the map to upscale into @level_resolution
@export var level_resolution: Vector2i = Vector2i(512, 512) ## How large should the largest texture be within the level

func _get_map_region_for_coordinate() -> Rect2i:
	return Rect2i(
		one_level_within_the_overview * level_coordinate,
		one_level_within_the_overview
	)

@export var levels_folder: String = "res://levels/":
	set(v): pass

## Images for level data in raw mode
## RAW_MODE: data of the level are in separate heightmaps
const raw_image_names: Array[String] = [
	"raw_terrain_heightmap",
	"raw_terrain_crackmap",
	"terrain_normalmap",
	"terrain_albedo_image",
	"raw_asphalt_presence",
	"raw_asphalt_editability",
	"raw_water_presence",
	"start_asphalt_state",
	"target_asphalt_state",
]

## Images for level data in packaged mode
## PACKAGED_MODE: data of the level is collected in a well defined set of images
## --> names of the images are also the fields within @RoadChunkData
const final_image_names: Array[String] = [
	"terrain_heightmap",
	"terrain_normalmap",
	"terrain_albedo_image",
	"asphalt_attributes",
	"start_asphalt_state",
	"target_asphalt_state",
]

@export_category("Level Data state")
@export var level_coordinate: Vector2i = Vector2i.ZERO:
	set(pos):
		level_coordinate = pos
		cached_level_base_dir = "N/A"
		if _is_level_data_in_packaged_format() or _is_level_data_in_raw_format(): _load_level_data()
		notify_property_list_changed()

## The name of the folder under the given coordinate, no zeroes as padding, just the raw numbers
func _level_map_name() -> String: return str(level_coordinate.x) + "_" + str(level_coordinate.y)

## The path of the folder containing all the level data
var cached_level_base_dir: String = "N/A"
func _level_base_dir() -> String:
	if cached_level_base_dir != "N/A" and DirAccess.dir_exists_absolute(levels_folder + cached_level_base_dir + "/"):
		return levels_folder + cached_level_base_dir + "/"
	if DirAccess.dir_exists_absolute(levels_folder + _level_map_name() + "/"):
		return levels_folder + _level_map_name() + "/"

	# Neither the cache or the default name exists, look for all compliant folders that start with the given coordinates
	for d in DirAccess.get_directories_at(MapStructure.LEVELS_FOLDER):
		if d.begins_with(_level_map_name()) and MapStructure.complies_with_level_folder_name(d):
			cached_level_base_dir = d
			return levels_folder + cached_level_base_dir + "/"
	
	# No folder matches the given coordinates, it has to be created
	cached_level_base_dir = _level_map_name()
	return levels_folder + cached_level_base_dir + "/"

## the path of the resource of the level
func _level_resource_path() -> String: return MapStructure.resource_path_in_dir(_level_base_dir())

## the path of the image which contains information for the level
func _level_image_path(image_name: String) -> String: return _level_base_dir() + image_name + ".png"

func _level_folder_exists() -> bool: return DirAccess.dir_exists_absolute(_level_base_dir())
func _level_resource_exists() -> bool: return FileAccess.file_exists(_level_resource_path())
func _level_image_exists(image_name: String) -> bool: return FileAccess.file_exists(_level_image_path(image_name))
func _is_level_data_in_raw_format() -> bool:
	if not _level_folder_exists(): return false
	for img in raw_image_names: if not _level_image_exists(img): return false
	return true

func _is_level_data_in_packaged_format() -> bool:
	if not _level_folder_exists(): return false
	for img in final_image_names: if not _level_image_exists(img): return false
	return true

var level_data_state_editable: bool = false
@export var level_data_mode: String = "N/A":
	set(v): if level_data_state_editable: level_data_mode = v

func _set_data_mode_raw() -> void:
	level_data_state_editable = true
	level_data_mode = "RAW"
	level_data_state_editable = false
	notify_property_list_changed()

func _set_data_mode_packaged() -> void:
	level_data_state_editable = true
	level_data_mode = "PACKAGED"
	level_data_state_editable = false
	notify_property_list_changed()

@export_tool_button("Create Level Data", "CheckBox") var create_level_data: Callable = _create_level_data
func _create_level_data() -> void:
	if not _level_folder_exists(): DirAccess.make_dir_absolute(_level_base_dir())
	if _level_resource_exists(): %RoadChunk.level_data = load(_level_resource_path())
	else: %RoadChunk.level_data = RoadChunkData.new()
	# New level is always created in raw format: 
	for img in raw_image_names:
		var image: Image
		# if it's the albedo, take the image from the map overview instead of making an empty image
		if img == "terrain_albedo_image":
			image = map_overview.get_region(_get_map_region_for_coordinate())
			image.resize(level_resolution.x, level_resolution.y)
		else: image = Image.create_empty(level_resolution.x, level_resolution.y, false, Image.FORMAT_RF)
		image.save_png(_level_image_path(img))
		%RoadChunk.level_data.set(img, load(_level_image_path(img)))
	_set_data_mode_raw()
	ResourceSaver.save(%RoadChunk.level_data, _level_resource_path())
	EditorInterface.get_resource_filesystem().scan() #TechDebt: This makes itch export crash

@export_tool_button("Change Data Mode", "Save") var change_data_mode: Callable = _change_data_mode
func _change_data_mode() -> void:
	if _is_level_data_in_packaged_format(): # Convert level data, make the raw/uncompressed format
		# Unchanged: terrain_normalmap, terrain_albedo_image, start_asphalt_state, target_asphalt_state
		# Changed:
		var terrain_heightmap: Image = load(_level_image_path("terrain_heightmap")).get_image()
		terrain_heightmap.decompress()
		var asphalt_attributes: Image = load(_level_image_path("asphalt_attributes")).get_image()
		asphalt_attributes.decompress()
		var raw_terrain_heightmap: Image = Image.create_empty(level_resolution.x, level_resolution.y, false, Image.FORMAT_RF)
		var raw_terrain_crackmap: Image = Image.create_empty(level_resolution.x, level_resolution.y, false, Image.FORMAT_RF)
		var raw_asphalt_presence: Image = Image.create_empty(level_resolution.x, level_resolution.y, false, Image.FORMAT_RF)
		var raw_asphalt_editability: Image = Image.create_empty(level_resolution.x, level_resolution.y, false, Image.FORMAT_RF)
		var raw_water_presence: Image = Image.create_empty(level_resolution.x, level_resolution.y, false, Image.FORMAT_RF)

		# Unpack color channels
		for x in level_resolution.x: for y in level_resolution.y:
			raw_terrain_heightmap.set_pixel(x,y, Color(terrain_heightmap.get_pixel(x,y).r, 0., 0.))
			raw_terrain_crackmap.set_pixel(x,y, Color(terrain_heightmap.get_pixel(x,y).g, 0., 0.))
			raw_asphalt_presence.set_pixel(x,y, Color(asphalt_attributes.get_pixel(x,y).r, 0., 0.))
			raw_asphalt_editability.set_pixel(x,y, Color(asphalt_attributes.get_pixel(x,y).g, 0., 0.))
			raw_water_presence.set_pixel(x,y, Color(asphalt_attributes.get_pixel(x,y).b, 0., 0.))

		# Save the new image files, erase the old images
		raw_terrain_heightmap.save_png(_level_image_path("raw_terrain_heightmap"))
		raw_terrain_crackmap.save_png(_level_image_path("raw_terrain_crackmap"))
		raw_asphalt_presence.save_png(_level_image_path("raw_asphalt_presence"))
		raw_asphalt_editability.save_png(_level_image_path("raw_asphalt_editability"))
		raw_water_presence.save_png(_level_image_path("raw_water_presence"))
		DirAccess.remove_absolute(_level_image_path("terrain_heightmap"))
		DirAccess.remove_absolute(_level_image_path("asphalt_attributes"))
		_save_level_data()
		get_tree().create_timer(0.5).timeout.connect(func(): if not _is_level_data_in_raw_format():
			push_error("Unable to convert level data from packaged to raw format!")
		)
	elif _is_level_data_in_raw_format():
		# Unchanged: terrain_normalmap, terrain_albedo_image, start_asphalt_state, target_asphalt_state
		# Changed:
		var raw_terrain_heightmap: Image = load(_level_image_path("raw_terrain_heightmap")).get_image()
		raw_terrain_heightmap.decompress()
		var raw_terrain_crackmap: Image = load(_level_image_path("raw_terrain_crackmap")).get_image()
		raw_terrain_crackmap.decompress()
		var raw_asphalt_presence: Image = load(_level_image_path("raw_asphalt_presence")).get_image()
		raw_asphalt_presence.decompress()
		var raw_asphalt_editability: Image = load(_level_image_path("raw_asphalt_editability")).get_image()
		raw_asphalt_editability.decompress()
		var raw_water_presence: Image = load(_level_image_path("raw_water_presence")).get_image()
		raw_water_presence.decompress()
		var terrain_heightmap: Image = Image.create_empty(level_resolution.x, level_resolution.y, false, Image.FORMAT_RGBF)
		var asphalt_attributes: Image = Image.create_empty(level_resolution.x, level_resolution.y, false, Image.FORMAT_RGBF)

		# Pack color channels
		for x in level_resolution.x: for y in level_resolution.y:
			terrain_heightmap.set_pixel(x,y, Color(
				raw_terrain_heightmap.get_pixel(x,y).r,
				raw_terrain_crackmap.get_pixel(x,y).r,
				0.
			))
			asphalt_attributes.set_pixel(x,y, Color(
				raw_asphalt_presence.get_pixel(x,y).r,
				raw_asphalt_editability.get_pixel(x,y).r,
				raw_water_presence.get_pixel(x,y).r
			))

		# Save the new image files, erase the old images
		DirAccess.remove_absolute(_level_image_path("raw_terrain_heightmap"))
		DirAccess.remove_absolute(_level_image_path("raw_terrain_crackmap"))
		DirAccess.remove_absolute(_level_image_path("raw_asphalt_presence"))
		DirAccess.remove_absolute(_level_image_path("raw_asphalt_editability"))
		DirAccess.remove_absolute(_level_image_path("raw_water_presence"))
		terrain_heightmap.save_png(_level_image_path("terrain_heightmap"))
		asphalt_attributes.save_png(_level_image_path("asphalt_attributes"))
		EditorInterface.get_resource_filesystem().scan() #TechDebt: This makes itch export crash
		get_tree().create_timer(0.5).timeout.connect(func(): # also try to initialize level data
			if _is_level_data_in_packaged_format(): _save_level_data()
			else: push_error("Unable to convert level data from raw to packaged format!")
		)
	else: push_error("Level data is in undefined state")

@export_tool_button("Load/Refresh Level Data", "Load") var load_level_data: Callable = _load_level_data
func _load_level_data() -> void:
	if not Engine.is_editor_hint(): return
	var resource_updated: bool = false
	if not _level_folder_exists(): DirAccess.make_dir_absolute(_level_base_dir())
	if _level_resource_exists(): %RoadChunk.level_data = load(_level_resource_path())
	else:
		%RoadChunk.level_data = RoadChunkData.new()
		resource_updated = true
	if _is_level_data_in_packaged_format():
		for img in final_image_names:
			%RoadChunk.level_data.set(img, load(_level_image_path(img)))
		_set_data_mode_packaged()
	else: # create empty image for every image that is not available
		for img in raw_image_names:
			if not _level_image_exists(img):
				push_warning("level attribute <" + img + "> was not availble, created empty image for it!")
				resource_updated = true
				var image: Image
				if img == "terrain_albedo_image": # if it's the albedo, take the image from the map overview
					image = map_overview.get_region(_get_map_region_for_coordinate())
					image.resize(level_resolution.x, level_resolution.y)
				else: image = Image.create_empty(level_resolution.x, level_resolution.y, false, Image.FORMAT_RF)
				image.save_png(_level_image_path(img))
		_set_data_mode_raw()

	# For each field in the resource: if the field is not set but the image is available, connect them
	for img in final_image_names: if not %RoadChunk.get(img) and _level_image_exists(img):
		%RoadChunk.level_data.set(img, load(_level_image_path(img)))
		resource_updated = true

	if resource_updated:
		ResourceSaver.save(%RoadChunk.level_data, _level_resource_path())
		EditorInterface.get_resource_filesystem().scan() #TechDebt: This makes itch export crash
		get_tree().create_timer(1.).timeout.connect(func():%RoadChunk.initialize(_level_resource_path()))
	else: %RoadChunk.initialize(_level_resource_path())

@export_tool_button("Save Level Data", "Save") var save_level_data: Callable = _save_level_data
func _save_level_data():
	if not Engine.is_editor_hint(): return
	if not get_node_or_null("%RoadChunk"): return
	if not _is_level_data_in_packaged_format(): return
	if not _level_resource_exists(): $RoadChunk.level_data = RoadChunkData.new()
	# always overwrite stored start and target asphalt states with the ones provided by the editor
	if %RoadChunk.asphalt_state:
		%RoadChunk.asphalt_state.get_image().save_png(_level_image_path("start_asphalt_state"))
	if %RoadChunk.level_data.target_asphalt_state:
		%RoadChunk.level_data.target_asphalt_state.get_image().save_png(_level_image_path("target_asphalt_state"))
	EditorInterface.get_resource_filesystem().scan() #TechDebt: This makes itch export crash
	get_tree().create_timer(0.5).timeout.connect(func(): # Update resource, set the updated fields and save it!
		for img in final_image_names: %RoadChunk.level_data.set(img, load(_level_image_path(img)))
		ResourceSaver.save(%RoadChunk.level_data, _level_resource_path())
	)

@export_category("Asphalt updates")
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

@export_category("Level Completion(Misc)")
@export var level_scan_range: float = 0.25
@export_tool_button("Scan Level", "ColorTrackVu") var scan_for_height: Callable = func():
	if not %RoadChunk: return
	%RoadChunk.initiate_scan(level_scan_range)

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
	_load_level_data()
	%ToolPanel.call_deferred("select", ToolPanel.Tools.PAVER)
	for tool in $ToolController.get_children(): if tool is RoadworkTool:
		tool.set_color(Color.TRANSPARENT)
