@tool
extends Node3D

@export var water_broke: bool = false:
	set(v):
		water_broke = v
		if get_node_or_null("WaterSpurt"): $WaterSpurt.emitting = v

@export var flying_time: float = 2.0
@export var flying_distance: float = 5.0
@export_range(0., TAU) var flying_angle_speed: float = PI/2.

func _ready() -> void:
	pass

@onready var already_crushed: bool = false:
	set(v):
		if v and not already_crushed and object_hitting_hydrant:
			water_broke = true
			var flying_tween = create_tween()
			flying_tween.tween_method(
				func(w):
					$fire_hydrant.global_position += (
						($fire_hydrant.global_position - object_hitting_hydrant.global_position).normalized()
						* w * flying_distance
					)
					$fire_hydrant.global_rotation += Vector3(
						randfn(0., flying_angle_speed), randfn(0., flying_angle_speed), randfn(0., flying_angle_speed)
					),
				0., 1. , flying_time
			)
			flying_tween.tween_callback(func(): $fire_hydrant.visible = false)
		already_crushed = v

var object_hitting_hydrant: Node3D
func _on_body_representation_area_entered(area: Area3D) -> void:
	if area.get_parent() is RoadworkTool and not already_crushed:
		object_hitting_hydrant = area.get_parent()
		already_crushed = true
