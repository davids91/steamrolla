extends RoadworkTool

@export var camera_transition_duration_sec: float = 0.15

func set_color(color: Color) -> void:
	create_tween().tween_property($SpinnyPart/Bloke/metarig/Skeleton3D/bloke.get_active_material(0), "albedo_color", color, 0.5)
	create_tween().tween_property($SpinnyPart/Bloke/metarig/Skeleton3D/hat.get_active_material(0), "albedo_color", color, 0.5)
	create_tween().tween_property($SpinnyPart/compactor/Cube_001.get_active_material(0), "albedo_color", color, 0.5)

@export var start_velo: float = 4.45
func start_working() -> void:
	super()
	velocity = Vector3.ZERO
	create_tween().tween_method( # delayed gradual buildup of momentum
		func(_w: float):
			velocity += basis.z * start_velo * (Performance.get_monitor(Performance.TIME_PROCESS) / 0.15),
		0., 1., 0.15
	).set_delay(0.15)

func prepare_for_runway() -> void:
	$SpinnyPart.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	previous_velocity = Vector3.ZERO
	$ToolBubbleIndicator.visible = false

@export var velo_epsilon: float = 0.1
@export var throttle_strength: float = 3.
@export var minimum_velo_length: float = 5.0
@export var max_velocity_length_for_jitter: float = 5.05
@export var velo_controllability: float = 20.
@export var gravity: Vector3 = Vector3(0., -0.15, 0.)
@export var momentum_impact_effect: float = 0.5
@export var spinning_amount: float = 30.5
@export_range(0., 1.) var turning_responsiveness: float = 0.4
@onready var previous_velocity: Vector3 = Vector3.ZERO
@onready var original_tool_strength = tool_strength
func handle_movement(delta: float) -> void:
	if not is_working:
		$Sound.stop()
		if $FloorRaycast.get_collider(): global_position.y = $FloorRaycast.get_collision_point().y
		return
	if not $Sound.playing: $Sound.play()

	# Add gravity while in the air, and jump to obstacle above tool
	if $FloorRaycast.get_collider() and $FloorRaycast.get_collider().get_parent() is RoadChunk:
		if $FloorRaycast.get_collision_point().y < global_position.y:
			velocity += gravity
			tool_strength = max(0., tool_strength - delta * 10.)
		else: tool_strength = lerp(tool_strength, original_tool_strength, 0.9)
		global_position.y = max(global_position.y, $FloorRaycast.get_collision_point().y)
		$SpinnyPart.look_at(basis.x.cross($FloorRaycast.get_collision_normal()))

	# Handle player controls
	var velo_length: float = velocity.length()
	var controllable_component: float = clampf(velo_controllability / max(velo_length, 0.0001), 0., 1.)
	var next_point_based_on_velocity: Vector3 = velocity - Vector3(0., velocity.y - 0.5, 0.)
	velocity += velocity.normalized() * -movement_intent.y * controllable_component * throttle_strength
	if abs(movement_intent.x) > steering_epsilon:
		velocity += basis.x * -movement_intent.x * steering_angle * controllable_component
	if velo_length > velo_epsilon: look_at(global_position - next_point_based_on_velocity + Vector3(0., 1., 0.))

	# Set vibration amount based on speed
	vibration_extent = (
		vibration_extent_min
		+ vibration_extent_max_delta * smoothstep(0., max_velocity_length_for_jitter, velocity.length())
	)

	# Handle forward collisions
	$ForwardRayCast.target_position = next_point_based_on_velocity
	if $ForwardRayCast.get_collider():
		var col_normal: Vector3 = $ForwardRayCast.get_collision_normal()
		if not is_zero_approx(col_normal.length()):
			var impacted_momentum: Vector3 = basis.z.reflect(col_normal).normalized()
			impacted_momentum = Vector3(impacted_momentum.x, 0., impacted_momentum.z) * momentum_impact_effect
			velocity = lerp(velocity, impacted_momentum, momentum_impact_effect)
	if velocity.length() > minimum_velo_length:
		velocity -= velocity.normalized() * momentum_dampening * delta

	# Rotate the spinny part
	$SpinnyPart.rotate(basis.y, (velocity - previous_velocity).length() * spinning_amount * delta)

	# Set velocity and save previous velo
	if velocity.length() < minimum_velo_length: velocity = velocity.normalized() * minimum_velo_length
	previous_velocity = velocity

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
