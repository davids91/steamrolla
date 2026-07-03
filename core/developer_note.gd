@tool
extends Sprite3D

@export_multiline var note: String = "":
	set(v):
		note = v
		if %Label: %Label.text = v

@export var text_color: Color:
	set(v):
		text_color = v
		if %Label:
			%Label.label_settings.font_color = v
