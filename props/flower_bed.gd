@tool
extends Node3D

@export var flowers_size_max: float = 0.4
@export var dried_bush_color: Color = Color.from_string("#948f00", Color.YELLOW_GREEN)
@export var lively_bush_color: Color = Color.LIME_GREEN

@export_tool_button("Water flowers", "Heart") var shine_up: Callable = water_me
@export_tool_button("Dry flowers", "DirectionalLight3D") var dry_up: Callable = dry_me

@export var shine_up_time_sec: float = 3.

var shine_up_tween: Tween
func water_me() -> void:
	if shine_up_tween: shine_up_tween.kill()
	shine_up_tween = create_tween()
	shine_up_tween.tween_property($Bush, "modulate", Color.GREEN, shine_up_time_sec / 2.)
	shine_up_tween.tween_method(
		func(w: Color): $Bush.get_active_material(0).albedo_color = w,
		dried_bush_color, lively_bush_color, shine_up_time_sec / 2.
	).set_ease(Tween.EASE_OUT)
	shine_up_tween.tween_method(
		func(w:float): $FlowerMeshBase.get_active_material(0).set_shader_parameter("mesh_size", w),
		0., flowers_size_max, shine_up_time_sec / 2.
	).set_ease(Tween.EASE_IN)

func dry_me(duration_sec: float = shine_up_time_sec) -> void:
	if shine_up_tween: shine_up_tween.kill()
	shine_up_tween = create_tween()
	shine_up_tween.tween_property($Bush, "modulate", Color.GREEN, shine_up_time_sec / 2.)
	shine_up_tween.tween_method(
		func(w: Color): $Bush.get_active_material(0).albedo_color = w,
		lively_bush_color, dried_bush_color, duration_sec / 2.
	).set_ease(Tween.EASE_OUT)
	shine_up_tween.tween_method(
		func(w:float): $FlowerMeshBase.get_active_material(0).set_shader_parameter("mesh_size", w),
		flowers_size_max, 0., duration_sec / 2.
	).set_ease(Tween.EASE_IN)
	shine_up_tween.set_parallel()
