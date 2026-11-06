@tool
extends Node3D

@export var light_beam_on: bool = true:
	set(v):
		light_beam_on = v
		if get_node_or_null("light-beam"): $"light-beam".visible = v
		else: visible = v 
