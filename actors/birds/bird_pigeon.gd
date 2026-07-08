extends ABird
class_name Pigeon


func _on_caution_entered(body: Node3D):
	if body.is_in_group(BIRD_REACTABLE_GROUP_NAME):
		if debug: print("%s has entered and activated caution area of %s" %[body.name, name])
		if not is_instance_valid(_active_threat):
			_active_threat = body
			_look_at_active_threat()
			if debug: print("%s has entered" % body.name,)
			_is_loitering = false

		

func _on_caution_exited(body: Node3D):
	if body == _active_threat:
		if debug: print("%s has exited the caution area of %s" %[body.name, name])
		_active_threat = null
		if current_state != State.FLYING:
			change_state(State.ONGROUND)
	
	if not _is_loitering: _is_loitering = true


func _on_flyaway_entered(body: Node3D):
	if body == _active_threat:
		if debug: print("Because of %s. %s has activated flyaway " %[body.name, name])
		change_state(State.FLYING)
		


func _asses_threat():
	if not _active_threat: return
	if global_position.distance_squared_to(_active_threat.global_position) > bird_data.tolerable_distance_for_threat: return
	var threat_speed: float = _active_threat.velocity.length()
	if threat_speed < bird_data.tolerable_velocity:
		change_state(State.RUNNING)
	else:
		change_state(State.FLYING)
	
func _make_decision():
	match current_state:
		State.ONGROUND:
			_process_loiter()
		State.RUNNING:
			_process_evade()
		State.FLYING:
			_process_fly()

func _process_loiter():
	if not _is_loitering: _snap_to_ground(); return
	if debug: print("%s is Loitering" % name)
	_do_brain_delay()
	var ground = _snap_to_ground()
	var half_time = bird_data.loiter_slowness / 2.0
	var original_pos = global_position
	var tween = create_tween()
	if global_position.length() > _spawn_pos.length() + bird_data._loiter_max_dist:
		tween.tween_property(
		self,"position",original_pos, half_time) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
		return
	tween.tween_property(
		self,"position:y",ground.y + randf_range(
			bird_data.lotier_jump_height,
			bird_data.lotier_jump_height + randf_range(0, .5)), 
		half_time) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(
		self,"position:x",ground.x + randf_range(
			bird_data.lotier_jump_height,
			bird_data.lotier_jump_height + randf_range(-.7, .7)), 
		half_time) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
		
	tween.tween_property(
		self,"position:z",ground.z + randf_range(
			bird_data.lotier_jump_height,
			bird_data.lotier_jump_height + randf_range(-.7, .7)), 
		half_time) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	
	
	tween.tween_property(self,"position:y",original_pos.y, half_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	

	

func _process_evade():
	if not is_instance_valid(_active_threat):
		change_state(State.ONGROUND)
		return
	
	velocity = Vector3(bird_data.run_speed, 0,0)
	if _active_threat and global_position.distance_squared_to(_active_threat.global_position) > \
						bird_data.tolerable_distance_for_threat + 5.0:
		change_state(State.ONGROUND)
			
func _process_fly():
	
	if is_instance_valid(_active_threat):
		_fly_direction = (global_position - _active_threat.global_position).normalized()
		_fly_direction.y = 1.0 
		_fly_direction = _fly_direction.normalized()
	elif _fly_direction == Vector3.ZERO:
		_fly_direction = Vector3.UP
	velocity = _fly_direction * (bird_data.fly_speed)
	if debug: print("%s is flying; its velocity is: %v. its fly direction is: %v" % [name, 	velocity, _fly_direction])	
	await get_tree().create_timer(5).timeout
	free()

func _look_at_active_threat():
	if not is_instance_valid(_active_threat):
		printerr("No Active Threat")
		return
	if debug: print("Looking at active threat, which is %s" % _active_threat.name)
		
func _look_away_from_active_threat():
	if not is_instance_valid(_active_threat):
		printerr("No Active Threat")
		return
	if debug: print("Looking away from active threat, which is %s" % _active_threat.name)
	var target_pos = global_position + global_position - _active_threat.global_position 
	if global_position.distance_squared_to(target_pos) > 0.01:
		_do_brain_delay()
		look_at(-target_pos)


func _do_brain_delay():
	var brain_delay = randf_range(bird_data.min_brain_delay, bird_data.min_brain_delay)
	await get_tree().create_timer(brain_delay).timeout
