extends Node3D

@export var modulate: Color = Color.WHITE:
	set(v):
		modulate = v
		for n in get_children(): n.modulate = v
