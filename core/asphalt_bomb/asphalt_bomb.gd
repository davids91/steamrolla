extends Node3D

const ACTIVATE_GROUP = "BombActivator"

@export_category("Bomb parameters")
@export var to_explode_time: float = 1.0
@export var exlode_radius: float = 10.0
@export var amount_to_add_asphalt: float = 20.0

@export var to_explode := false

@export var explosion_vfx_scene: PackedScene

signal asphalt_bomb_exploded(blast_pos: Vector3, explode_radius: float, amount_to_add_asphalt: float)



func _on_area_3d_area_entered(body: Node3D) -> void:
	if body.is_in_group(ACTIVATE_GROUP):
		await get_tree().create_timer(to_explode_time).timeout
		asphalt_bomb_exploded.emit(global_position, exlode_radius, amount_to_add_asphalt)
		if explosion_vfx_scene:
			var vfx: Node3D = explosion_vfx_scene.instantiate()
			get_tree().current_scene.add_child(vfx)
			vfx.global_position = global_position
		queue_free()
