extends Camera3D

@export var move_speed_factor: float = 5.0
@export var mouse_sensitivity: float = 0.005

var is_rotating: bool = false

func _process(delta: float) -> void:
	var horizonal_move_dir = Input.get_axis("move_left", "move_right")
	var veritcal_move_dir = Input.get_axis("move_backwards", "move_forward")
	
	match horizonal_move_dir:
		# when rotating horizontal becomes the z axis so updating the x pos has no effect?
		-1.0:
			position.x += -move_speed_factor * delta * transform.basis.x.x
		1.0:
			position.x += move_speed_factor * delta * transform.basis.x.x
			
	match veritcal_move_dir:
		-1.0:
			position.y += -move_speed_factor * delta * transform.basis.y.y
		1.0: 
			position.y += move_speed_factor * delta * transform.basis.y.y
		
	print(transform.basis)

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton
	and event.is_pressed()
	and event.button_index == MOUSE_BUTTON_LEFT):
		is_rotating = true
		
	if (event is InputEventMouseButton
	and event.is_released()
	and event.button_index == MOUSE_BUTTON_LEFT):
		is_rotating = false
		
	if event is InputEventMouseMotion and is_rotating:
		var offset: Vector2 = event.screen_relative * mouse_sensitivity
		_rotate_camera_by(offset)

func _rotate_camera_by(offset: Vector2) -> void:
	rotation.y -= offset.x
	rotation.x -= offset.y
	rotation.y = wrapf(rotation.y, -PI, PI)
