@abstract
extends Node3D
class_name ABird

@export var debug = false

const BIRD_REACTABLE_GROUP_NAME: String = "BirdReactable"

var bird_system: BirdSystem

@export var bird_data: BirdData

signal despawn

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
var _fly_direction: = Vector3.ZERO
@warning_ignore("unused_private_class_variable")
var _is_loitering: = true
var _spawn_pos: Vector3 = Vector3.ZERO
#endregion

var velocity := Vector3.ZERO
var is_flying := false
var _floor_detector: RayCast3D


# Is called from BirdSystem with custom tick rate
func think(_delta: float) -> void:
	if debug:
		print("%s's: Current state is: %d" % [name, current_state])
	_asses_threat()
	_make_decision()


func _create_floor_raycast() -> void:
	_floor_detector = RayCast3D.new()
	_floor_detector.target_position = Vector3(0.0, 2.0 ,0.0)
	add_child(_floor_detector)

func _snap_to_ground() -> Vector3:
	_floor_detector.force_raycast_update()
	if _floor_detector.is_colliding():
		var ground_pos = _floor_detector.get_collision_point()
		global_position.y = ground_pos.y
	return global_position
func _ready() -> void:
	bird_system = get_tree().get_first_node_in_group("BirdSystem")
	if bird_system == null: printerr("CRITICAL: Can't find the Bird System on " + name)
	if caution_area == null: printerr("CRITICAL: Caution Area not assigned on " + name)
	if flyaway_area == null: printerr("CRITICAL: Flyaway Area not assigned on " + name)

	caution_area.body_entered.connect(_on_caution_entered)
	caution_area.body_exited.connect(_on_caution_exited)
	flyaway_area.body_entered.connect(_on_flyaway_entered)

	caution_area.area_entered.connect(_on_caution_entered)
	caution_area.area_exited.connect(_on_caution_exited)
	flyaway_area.area_entered.connect(_on_flyaway_entered)

	_create_floor_raycast()
	_snap_to_ground()

	_spawn_pos = global_position

	bird_system.register(self)


func _process(delta: float) -> void:
	if velocity.length() == 0.0:
		if _active_threat:
			var direction = global_position.direction_to(_active_threat.global_position)
			var target_basis := Basis.looking_at(direction)
			global_basis = global_basis.slerp(target_basis, bird_data.rotation_speed - exp(-3.0 * delta))
	elif velocity.length()>0.1:
		var direction_to: Vector3 = global_rotation
		if _active_threat: direction_to =_active_threat.global_position
		var direction = -global_position.direction_to(direction_to)
		var target_basis := Basis.looking_at(direction)
		global_basis = global_basis.slerp(target_basis, bird_data.rotation_speed - exp(-3.0 * delta))

		global_position += velocity * delta
		_fly_direction = global_position + velocity
		_fly_direction.y = global_position.y


func _exit_tree() -> void:
	bird_system.unregister(self)
	despawn.emit()
