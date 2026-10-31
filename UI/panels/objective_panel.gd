extends Control

signal panel_shown()
signal panel_hidden()
signal objective_completed(objective_name: String)

@export var photos: Array[Texture] = []:
	set(v):
		photos = v
		if photos.size() > 0: %Photo1/Image.texture = photos[0]
		else: %Photo1.visible = false
		if photos.size() > 1: %Photo2/Image.texture = photos[1]
		else: %Photo2.visible = false
		if photos.size() > 2: %Photo3/Image.texture = photos[2]
		else: %Photo3.visible = false
		if photos.size() > 3: %Photo4/Image.texture = photos[3]
		else: %Photo4.visible = false
@export var task_item_scn: PackedScene
@export var road_chunk: RoadChunk
@export var level: BaseLevel

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

func clicked_away() -> void:
	_on_panel_button_toggled(false)

func _on_panel_button_toggled(_toggled_on: bool) -> void:
	if not $ClickAwayRect.visible:
		$ClickAwayRect.visible = true
		panel_shown.emit()
		$AnimationPlayer.play("slide")
	else:
		panel_hidden.emit()
		$ClickAwayRect.visible = false
		$AnimationPlayer.play_backwards("slide")

## Set objectives to display and check for automatically
## Objective structure: {"objective identifier": "objective text"}
var used_base_dir: String = ""
func set_objectives(objectives_to_do: Dictionary[String, String], base_dir: String) -> void:
	used_base_dir = base_dir

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
	if road_chunk: road_chunk.initiate_scan()

func _ready() -> void:
	if is_completed("traffic"):
		traffic_objective_complete = true

@export var objective_check_interval_sec : float = 0.5
var time_left_to_check_sec: float = objective_check_interval_sec
@export var traffic_objective_delay_sec: float = 25.
var time_to_check_traffic_objective_sec: float = traffic_objective_delay_sec
var traffic_objective_complete: bool = false
func _process(delta: float) -> void:
	time_left_to_check_sec -= delta
	time_to_check_traffic_objective_sec -= delta
	if road_chunk:
		if time_left_to_check_sec < 0.:
			time_left_to_check_sec = objective_check_interval_sec
			# Check for asphalt state objective completion
			%AsphaltProgress.value = 1. - road_chunk.get_deviation_from_target() * 10.
			if road_chunk.is_state_in_target() and not is_completed("asphalt_done"):
				set_completed("asphalt_done")
				LevelStructure.level_attribute_store(used_base_dir, "asphalt_done")

		if( # Check for crashes in traffic
			not traffic_objective_complete
			and time_left_to_check_sec < objective_check_interval_sec * 0.5
			and time_to_check_traffic_objective_sec < 0.
		):
			time_to_check_traffic_objective_sec = objective_check_interval_sec * 0.6
			var crashed_car_count: int = 0
			for car in level.contained_traffic: if car.crashed: crashed_car_count += 1
			if 0 == crashed_car_count:
				traffic_objective_complete = true
				set_completed("traffic_ok")

			# Check for the other named objectives completion
			for i in range(1, objective_paths.size()):
				if LevelStructure.level_attribute_under_path_present(objective_paths[i]):
					if not is_completed(objective_names[i]): set_completed(objective_names[i])
				elif is_completed(objective_names[i]): revert_completed(objective_names[i])
