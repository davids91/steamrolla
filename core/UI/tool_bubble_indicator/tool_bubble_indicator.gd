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

func _ready() -> void:
	show_tooltip(false)

@export var min_px_size: float = 0.07
@export var max_px_size: float = 0.08
var elapsed_time: float = 0.
func _process(delta: float) -> void:
	elapsed_time += delta
	pixel_size = min_px_size + (max_px_size - min_px_size) * (1. + sin(elapsed_time))
