extends Node
class_name BirdSystem

const TICK_RATE: float = 1.0

@export var spawn_rate: float = 1.0

var flocking_points: Array[Marker3D]
var birds: Array[ABird]

func register(bird: ABird):
	birds.append(bird)
func unregister(bird: ABird):
	birds.erase(bird)

var _time_passed: float = 1.0

func _ready() -> void:
	flocking_points.assign(%FlockingPoints.get_children().filter(func(c): return c is Marker3D))
	birds.assign(%Birds.get_children().filter(func(c): return c is ABird))

func _physics_process(delta: float) -> void:
	if len(birds) == 0: return
	_time_passed += delta
	var time_per_tick: float = 1.0 / TICK_RATE
	while _time_passed >= time_per_tick:
		_time_passed -= time_per_tick
		for bird in birds:
			bird.think(time_per_tick)
