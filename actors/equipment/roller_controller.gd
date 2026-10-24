class_name RollerController
extends RoadworkTool

@export var color_responsiveness: float = 0.075
var target_color: Color = default_color
var current_color: Color = default_color

@onready var skin: MeshInstance3D = $roller/Roller
func set_color(color: Color) -> void:
	target_color = color

func start_working() -> void:
	if get_node_or_null("KeyPrompt"): $KeyPrompt.is_enabled = true
	$ToolBubbleIndicator.visible = false
	super()

func stop_working() -> void:
	if get_node_or_null("KeyPrompt"): $KeyPrompt.is_enabled = false
	$ToolBubbleIndicator.visible = true
	$SqueezeSound.stop()
	super()

func handle_movement(delta: float) -> void:
	super(delta)
	velocity = velocity.limit_length(speed)

func prepare_for_runway() -> void:
	$ToolBubbleIndicator.visible = false

var is_on_asphalt: bool = false
var was_on_asphalt: bool = is_on_asphalt
var connected_chunk: RoadChunk
func _on_asphalt_detector_body_entered(body: Node3D) -> void:
	if not connected_chunk or body is RoadChunkBody:
		connected_chunk = body.get_parent() as RoadChunk

func _on_asphalt_detector_body_exited(body: Node3D) -> void:
	if body == connected_chunk: connected_chunk = null

@export var transparency_while_moving: float = 0.025
var moving_transparency_modifier: float = 0.
func _process(delta: float) -> void:
	super(delta)
	if not $OrbitCamera.get_current(): return
	var movement_direction: Vector3 = (basis.z * -movement_intent.y).normalized()
	var camera_direction: Vector3 = ($OrbitCamera.get_view_origin() - global_position)
	if 0. > movement_direction.dot(camera_direction): moving_transparency_modifier = -(1. - transparency_while_moving)
	else: moving_transparency_modifier = 0.
	current_color = lerp(
		current_color, Color(target_color.r, target_color.g, target_color.b, target_color.a + moving_transparency_modifier),
		color_responsiveness
	)
	skin.get_active_material(0).albedo_color = current_color

@export var forward_collision_dampening: float = 0.95
func _physics_process(delta: float) -> void:
	super(delta)
	(func(): # Handle asphalt detection
		if connected_chunk:
			var asphalt_quantity: float = await connected_chunk.get_asphalt_quantity_at(global_position)
			is_on_asphalt = 0. < asphalt_quantity
			if(
				is_reversing != (direction.z > 0.0) or is_moving != (direction.z != 0.0)
				or was_on_asphalt != is_on_asphalt
			):
				var sound_should_be_playing: bool = (direction.z != 0.0) and is_on_asphalt
				if sound_should_be_playing: # Play from a random time within the length of the audio stream if not already playing
					if not $SqueezeSound.playing: $SqueezeSound.play(randf() * 1.89)
				else: $SqueezeSound.stop()
			was_on_asphalt = is_on_asphalt
	).call_deferred()

	# Stick to the ground
	if is_working and $FloorRaycast.get_collision_point():
		global_position.y = $FloorRaycast.get_collision_point().y

	# Slow down roller when there's anything in front
	if is_working and $ForwardShapeCast.is_colliding() and not is_reversing:
		velocity = velocity.limit_length(velocity.length() * forward_collision_dampening)

func _on_body_representation_area_entered(area: Area3D) -> void:
	if area.name == "PlayerCursorBody" and area.get_parent().visible and not is_working:
		$ToolBubbleIndicator.show_tooltip(true)

func _on_body_representation_area_exited(area: Area3D) -> void:
	if area.name == "PlayerCursorBody" and area.get_parent().visible:
		$ToolBubbleIndicator.show_tooltip(false)
