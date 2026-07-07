@abstract
extends CharacterBody3D
class_name ABird

const BIRD_REACTABLE_GROUP_NAME: String = "BirdReactable"

var bird_system: BirdSystem

@export var bird_data: BirdData

enum State {ONGROUND, RUNNING, FLYING} 
@export var current_state: State

@export var caution_area: Area3D
@export var flyaway_area: Area3D


func change_state(new_state):
	current_state = new_state

@abstract func _asses_threat()
@abstract func _make_decision()
@abstract func _process_evade()
@abstract func _process_fly()
@abstract func _on_caution_entered(body: Node3D)
@abstract func _on_caution_exited(body: Node3D)
@abstract func _on_flyaway_entered(body: Node3D)


#region internal memory
var _active_threat: Node3D = null
var _fly_direction: Vector3 = Vector3.ZERO
var _away: Vector3 = Vector3.ZERO
var _to_rotate_to: Quaternion
#endregion

# Is called from BirdSystem with custom tick rate
func think(delta: float) -> void:
	print("Current state is: ", current_state)
	_asses_threat()
	_make_decision()



func _ready() -> void:
	bird_system = get_tree().get_first_node_in_group("BirdSystem")
	assert(bird_system != null, "CRITICAL: Can't find the Bird System on " + name)	
	
	assert(caution_area != null, "CRITICAL: Caution Area not assigned on " + name)
	assert(flyaway_area != null, "CRITICAL: Flyaway Area not assigned on " + name)
	
	caution_area.body_entered.connect(_on_caution_entered)
	caution_area.body_exited.connect(_on_caution_exited)
	flyaway_area.body_entered.connect(_on_flyaway_entered)
	
	caution_area.area_entered.connect(_on_caution_entered)
	caution_area.area_exited.connect(_on_caution_exited)
	flyaway_area.area_entered.connect(_on_flyaway_entered)
	
	bird_system.register(self)
	

func _physics_process(delta: float) -> void:
	if _to_rotate_to.is_normalized():
		quaternion = quaternion.slerp(_to_rotate_to, bird_data.rotation_speed * delta)
	move_and_slide()
	
func _exit_tree() -> void:
	bird_system.unregister(self)
