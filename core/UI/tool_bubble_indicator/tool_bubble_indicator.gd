class_name UsageIndicator
extends Sprite3D

static var displayed: UsageIndicator:
	set(v):
		if v and displayed and v != displayed: displayed.show_tooltip(false)
		displayed = v

@onready var is_showing = false
func show_tooltip(should_show: bool) -> void:
	if should_show and not is_showing:
		$AnimationPlayer.play("show")
		is_showing = true
		displayed = self
	elif not should_show and is_showing:
		if displayed == self: displayed = null
		$AnimationPlayer.play_backwards("show")
		is_showing = false
