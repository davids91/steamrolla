extends RoadworkTool

@export var payload_type: RoadChunk.DynamicSurfaces = RoadChunk.DynamicSurfaces.GRAVEL:
	set(v):
		payload_type = v
		if get_node_or_null("%GravelPile"):
			var pile_material: Material = %GravelPile.get_active_material(0)
			match v:
				RoadChunk.DynamicSurfaces.ASPHALT:
					pile_material.set_shader_parameter("asphalt_texture", load("res://textures/asphalt_tile_seamless.png"))
					pile_material.set_shader_parameter("asphalt_normal", load("res://textures/asphalt_tile_seamless_normal.png"))
				RoadChunk.DynamicSurfaces.GRAVEL:
					pile_material.set_shader_parameter("asphalt_texture", load("res://textures/gravel-seamless.png"))
					pile_material.set_shader_parameter("asphalt_normal", load("res://textures/gravel-seamless-normal.png"))
				RoadChunk.DynamicSurfaces.DIRT:
					pile_material.set_shader_parameter("asphalt_texture", load("res://textures/dirt-seamless.png"))
					pile_material.set_shader_parameter("asphalt_normal", load("res://textures/dirt-seamless-normal.png"))
				_:
					pile_material.set_shader_parameter("asphalt_texture", load("res://textures/gravel-seamless.png"))
					pile_material.set_shader_parameter("asphalt_normal", load("res://textures/gravel-seamless-normal.png"))

@export var asphalt_height_for_quantity: float = 2.
@export var asphalt_capacity: float = 1.
@export var asphalt_usage_per_sec: float = 1.
@onready var asphalt_remaining: float = asphalt_capacity:
	set(v):
		asphalt_remaining = v
		%GravelPile.get_active_material(0).set_shader_parameter("asphalt_pile_size", v * asphalt_height_for_quantity)

func prepare_for_runway() -> void:
	asphalt_remaining = asphalt_capacity
	$ToolBubbleIndicator.visible = false

func start_working() -> void:
	if get_node_or_null("KeyPrompt"): $KeyPrompt.is_enabled = true
	if get_node_or_null("KeyPromptPayload"): $KeyPromptPayload.is_enabled = true
	$ToolBubbleIndicator.visible = false
	super()

func stop_working() -> void:
	if get_node_or_null("KeyPrompt"): $KeyPrompt.is_enabled = false
	if get_node_or_null("KeyPromptPayload"): $KeyPromptPayload.is_enabled = false
	#$ActiveSound.stop()
	$ToolBubbleIndicator.visible = true
	super()

func handle_movement(delta: float) -> void:
	super(delta)
	velocity = velocity.limit_length(speed)

var is_pouring: bool = false
func _process(delta: float) -> void:
	super(delta)
	if 0. >= asphalt_remaining: payload_triggered = false
	$SmokeParticles.emitting = is_working and payload_triggered
	if is_working and payload_triggered:
		if not is_pouring:
			is_pouring = true
			$Truck/AnimationPlayer.play("Cube_039|Cube_039Action")
			#$ActiveSound.play()
		asphalt_remaining = max(0., asphalt_remaining - asphalt_usage_per_sec * delta)
	else:
		if is_pouring:
			$Truck/AnimationPlayer.play_backwards("Cube_039|Cube_039Action")
			is_pouring = false
		#$ActiveSound.stop()

@export var forward_collision_dampening: float = 0.95
@onready var original_speed: float = speed
func _physics_process(delta: float) -> void:
	super(delta)
	if Input.is_action_pressed("deploy_payload"): speed = original_speed / 2.
	else: speed = original_speed

	# Stick to the ground
	if is_working:
		var floor_raycast_point: Vector3
		if $FloorShapecastBack.is_colliding(): floor_raycast_point = $FloorShapecastBack.get_collision_point(0)
		if(
			$FloorShapecastFront.is_colliding()
			and (
				null == floor_raycast_point
				or $FloorShapecastFront.get_collision_point(0).y > floor_raycast_point.y
			)
		): floor_raycast_point = $FloorShapecastFront.get_collision_point(0)
		if floor_raycast_point != null:
			global_position.y = lerp(global_position.y, floor_raycast_point.y, inv_turn_responsiveness)
