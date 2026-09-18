extends MarginContainer

signal objective_completed(objective_name: String)

const OBJECTIVE_ITEM_TEMPLATE: PackedScene = preload("res://core/UI/objective_item.tscn")

@export var level: RoadChunk

## The level objectives and the "asphalt_done" objective at the end of the array
var objectives: Array[ObjectiveItem] = []
var objective_names: Array[String]
var objective_paths: Array[String]

## Set objectives to display and check for automatically
## Objective structure: {"objective identifier": "objective text"}
func set_objectives(objectives_to_do: Dictionary[String, String], base_dir: String) -> void:
	# Clear all objectives except "asphalt_done"
	for o in objectives: if o.name != "AsphaltProgress": o.queue_free()
	objective_paths.clear()
	objectives.reverse()
	objectives.resize(1)

	# Set the level specific objectives
	for objective in objectives_to_do.keys():
		var objective_item: ObjectiveItem = OBJECTIVE_ITEM_TEMPLATE.instantiate()
		objective_names.push_back(objective)
		objective_paths.push_back(LevelStructure.level_attribute_path(base_dir, objective))
		%ObjectiveList.add_child(objective_item)
		objective_item.set_objective(objectives_to_do[objective])
		objective_item.completed = false
		objectives.append(objective_item)

	# Automatically push the "ashpalt_done" objective
	objectives.push_back(objectives.pop_front()) # move the objective item to the back
	objective_names.push_back("asphalt_done")
	objective_paths.push_back(LevelStructure.level_attribute_path(base_dir, "asphalt_done"))

func is_completed(objective_name: String) -> bool:
	return objectives[objective_names.find(objective_name)].completed

func set_completed(objective_name: String) -> void:
	objectives[objective_names.find(objective_name)].completed = true
	objective_completed.emit(objective_name)

func revert_completed(objective_name: String) -> void:
	objectives[objective_names.find(objective_name)].completed = false

func _on_check_btn_pressed() -> void:
	$ObjectiveButtonSound.play()

@export var objective_check_interval_sec : float = 0.5
var time_left_to_check_sec: float = objective_check_interval_sec
func _process(delta: float) -> void:
	time_left_to_check_sec -= delta
	if 0. > time_left_to_check_sec:
		time_left_to_check_sec = objective_check_interval_sec

		# Check for asphalt state objective completion
		if level:
			%AsphaltDoneProgress.value = 1. - level.get_deviation_from_target() * 10.
			if level.is_state_in_target() and not is_completed("asphalt_done"):
				set_completed("asphalt_done")

		for i in objective_paths.size(): # Check for named objectives completion
			if LevelStructure.level_attribute_under_path_present(objective_paths[i]):
				set_completed(objective_names[i])
			elif not is_completed(objective_names[i]): revert_completed(objective_names[i])
