extends MarginContainer

const OBJECTIVE_ITEM_TEMPLATE: PackedScene = preload("res://core/UI/objective_item.tscn")

var objectives: Array[ObjectiveItem] = []
var objective_paths: Array[String]

## Set objectives to display and check for automatically
## Objective structure: {"objective identifier": "objective text"}
func set_objectives(objectives_to_do: Dictionary[String, String], base_dir: String) -> void:
	objective_paths.clear()
	objectives.clear()
	for objective in objectives_to_do.keys():
		var objective_item: ObjectiveItem = OBJECTIVE_ITEM_TEMPLATE.instantiate()
		objective_paths.push_back(LevelStructure.level_attribute_path(base_dir, objective))
		%ObjectiveList.add_child(objective_item)
		objective_item.set_objective(objectives_to_do[objective])
		objective_item.completed = false
		objectives.append(objective_item)

func set_completed(objective_index: int) -> void:
	%ObjectiveList.get_child(objective_index).completed = true

func revert_completed(objective_index: int) -> void:
	%ObjectiveList.get_child(objective_index).completed = false

func _on_check_btn_pressed() -> void:
	$ObjectiveButtonSound.play()

@export var objective_check_interval_sec : float = 0.5
var time_left_to_check_sec: float = objective_check_interval_sec
func _process(delta: float) -> void:
	time_left_to_check_sec -= delta
	if 0. > time_left_to_check_sec:
		time_left_to_check_sec = objective_check_interval_sec
		for i in objective_paths.size(): # Check for objective completion
			if LevelStructure.level_attribute_under_path_present(objective_paths[i]):
				set_completed(i)
			else: revert_completed(i)
