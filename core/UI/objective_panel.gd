extends MarginContainer

const OBJECTIVE_ITEM_TEMPLATE: PackedScene = preload("res://core/UI/objective_item.tscn")

@export var objective_text: Array[String] = []:
	set(v):
		objective_text = v
		set_objectives(v)

var objectives: Array[ObjectiveItem] = []
func set_objectives(objectives_text: Array[String]) -> void:
	objectives.clear()
	for objective in objectives_text:
		var objective_item: ObjectiveItem = OBJECTIVE_ITEM_TEMPLATE.instantiate()
		objective_item.set_objective(objective)
		objective_item.completed = false
		objectives.append(objective_item)
		%ObjectiveList.add_child(objective_item)

func set_completed(objective_index: int) -> void:
	%ObjectiveList.get_child(objective_index).completed = true

func _on_check_btn_pressed() -> void:
	$ObjectiveButtonSound.play()
