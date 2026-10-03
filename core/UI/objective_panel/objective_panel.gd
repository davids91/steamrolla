extends Control

signal objective_completed(objective_name: String)

@export var task_item_scn: PackedScene
@export var level: RoadChunk

## The level objectives and the "asphalt_done" objective at the end of the array
@onready var objectives: Array[ObjectiveItemv2] = [%AsphaltDoneTaskItem]
var objective_names: Array[String]
var objective_paths: Array[String]

func set_level_intro_label(level_intro_text: String):
	%LevelIntroLabel.text = level_intro_text

func set_field_photos(field_photos_array: Array[Texture]):
	var photos_count = min(field_photos_array.size(), 2)
	for i in photos_count:
		var photo: TextureRect = get_node("%Photo%d/Image" % (i+1) )
		photo.texture = field_photos_array[i]

func _on_panel_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$AnimationPlayer.play("slide")
	else:
		$AnimationPlayer.play_backwards("slide")

## Set objectives to display and check for automatically
## Objective structure: {"objective identifier": "objective text"}
func set_objectives(objectives_to_do: Dictionary[String, String], base_dir: String) -> void:
	# Clear all objectives except "asphalt_done"
	for o in objectives: if o.name != "AsphaltDoneTaskItem": o.queue_free()
	objective_paths.clear()
	objective_names.clear()

	# Manually set the "ashpalt_done" objective
	objectives.resize(1)
	objective_names.push_back("asphalt_done")
	objective_paths.push_back(LevelStructure.level_attribute_path(base_dir, "asphalt_done"))

	# Set the level specific objectives
	for objective in objectives_to_do.keys():
		if objective == "asphalt_done": continue # Asphalt Done Task is already present within the list
		var objective_item: ObjectiveItemv2 = task_item_scn.instantiate()
		objective_names.push_back(objective)
		objective_paths.push_back(LevelStructure.level_attribute_path(base_dir, objective))
		%TaskList.add_child(objective_item)
		objective_item.set_objective(objectives_to_do[objective])
		objective_item.completed = false
		objectives.append(objective_item)

func is_completed(objective_name: String) -> bool:
	return objectives[objective_names.find(objective_name)].completed

func set_completed(objective_name: String) -> void:
	objectives[objective_names.find(objective_name)].completed = true
	objective_completed.emit(objective_name)

func revert_completed(objective_name: String) -> void:
	objectives[objective_names.find(objective_name)].completed = false

func _on_check_btn_pressed() -> void:
	if level: level.initiate_scan()

@export var objective_check_interval_sec : float = 0.5
var time_left_to_check_sec: float = objective_check_interval_sec
func _process(delta: float) -> void:
	time_left_to_check_sec -= delta
	if 0. > time_left_to_check_sec:
		time_left_to_check_sec = objective_check_interval_sec

		# Check for asphalt state objective completion
		if level:
			%AsphaltProgress.value = 1. - level.get_deviation_from_target() * 10.
			if level.is_state_in_target() and not is_completed("asphalt_done"):
				set_completed("asphalt_done")

		# Check for the other named objectives completion
		for i in range(1, objective_paths.size()):
			if LevelStructure.level_attribute_under_path_present(objective_paths[i]):
				if not is_completed(objective_names[i]): set_completed(objective_names[i])
			elif is_completed(objective_names[i]): revert_completed(objective_names[i])
