extends Resource
class_name BirdData

@export_category("General")
@export var name: String = "Bird"
@export_category("Movment")
@export var walk_speed: float = 1.0
@export var run_speed: float = 2.0
@export var fly_speed: float = 10.0
@export var rotation_speed: float = 1
@export var loiter_slowness: float = 100
@export_range(0.0, 2.0, 0.1) var lotier_jump_height: float = 0.1
@export var _loiter_max_dist : = 2


@export_category("Behaviour")
 # If the velocity of incoming object exceeds it - fly even if not in flyaway radius
@export var tolerable_velocity: float = 1.0
@export var tolerable_distance_for_threat = 5.0
@export var min_brain_delay: float = 0.1
@export var max_brain_delay: float = 1.0
