extends Node
class_name BirdSystem

const TICK_RATE: float = 1.0

@export var bird_type: Dictionary[BirdData, PackedScene]
@export var spawn_radius_from_flocking_point: float = 3.0

var flocking_points: Array[Marker3D]
var birds: Array[ABird]
@onready var birds_node: Node3D = %Birds

var max_birds: int = 0

#is used in bird abstract script
func register(bird: ABird):
	birds.append(bird)
func unregister(bird: ABird):
	birds.erase(bird)

var _time_passed: float = 1.0

func spawn_new_birds():
	if bird_type.size() == 0: push_error("Forgot to assign bird types and their scenes"); return
	for i in range(max_birds):
		var scenes:Array[PackedScene] = bird_type.values()
		var birdi: int = randi_range(0, scenes.size()-1)
		var scene_to_spawn:PackedScene = scenes[birdi]
		if scene_to_spawn == null:
			push_error("Invalid scene at %s" % birdi)
			return
		var bird_instance: Node3D = scene_to_spawn.instantiate()
		var target_pos: Vector3 = Vector3.ZERO
		if len(flocking_points) > 0:
			var flocking_point:Marker3D = flocking_points[randi_range(0,len(flocking_points)-1)]
			var flocking_point_position = flocking_point.global_position
			target_pos = Vector3(
				randf_range(flocking_point_position.x, flocking_point_position.x + spawn_radius_from_flocking_point),
				flocking_point_position.y,
				randf_range(flocking_point_position.z, flocking_point_position.z + spawn_radius_from_flocking_point),
				
				)
		birds_node.add_child.call_deferred(bird_instance)
		bird_instance.set_deferred("global_position", target_pos)
		call_deferred("_setup_new_bird", bird_instance)
		print("Spawned a new bird")

func _setup_new_bird(bird: ABird) -> ABird:
	bird.despawn.connect(_on_bird_despawn)
	return bird

func _ready() -> void:
	flocking_points.assign(%FlockingPoints.get_children().filter(func(c): return c is Marker3D))
	birds.assign(%Birds.get_children().filter(func(c): return c is ABird))
	for b in birds:
		_setup_new_bird(b)
	max_birds = len(birds)



func _physics_process(delta: float) -> void:
	if len(birds) == 0: return
	_time_passed += delta
	var time_per_tick: float = 1.0 / TICK_RATE
	while _time_passed >= time_per_tick:
		_time_passed -= time_per_tick
		for bird in birds:
			bird.think(time_per_tick)


func _on_bird_despawn():
	print("bird has despawed")
	if len(birds) == 0:
		spawn_new_birds()
