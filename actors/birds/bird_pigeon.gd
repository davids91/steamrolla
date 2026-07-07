extends ABird
class_name Pigeon


func _on_caution_entered(body: Node3D):
	if body.is_in_group(BIRD_REACTABLE_GROUP_NAME):
		print("On caution entered activation")
		if not is_instance_valid(_active_threat):
			_active_threat = body
			_look_at_active_threat()
			var brain_delay = randf_range(bird_data.min_brain_delay, bird_data.min_brain_delay)
			if _away == Vector3.ZERO:
				_away = (global_position - _active_threat.global_position)
				_away.y = 0
				_away = _away.normalized()
			print(body, "has entered")
			await get_tree().create_timer(brain_delay).timeout
		

func _on_caution_exited(body: Node3D):
	if body == _active_threat:
		print("On caution exited activation")
		_active_threat = null
		if current_state != State.FLYING:
			change_state(State.ONGROUND)


func _on_flyaway_entered(body: Node3D):
	if body == _active_threat:
		print("On flyaway activation")
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
			velocity = Vector3.ZERO
		State.RUNNING:
			_process_evade()
		State.FLYING:
			_process_fly()

func _process_evade():
	if not is_instance_valid(_active_threat):
		change_state(State.ONGROUND)
		return
	_look_away_from_active_threat()
	
	velocity = _away * bird_data.run_speed
	if _active_threat and global_position.distance_squared_to(_active_threat.global_position) > \
						bird_data.tolerable_distance_for_threat + 5.0:
		change_state(State.ONGROUND)
		_look_at_active_threat()
			
func _process_fly():
	if is_instance_valid(_active_threat):
		_fly_direction = (global_position - _active_threat.global_position).normalized()
		_fly_direction.y = 1.0 
		_fly_direction = _fly_direction.normalized()
	elif _fly_direction == Vector3.ZERO:
		_fly_direction = Vector3.UP
		
	var target_pos = global_position + _fly_direction
	if global_position.distance_squared_to(target_pos) > 0.01:
		var look_transform = global_transform.looking_at(target_pos, Vector3.UP)
		_to_rotate_to = look_transform.basis.get_rotation_quaternion()
	
	velocity = _fly_direction * (bird_data.fly_speed)


func _look_at_active_threat():
	if not is_instance_valid(_active_threat):
		printerr("No Active Threat")
		return
	print("Looking at active threat")
	var target_pos = _active_threat.global_position
	if global_position.distance_squared_to(target_pos) > 0.01:
		var look_transform = global_transform.looking_at(target_pos, Vector3.UP)
		var brain_delay = randf_range(bird_data.min_brain_delay, bird_data.min_brain_delay)
		await get_tree().create_timer(brain_delay).timeout
		_to_rotate_to = look_transform.basis.get_rotation_quaternion()
		
func _look_away_from_active_threat():
	if not is_instance_valid(_active_threat):
		printerr("No Active Threat")
		return
	print("Looking away from active threat")
	_away = (global_position - _active_threat.global_position)
	_away.y = 0
	_away = _away.normalized() 
	var target_pos = global_position + _away 
	if global_position.distance_squared_to(target_pos) > 0.01:
		var look_transform = global_transform.looking_at(target_pos, Vector3.UP)
		var brain_delay = randf_range(bird_data.min_brain_delay, bird_data.min_brain_delay)
		await get_tree().create_timer(brain_delay).timeout
		_to_rotate_to = look_transform.basis.get_rotation_quaternion()
