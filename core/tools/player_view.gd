class_name PlayerView
extends OrbitCamera3D

@export var cursor: Node3D
@export var make_current_on_start: bool = false
@onready var camera: Camera3D = $Pitch/Camera3D

func lock_view(yesno: bool = true) -> void:
	_view_locked = yesno

func _ready() -> void:
	if make_current_on_start: make_current()

var _view_locked: bool = false
func _rotate_camera_by(offset: Vector2) -> void:
	if not _view_locked: super(offset)

func move_towards_object_by(distance: float, o: Node3D = looking_at_chunk) -> void:
	if not o: return
	global_position += (o.global_position - global_position).normalized() * distance

var looking_at_chunk: RoadChunk
func _physics_process(_delta: float) -> void:
	if not cursor: return
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var mouse_screen_position: Vector2 = get_viewport().get_mouse_position()
	var origin_global_pos: Vector3 = camera.project_ray_origin(mouse_screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_screen_position)
	var raycast_result: Dictionary = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		origin_global_pos, origin_global_pos + ray_direction * 500000.
	))
	if "position" in raycast_result:
		if raycast_result.collider is RoadChunkBody:
			looking_at_chunk = raycast_result.collider.get_road_chunk()
		cursor.global_position = raycast_result.position
		cursor.look_at(raycast_result.position + raycast_result.normal)
