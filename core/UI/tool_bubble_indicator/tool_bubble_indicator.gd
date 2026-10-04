extends Sprite3D

var is_showing = false

func show_tooltip(should_show: bool) -> void:
	if should_show and not is_showing:
		$AnimationPlayer.play("show")
		is_showing = true
	elif not should_show and is_showing:
		$AnimationPlayer.play_backwards("show")
		is_showing = false
