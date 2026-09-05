@tool
extends Node3D

@onready var level_container: Node = get_node("/root/Main/LevelContainer")

@export var road_chunk_spacing: float = 50.

func _position_from_dir_name(dir_name: String) -> Vector3:
	var regex_match: RegExMatch = RegEx.create_from_string(MapStructure.LEVEL_FOLDER_NAME_REGEX).search(dir_name)
	if regex_match.get_group_count() < 2: push_error("level folder name " + dir_name + " is not supported!")
	var x: float = float(regex_match.strings[1]) # X coordinate is the first group, which is after the full match
	var y: float = float(regex_match.strings[2]) # Y coordinate is the second group, which is after the full match
	return Vector3(x * road_chunk_spacing, 0., y * road_chunk_spacing)

@export_tool_button("Load Level Data", "CheckBox") var create_level_data: Callable = _load_level_data
const road_chunk_template: PackedScene = preload("res://core/road_chunk.scn")
var scenes: Dictionary[RoadChunk, String] = {}
func _load_level_data() -> void:
	for c in $Chunks.get_children(): c.queue_free()
	# Iterate all of the compliant folders
	for d in DirAccess.get_directories_at(MapStructure.LEVELS_FOLDER): if MapStructure.complies_with_level_folder_name(d):
		var road_chunk: RoadChunk = road_chunk_template.instantiate()
		$Chunks.add_child(road_chunk)
		road_chunk.initialize(MapStructure.resource_path_in_levels(d))
		road_chunk.global_position = _position_from_dir_name(d)
		if FileAccess.file_exists(MapStructure.scene_path_in_levels(d)):
			scenes[road_chunk] = MapStructure.scene_path_in_levels(d)

var selected_chunk: RoadChunk = null
var selected_scene: PackedScene = null
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if $PlayerView.looking_at_chunk:
				if scenes.has($PlayerView.looking_at_chunk): $Highlight.modulate = Color.WHITE
				else: $Highlight.modulate = Color.RED
				$Highlight.visible = true
				$Highlight.global_position = $PlayerView.looking_at_chunk.global_position
				if selected_chunk == $PlayerView.looking_at_chunk and scenes.has(selected_chunk):
					time_left_to_travel = time_to_travel_towards_selected_sec
					selected_chunk = $PlayerView.looking_at_chunk
					create_tween().tween_property(%ScreenBlocker, "modulate", Color.WHITE, time_to_travel_towards_selected_sec)
					selected_scene = load(scenes[selected_chunk])
			selected_chunk = $PlayerView.looking_at_chunk
		else:
			$Highlight.visible = true

func _ready() -> void:
	_load_level_data()

@export var distance_travel_towards_selected: float = 100.
@export var time_to_travel_towards_selected_sec: float = 1.
var time_left_to_travel: float = 0.
func _process(delta: float) -> void:
	if 0. < time_left_to_travel and selected_chunk:
		$PlayerView.move_towards_object_by(distance_travel_towards_selected * delta, selected_chunk)
		time_left_to_travel -= delta
		if 0. >= time_left_to_travel:
			for c in level_container.get_children(): c.queue_free()
			level_container.add_child(selected_scene.instantiate())
