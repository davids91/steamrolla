extends Node3D

@export var crush_sound_repeat_sec: float = 1.0
@export var crush_distance: float = 4.0
@export var crush_scale: float = 0.1

const crushes_me = "../ToolController/Roller"

func _ready() -> void:
	pass

var can_play_crush_sound: bool = true
func _process(delta: float) -> void:
	var roller_node: Node3D = get_node_or_null(crushes_me) as Node3D
	var smoke: Node3D = get_node_or_null("smoke-particles") as Node3D
	if roller_node:
		var dist: float = roller_node.global_position.distance_to(global_position)
		# print("car sees a roller! dist="+str(dist))
		if dist <= crush_distance:
			scale.y = lerp(scale.y, crush_scale, delta) # lol
			if (smoke): smoke.emitting = true
			if get_node_or_null("CrushSound") and not $CrushSound.playing and can_play_crush_sound:
				$CrushSound.play()
				can_play_crush_sound = false
				create_tween().tween_callback(func(): can_play_crush_sound = true).set_delay(crush_sound_repeat_sec)
			if get_node_or_null("WaterStream") and not $WaterStream.emitting:$WaterStream.emitting = true
			# crushSound.volume_db = linear_to_db(1-(dist/crush_distance))
		else:
			if (smoke): smoke.emitting = false
			if get_node_or_null("CrushSound") and $CrushSound.playing: $CrushSound.stop()
			# crushSound.volume_db = linear_to_db(0)
