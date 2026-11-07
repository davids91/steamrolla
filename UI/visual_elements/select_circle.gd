@tool
extends Sprite3D

@export var ring_diameter: float = 0.72:
	set(v):
		ring_diameter = v
		material_override.set_shader_parameter("ring_diameter", v)

@export var ring_width: float = 0.25:
	set(v):
		ring_width = v
		material_override.set_shader_parameter("ring_width", v)

@export var ring_sharpness: float = 0.075:
	set(v):
		ring_sharpness = v
		material_override.set_shader_parameter("ring_sharpness", v)

@export var ring_fadeout_width: float = 2.925:
	set(v):
		ring_fadeout_width = v
		material_override.set_shader_parameter("ring_fadeout_width", v)

@export var ring_fadeout_sharpness: float = 0.65:
	set(v):
		ring_fadeout_sharpness = v
		material_override.set_shader_parameter("ring_fadeout_sharpness", v)

@export var ring_fade_speed: float = 0.72:
	set(v):
		ring_fade_speed = v
		material_override.set_shader_parameter("ring_fade_speed", v)

@export var animation_length_sec: float = 0.3
@onready var is_hidden: bool = true
@export_tool_button("Display", "Verified") var show_button: Callable = show_circle
func show_circle() -> Tween:
	is_hidden = false
	material_override.set_shader_parameter("ring_width", 0.)
	material_override.set_shader_parameter("ring_sharpness", 0.)
	material_override.set_shader_parameter("ring_fadeout_sharpness", 0.05)
	material_override.set_shader_parameter("ring_diameter", ring_diameter / 2.)
	material_override.set_shader_parameter("ring_fade_speed", 0.)

	var hide_tween = create_tween()
	hide_tween.set_parallel()
	hide_tween.set_ease(Tween.EASE_IN_OUT)
	hide_tween.tween_method(
		func(w: float): material_override.set_shader_parameter("ring_width", w),
		0., ring_width, animation_length_sec
	)
	hide_tween.tween_method(
		func(w: float): material_override.set_shader_parameter("ring_sharpness", w),
		0., ring_sharpness, animation_length_sec
	)
	hide_tween.tween_method(
		func(w: float): material_override.set_shader_parameter("ring_fadeout_sharpness", w),
		0., ring_fadeout_sharpness, animation_length_sec
	)
	hide_tween.tween_method(
		func(w: float): material_override.set_shader_parameter("ring_diameter", w),
		ring_diameter / 2., ring_diameter, animation_length_sec
	)
	hide_tween.tween_method(
		func(w: float): material_override.set_shader_parameter("ring_fade_speed", w),
		0., ring_fade_speed, animation_length_sec
	)
	return hide_tween

@export_tool_button("Hide", "StatusError") var hide_button: Callable = hide_circle
func hide_circle() -> Tween:
	is_hidden = true
	material_override.set_shader_parameter("ring_width", ring_width)
	material_override.set_shader_parameter("ring_sharpness", ring_sharpness)
	material_override.set_shader_parameter("ring_fadeout_sharpness", ring_fadeout_sharpness)
	material_override.set_shader_parameter("ring_diameter", ring_diameter)
	material_override.set_shader_parameter("ring_fade_speed", -ring_fade_speed)

	var hide_tween = create_tween()
	hide_tween.set_parallel()
	hide_tween.set_ease(Tween.EASE_IN_OUT)
	hide_tween.tween_method(
		func(w: float): material_override.set_shader_parameter("ring_width", w),
		ring_width, 0., animation_length_sec
	)
	hide_tween.tween_method(
		func(w: float): material_override.set_shader_parameter("ring_sharpness", w),
		ring_sharpness, -0.01, animation_length_sec
	)
	hide_tween.tween_method(
		func(w: float): material_override.set_shader_parameter("ring_fadeout_sharpness", w),
		ring_fadeout_sharpness, 0.005, animation_length_sec
	)
	hide_tween.tween_method(
		func(w: float): material_override.set_shader_parameter("ring_diameter", w),
		ring_diameter, ring_diameter / 2., animation_length_sec
	)
	hide_tween.tween_method(
		func(w: float): material_override.set_shader_parameter("ring_fade_speed", w),
		-ring_fade_speed, 0., animation_length_sec
	)
	return hide_tween

@export_range(0., 1.) var movement_responsiveness: float = 0.3
@onready var target_position: Vector3 = global_position
func _process(_delta: float) -> void:
	global_position = lerp(global_position, target_position, movement_responsiveness)
