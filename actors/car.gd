extends Node3D

@export var crush_distance: float = 4.0
@export var crush_scale: float = 0.1

const crushes_me = "../ToolController/Roller"

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	var roller_node: Node3D = get_node_or_null(crushes_me) as Node3D
	var smoke: Node3D = get_node_or_null("smoke-particles") as Node3D
	var crushSound: Node3D = get_node_or_null("CarCrush") as Node3D
	if roller_node:
		var dist: float = roller_node.global_position.distance_to(global_position)
		# print("car sees a roller! dist="+str(dist))
		if dist <= crush_distance:
			scale.y = lerp(scale.y, crush_scale, delta) # lol
			if (smoke): smoke.emitting = true
			if (crushSound): 
				if not crushSound.playing: crushSound.play()
				# crushSound.volume_db = linear_to_db(1-(dist/crush_distance))
		else:
			if (smoke): smoke.emitting = false
			if (crushSound): 
				if crushSound.playing: crushSound.stop()
				# crushSound.volume_db = linear_to_db(0)
