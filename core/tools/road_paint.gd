extends Node3D

@export var road_paint_animation_curve: Curve

@onready var original_paint_sizes: Dictionary[Node, Vector2] = {}
@onready var hidden_paints: Array[Node] = []
func _ready() -> void:
	for paint in get_children():
		original_paint_sizes[paint] = paint.mesh.size
		paint.mesh.size = Vector2.ZERO
		paint.visible = false
		hidden_paints.push_back(paint)

## Displays a random piece of roadpaint, returns with true if there is more to show
func show_random(animation_length: float = 0.7) -> bool:
	if hidden_paints.is_empty(): return false
	var to_show: Node = hidden_paints.pick_random()
	hidden_paints.erase(to_show)
	to_show.visible = true
	create_tween().tween_method(
		func(w: float):
			to_show.mesh.size = road_paint_animation_curve.sample(w) * original_paint_sizes[to_show],
		0., 1., animation_length
	).set_ease(Tween.EASE_IN_OUT)
	return not hidden_paints.is_empty()
