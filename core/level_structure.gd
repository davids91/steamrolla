class_name LevelStructure
extends Node

const LEVELS_FOLDER: String = "res://levels/"
## The folder for a level should start with the appropriate coordinates, separated by a single underline
const LEVEL_FOLDER_NAME_REGEX: String = "^([0-9]*)_([0-9]*).*"
static func complies_with_level_folder_name(dir_name: String) -> bool:
	var level_folder_name_regex = RegEx.create_from_string(LEVEL_FOLDER_NAME_REGEX)
	return null != level_folder_name_regex.search(dir_name)

static func scene_path_in_dir(dir_path: String) -> String:
	return dir_path + "/level.scn"

static func resource_path_in_dir(dir_path: String) -> String:
	return dir_path + "/level_data.res"

static func scene_path_in_levels(level_name: String) -> String:
	return  LEVELS_FOLDER + level_name + "/level.scn"

static func resource_path_in_levels(level_name: String) -> String:
	return LEVELS_FOLDER + level_name + "/level_data.res"

static func asphalt_state_tex_path(base_dir: String)-> String:
	return base_dir + "/asphalt_state.png"

static func asphalt_target_state_tex_path(base_dir: String)-> String:
	return base_dir + "/target_asphalt_state.png"

static func _user_path_prefix(base_dir: String, user_token_length: int) -> String:
	var path: String = (
		base_dir
		.replace("res://", "user:##")
		.replace("/", "_")
		.replace("##", "//")
	);
	# Limit the filename to have max 255 characters including the user token
	path = path.substr(max(0, path.length() - (255 - user_token_length)))
	return path

## Returns the base directory for a particular level scene.
static func get_base_dir_for_scene(scene: Node) -> String:
	print(scene.scene_file_path.get_base_dir())
	return scene.scene_file_path.get_base_dir()

## Converts the res:// base dir of the level into a single filename for the asphalt state
static func user_asphalt_state_tex_path(base_dir: String) -> String:
	return _user_path_prefix(base_dir, 18) + "_asphalt_state.png"

#region Level Attributes
"""
Each level may have a set of objectives, stored as attributes as well as a list of objectives
the player may complete on each level. The list is a Dictionary[String, String]:
	{"Objective name":"Objective text"}
Each objective completion is denoted by a unique file stored within the 'user://' folder
"""
## Provides the path to the list of attributes the given level abse directory contains
static func level_attribute_list_path(base_dir: String) -> String:
	return _user_path_prefix(base_dir, 10) + "_attr_list"

## Reads and provides the stored attributes for the given level base directory
static func level_attribute_list(base_dir: String) -> Dictionary[String, String]:
	var file: FileAccess = FileAccess.open(level_attribute_list_path(base_dir), FileAccess.READ)
	return file.get_var()

## Updates the stored attributes for the given level base directory
static func level_attribute_list_overwrite(base_dir: String, new_attribute_list: Dictionary[String, String]) -> void:
	var file: FileAccess = FileAccess.open(level_attribute_list_path(base_dir), FileAccess.WRITE)
	file.store_var(new_attribute_list)

## Path for the given attribute within the given levels base directory
static func level_attribute_path(base_dir: String, attribute_name: String) -> String:
	return _user_path_prefix(base_dir, 6 + attribute_name.length()) + "_attr_" + attribute_name

## Presence of the given attribute within the given levels base directory
static func level_attribute_present(base_dir: String, attribute_name: String) -> bool:
	return FileAccess.file_exists(level_attribute_path(base_dir, attribute_name))

## Set the given attribute within the given levels base directory
static func level_attribute_set(base_dir: String, attribute_name: String) -> void:
	var file: FileAccess = FileAccess.open(level_attribute_path(base_dir, attribute_name), FileAccess.WRITE)
	file.store_var(true)

## Erase the given attribute within the given levels base directory
static func level_attribute_reset(base_dir: String, attribute_name: String) -> void:
	DirAccess.remove_absolute(level_attribute_path(base_dir, attribute_name))

## Provides the completed percentage of the level, meaning the number of set attributes out of the full list
static func level_attribute_completion(base_dir: String) -> float:
	var attribute_list: Dictionary[String, String] = level_attribute_list(base_dir)
	var completed_attr: int = 0
	for attr in attribute_list.keys(): if level_attribute_present(base_dir, attr): completed_attr += 1
	return float(completed_attr) / float(attribute_list.size())
#endregion
