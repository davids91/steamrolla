extends TextureRect
class_name Hand

@export var target_pos = Vector2.ZERO
@export var hide_pos = Vector2.ZERO

func appear():
	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(self, "offset_transform_position", target_pos, 0.3)
	
func disappear():
	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(self, "offset_transform_position", hide_pos, 0.3)
