extends RoadworkTool

@export var camera_transition_duration_sec: float = 0.15

func set_color(color: Color) -> void:
	create_tween().tween_property($SpinnyPart/Bloke/metarig/Skeleton3D/bloke.get_active_material(0), "albedo_color", color, 0.5)
	create_tween().tween_property($SpinnyPart/Bloke/metarig/Skeleton3D/hat.get_active_material(0), "albedo_color", color, 0.5)
	create_tween().tween_property($SpinnyPart/compactor/Cube_001.get_active_material(0), "albedo_color", color, 0.5)

@export var start_momentum_length: float = 1.45
func start_working() -> void:
	super()
	momentum = Vector3.ZERO
	create_tween().tween_method( # delayed gradual buildup of momentum
		func(_w: float): momentum += (
			basis.z * start_momentum_length
			* (Performance.get_monitor(Performance.TIME_PROCESS) / 0.15)
		),
		0., 1., 0.15
	).set_delay(0.15)

func prepare_for_runway() -> void:
	velocity = Vector3.ZERO
	momentum = Vector3.ZERO
	$ToolBubbleIndicator.visible = false

@export var minimum_momentum_length: float = 0.55
@export var max_momentum_length_for_jitter: float = 5.05
@export var momentum_controllability: float = 0.45
@export var momentum_control_strength: Vector2 = Vector2(0.01, 0.5)
@export var momentum_gravity: Vector3 = Vector3(0., -0.015, 0.)
@export var momentum_impact_effect: float = 0.5
@export var spinning_amount: float = 30.5
var previous_momentum: Vector3
var momentum: Vector3 = Vector3.ZERO
func handle_movement(delta: float) -> void:
	if not is_working:
		$Sound.stop()
		if $FloorRaycast.get_collider(): global_position.y = $FloorRaycast.get_collision_point().y
		return
	if not $Sound.playing: $Sound.play()

	# Add gravity while in the air, and jump to obstacle above tool
	if $FloorRaycast.get_collider():
		if $FloorRaycast.get_collision_point().y < global_position.y:
			momentum += momentum_gravity
		global_position.y = max(global_position.y, $FloorRaycast.get_collision_point().y)
		$SpinnyPart.look_at(basis.x.cross($FloorRaycast.get_collision_normal()))

	# Handle forward collisions
	var next_point_based_on_momentum: Vector3 = ((momentum - Vector3(0.,momentum.y,0.)).normalized() + Vector3(0., 0.5, 0.)) * 2.
	$ForwardRayCast.target_position = next_point_based_on_momentum
	if $ForwardRayCast.get_collider():
		var col_normal: Vector3 = $ForwardRayCast.get_collision_normal()
		if not is_zero_approx(col_normal.length()):
			var impacted_momentum: Vector3 = basis.z.reflect(col_normal).normalized()
			impacted_momentum = Vector3(impacted_momentum.x, 0., impacted_momentum.z) * momentum_impact_effect
			momentum = lerp(momentum, impacted_momentum, momentum_impact_effect)
	if momentum.length() > minimum_momentum_length:
		momentum.x -= momentum.normalized().x * momentum_dampening * delta
		momentum.z -= momentum.normalized().z * momentum_dampening * delta

	# Handle player controls
	var momentum_control_component: float = clampf(momentum_controllability / max(momentum.length(), 0.0001), 0., 1.)
	momentum += momentum.normalized() * -movement_intent.y * momentum_control_strength.y * momentum_control_component
	if momentum == Vector3.ZERO: momentum = previous_momentum
	if(abs(movement_intent.x) > steering_epsilon):
		momentum += basis.x * -movement_intent.x * momentum_control_strength.x * momentum_control_component
		look_at(global_position - next_point_based_on_momentum + Vector3(0., 1., 0.))

	# Set vibration amount based on momentum length
	vibration_extent = (
		vibration_extent_min
		+ (
			vibration_extent_max_delta
			* smoothstep(minimum_momentum_length, max_momentum_length_for_jitter, momentum.length())
		)
	)

	# Rotate the spinny part
	$SpinnyPart.rotate(basis.y, (momentum - previous_momentum).length() * spinning_amount * delta)

	# Set velocity and save previous momentum
	velocity += speed * momentum * delta
	previous_momentum = momentum

func _ready() -> void:
	$SpinnyPart/Bloke/AnimationPlayer.current_animation = "default"

@export var vibration_speed: float = 100.
@export var vibration_extent_min: float = 0.3
@export var vibration_extent_max_delta: float = 0.65 # The amount the extent can go up from @vibration_extent_min
@export var handle_angle_delta_extent: float = 10.
@export_range(0., 1.) var handle_volatility: float = 0.3
@export_range(0., 1.) var handle_positional_strength: float = 0.05

@onready var skidplate_bone_id: int = %Compactor/rig/Skeleton3D.find_bone("Skidplate")
var vibration_extent: float = 0.1
var elapsed_time = 0.
func _process(delta: float) -> void:
	super(delta)
	elapsed_time += delta
	var vibration_y_delta: float = sin(elapsed_time * vibration_speed) * vibration_extent
	%Compactor.position += %Compactor.basis.y * vibration_y_delta * 0.3
	var bone_position: Vector3 = %Compactor/rig/Skeleton3D.get_bone_pose_position(skidplate_bone_id)
	bone_position += %Compactor.basis.y * vibration_y_delta * 0.7
	%Compactor/rig/Skeleton3D.set_bone_pose_position(skidplate_bone_id, bone_position)
	%Bloke.position += %Bloke.basis.y * vibration_y_delta

@onready var handle_bone_id: int = %Compactor/rig/Skeleton3D.find_bone("Handle")
@onready var handle_start_angle_y: float = %Compactor/rig/Skeleton3D.get_bone_pose_rotation(handle_bone_id).y
func _physics_process(delta: float) -> void:
	super(delta)
	var current_quaternion: Quaternion = %Compactor/rig/Skeleton3D.get_bone_pose_rotation(handle_bone_id)
	current_quaternion.y = lerp( #TechDebt: angles 1. and 5. are magic numbers based on visual feedback and vibes
		current_quaternion.y,
		clamp(
			current_quaternion.y + (previous_position.y - global_position.y) * handle_angle_delta_extent,
			1., 5.
		),
		handle_volatility
	)
	current_quaternion.y = lerp(current_quaternion.y, handle_start_angle_y, handle_positional_strength)
	%Compactor/rig/Skeleton3D.set_bone_pose_rotation(handle_bone_id, current_quaternion)

func _on_body_representation_area_entered(area: Area3D) -> void:
	if area.name == "PlayerCursorBody" and area.get_parent().visible and not is_working:
		$ToolBubbleIndicator.show_tooltip(true)

func _on_body_representation_area_exited(area: Area3D) -> void:
	if area.name == "PlayerCursorBody" and area.get_parent().visible:
		$ToolBubbleIndicator.show_tooltip(false)
