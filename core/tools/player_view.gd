class_name PlayerView
extends OrbitCamera3D

@export var cursor: Node3D
@export var make_current_on_start: bool = false

@onready var camera: Camera3D = %Camera3D
@onready var camera_transform: Transform3D:
	get(): return camera.global_transform
	set(v): camera.global_transform = v

var lock_requests: Array[Node] = [] # Each request is stored based on the requester
func lock_view(request_source: Node, request_to_be_locked: bool = true) -> void:
	if request_to_be_locked and not lock_requests.has(request_source):
		lock_requests.push_back(request_source)
	if not request_to_be_locked: lock_requests.erase(request_source)
	_view_locked = not lock_requests.is_empty()

func _ready() -> void:
	if make_current_on_start: make_current()

func move_towards_object_by(distance: float, o: Node3D = looking_at) -> void:
	if not o: return
	global_position += (o.global_position - global_position).normalized() * distance

var _view_locked: bool = false
func _rotate_camera_by(offset: Vector2) -> void:
	if not _view_locked: super(offset)

var looking_at: Node3D
func _physics_process(_delta: float) -> void:
	if not cursor: return
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var mouse_screen_position: Vector2 = get_viewport().get_mouse_position()
	var origin_global_pos: Vector3 = camera.project_ray_origin(mouse_screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_screen_position)
	var raycast_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin_global_pos, origin_global_pos + ray_direction * 500000.
	)
	var exclude_rids: Array[RID] = []
	for tool in get_tree().get_nodes_in_group("RoadworkTool"):
		exclude_rids.push_back(tool.get_rid())
	raycast_query.exclude = exclude_rids
	var raycast_result: Dictionary = space_state.intersect_ray(raycast_query)
	if "position" in raycast_result:
		if not raycast_result.collider is RoadChunkBody: looking_at = raycast_result.collider
		else: looking_at = raycast_result.collider.get_road_chunk()
		cursor.global_position = raycast_result.position
		# this check avoids a godot warning message about colinear vectors
		if cursor.global_position.direction_to(raycast_result.position + raycast_result.normal).is_equal_approx(Vector3.UP):
			cursor.look_at(cursor.position + Vector3.FORWARD) ## was originally cursor.look_at(cursor.position + Vector3.UP) if that was important?? couldn't find any behavior that *depended* on this
		else:
			cursor.look_at(raycast_result.position + raycast_result.normal)
	else: looking_at = null
