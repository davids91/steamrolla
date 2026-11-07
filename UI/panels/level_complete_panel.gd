extends Control

signal exit_scene()

@export var position_randomness: float = 50.
@export var confetti_instances: Array[GPUParticles2D]
@export var confetti_delay_sec: float = 0.35
func shoot_confetti() -> void:
	var shoot_tween: Tween = create_tween()
	for inst in confetti_instances:
		shoot_tween.tween_callback(func(): inst.emitting = true)
		shoot_tween.tween_interval(confetti_delay_sec)

func _ready() -> void:
	for inst in confetti_instances:
		inst.position += Vector2(randfn(0., position_randomness), randfn(0., position_randomness))

func _on_stay_button_pressed() -> void:
	queue_free()

func _on_level_select_button_pressed() -> void:
	exit_scene.emit()
