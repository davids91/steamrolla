class_name MapStructure
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
