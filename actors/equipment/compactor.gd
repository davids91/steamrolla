extends Node3D

func _ready() -> void:
	$Bloke/AnimationPlayer.current_animation = "default"

func set_color(color: Color) -> void:
	create_tween().tween_property($Bloke/metarig/Skeleton3D/bloke.get_active_material(0), "albedo_color", color, 0.5)
	create_tween().tween_property($Bloke/metarig/Skeleton3D/hat.get_active_material(0), "albedo_color", color, 0.5)
	create_tween().tween_property($compactor/Cube_001.get_active_material(0), "albedo_color", color, 0.5)

@export var vibration_speed: float = 100.
@export var vibration_extent: float = 0.1
@export var elapsed_time = 0.
func _process(delta: float) -> void:
	elapsed_time += delta
	$compactor.position += $compactor.basis.y * sin(elapsed_time * vibration_speed) * vibration_extent
	$Bloke.position += $Bloke.basis.y * sin(elapsed_time * vibration_speed) * vibration_extent
