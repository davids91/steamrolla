extends RoadworkTool

@export var camera_transition_duration_sec: float = 0.15

#region Common Interface For Roadwork Tools
func set_color(color: Color) -> void:
	create_tween().tween_property($Bloke/metarig/Skeleton3D/bloke.get_active_material(0), "albedo_color", color, 0.5)
	create_tween().tween_property($Bloke/metarig/Skeleton3D/hat.get_active_material(0), "albedo_color", color, 0.5)
	create_tween().tween_property($compactor/Cube_001.get_active_material(0), "albedo_color", color, 0.5)

func set_angle_from_prev_pos(prev_pos: Vector3) -> void:
	look_at(prev_pos - global_position)

@export var start_momentum_length: float = 1.45
func start_working() -> void:
	super()
	momentum = Vector3.ZERO
	create_tween().tween_method( # delayed gradual buildup of momentum
		func(_w: float): momentum += basis.z * start_momentum_length * (Performance.get_monitor(Performance.TIME_PROCESS) / 0.15),
		0., 1., 0.15
	).set_delay(0.15)

func stop_working() -> void:
	super()
	$Sound.stop()

func work_at_cursor(target_position: Vector3) -> void:
	super(target_position)
	$Sound.play()

@export var minimum_momentum_length: float = 1.05
@export var momentum_controllability: float = 0.45
@export var momentum_control_strength: Vector2 = Vector2(0.25, 0.5)
@export var momentum_dampening: float = 1.25
@export var momentum_gravity: Vector3 = Vector3(0., -0.015, 0.)
@export var momentum_impact_effect: float = 0.5
@export var spinning_amount: float = 30.5
var previous_momentum: Vector3
var momentum: Vector3 = Vector3.ZERO
func handle_movement(delta: float) -> void:
	if not is_working:
		if $FloorRaycast.get_collider(): global_position.y = $FloorRaycast.get_collision_point().y
		return
	previous_momentum = momentum
	global_position += speed * momentum * delta

	if $FloorRaycast.get_collider():
		if $FloorRaycast.get_collision_point().y < global_position.y:
			momentum += momentum_gravity
		global_position.y = max(global_position.y, $FloorRaycast.get_collision_point().y)

	var next_point_based_on_momentum: Vector3 = ((momentum - Vector3(0.,momentum.y,0.)).normalized() + Vector3(0., 0.5, 0.)) * 2.
	$ForwardRayCast.target_position = next_point_based_on_momentum
	if $ForwardRayCast.get_collider():
		var impacted_momentum: Vector3 = basis.z.reflect($ForwardRayCast.get_collision_normal()).normalized()
		impacted_momentum = Vector3(impacted_momentum.x, 0., impacted_momentum.z) * momentum_impact_effect
		momentum = lerp(momentum, impacted_momentum, momentum_impact_effect)
	if momentum.length() > minimum_momentum_length:
		momentum.x -= momentum.normalized().x * momentum_dampening * delta
		momentum.z -= momentum.normalized().z * momentum_dampening * delta

	# Handle player controls
	var momentum_control_component: float = clampf(momentum_controllability / max(momentum.length(), 0.0001), 0., 1.)
	if momentum == Vector3.ZERO: momentum = previous_momentum

	momentum += momentum.normalized() * -movement_intent.y * momentum_control_strength.y * momentum_control_component
	if(abs(movement_intent.x) > steering_epsilon):
		momentum += basis.x * -movement_intent.x * momentum_control_strength.x * momentum_control_component
		look_at(global_position - next_point_based_on_momentum + Vector3(0., 1., 0.))

func handle_turning(delta: float) -> void:
	$SpinnyPart.rotate(basis.y, (momentum - previous_momentum).length() * spinning_amount * delta)

#endregion Common Interface For Roadwork Tools

func _ready() -> void:
	$SpinnyPart/Bloke/AnimationPlayer.current_animation = "default"

@export var vibration_speed: float = 100.
@export var vibration_extent: float = 0.1
var elapsed_time = 0.
func _process(delta: float) -> void:
	elapsed_time += delta
	$SpinnyPart/compactor.position += $SpinnyPart/compactor.basis.y * sin(elapsed_time * vibration_speed) * vibration_extent
	$SpinnyPart/Bloke.position += $SpinnyPart/Bloke.basis.y * sin(elapsed_time * vibration_speed) * vibration_extent

func _on_body_representation_area_entered(area: Area3D) -> void:
	if area.name == "PlayerCursorBody" and area.get_parent().visible and not is_working:
		$ToolBubbleIndicator.show_tooltip(true)

func _on_body_representation_area_exited(area: Area3D) -> void:
	if area.name == "PlayerCursorBody" and area.get_parent().visible:
		$ToolBubbleIndicator.show_tooltip(false)
