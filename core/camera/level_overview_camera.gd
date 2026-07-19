class_name OrbitCamera3D extends Node3D

@export var orbit_speed: float = 0.005
@export var zoom_speed: float = 0.5
@export var panning_speed: float = 0.01

@onready var _camera_3d: Camera3D = %Camera3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var offset: Vector2 = event.screen_relative * orbit_speed
		_rotate_camera_by(offset)
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_3d.position.z += zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_3d.position.z -= zoom_speed
			
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var offset := Vector3(-event.relative.x * panning_speed, event.relative.y * panning_speed, 0)
		var local_offset_transform = Transform3D(Basis.IDENTITY, offset)
		set_transform(transform * local_offset_transform)
		
func _rotate_camera_by(offset: Vector2) -> void:
	rotation.y -= offset.x
	rotation.x -= offset.y
	rotation.y = wrapf(rotation.y, -PI, PI)
