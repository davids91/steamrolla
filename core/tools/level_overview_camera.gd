class_name OrbitCamera3D extends Node3D

@export var orbit_speed: float = 0.005
@export var zoom_speed: float = 0.5
@export var panning_speed: float = 0.01

@onready var _camera_3d: Camera3D = %Camera3D

func make_current() -> void: _camera_3d.make_current()
func get_current() -> bool: return _camera_3d.current
func get_view_origin() -> Vector3: return _camera_3d.global_position

@onready var camera_transform_before_transition: Transform3D = global_transform
var transition_tween: Tween:
	set(v):
		if transition_tween: transition_tween.kill()
		transition_tween = v

## Moves the current camera into the place of the given one before it makes it the current
func transition_to(other: OrbitCamera3D, transition_duration_sec: float = 1.) -> Tween:
	$TransitionSound.play()
	camera_transform_before_transition = global_transform
	transition_tween = create_tween()
	transition_tween.tween_property(_camera_3d, "global_transform", other._camera_3d.global_transform, transition_duration_sec)
	transition_tween.tween_callback(func():
		other.make_current()
		_camera_3d.global_transform = camera_transform_before_transition
	)
	return transition_tween

func _unhandled_input(event: InputEvent) -> void:
	if not get_current(): return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var offset: Vector2 = event.screen_relative * orbit_speed
		_rotate_camera_by(offset)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_3d.position.z += zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_3d.position.z -= zoom_speed
			
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var offset: Vector3 = Vector3(-event.relative.x * panning_speed, event.relative.y * panning_speed, 0)
		var local_offset_transform: Transform3D = Transform3D(Basis.IDENTITY, offset)
		set_transform(transform * local_offset_transform)
		
func _rotate_camera_by(offset: Vector2) -> void:
	rotation.y -= offset.x
	rotation.x -= offset.y
	rotation.y = wrapf(rotation.y, -PI, PI)
