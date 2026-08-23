@tool
extends Node3D

@export var road_chunk_spacing: float = 50.

func _position_from_dir_name(dir_name: String) -> Vector3:
	var regex_match: RegExMatch = RegEx.create_from_string(MapStructure.LEVEL_FOLDER_NAME_REGEX).search(dir_name)
	if regex_match.get_group_count() < 2: push_error("level folder name " + dir_name + " is not supported!")
	var x: float = float(regex_match.strings[1]) # X coordinate is the first group, which is after the full match
	var y: float = float(regex_match.strings[2]) # Y coordinate is the second group, which is after the full match
	return Vector3(x * road_chunk_spacing, 0., y * road_chunk_spacing)

@export_tool_button("Load Level Data", "CheckBox") var create_level_data: Callable = _load_level_data
const road_chunk_template: PackedScene = preload("res://core/road_chunk.scn")
func _load_level_data() -> void:
	for c in $Chunks.get_children(): c.queue_free()
	# Iterate all of the compliant folders
	for d in DirAccess.get_directories_at(MapStructure.LEVELS_FOLDER): if MapStructure.complies_with_level_folder_name(d):
		var road_chunk: RoadChunk = road_chunk_template.instantiate()
		$Chunks.add_child(road_chunk)
		road_chunk.initialize(MapStructure.resource_path_in_levels(d))
		road_chunk.global_position = _position_from_dir_name(d)

func _ready() -> void:
	_load_level_data()
