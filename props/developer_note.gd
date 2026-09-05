@tool
extends Sprite3D

@export_multiline var note: String = "":
	set(v):
		note = v
		if is_inside_tree() and  %Label: %Label.text = v

@export var text_color: Color:
	set(v):
		text_color = v
		if is_inside_tree() and %Label:
			%Label.label_settings.font_color = v

func _ready() -> void:
	if %Label:
		%Label.text = note
		%Label.label_settings.font_color = text_color
