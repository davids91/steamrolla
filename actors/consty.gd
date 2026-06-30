extends Node3D

func is_being_smooshed() -> bool: return _is_being_smooshed or smoosh_tween != null

var original_transform: Transform3D = transform
var original_rotation: Vector3 = rotation
var _is_being_smooshed: bool = false
var smoosh_tween: Tween
func smoosh() -> void:
	if _is_being_smooshed: return
	if smoosh_tween: smoosh_tween.kill()
	_is_being_smooshed = true
	smoosh_tween = create_tween()
	original_transform = transform
	original_rotation = rotation
	smoosh_tween.tween_method(func(w: float):
		basis.z *= w
		rotation.x = lerp(rotation.x, -PI/2., w),
		1., 0.8, 0.15
	)
	smoosh_tween.tween_callback(func(): smoosh_tween = null)
	$SmooshSound.play()

func unsmoosh() -> void:
	if not is_being_smooshed(): return
	if smoosh_tween: smoosh_tween.kill()
	smoosh_tween = create_tween()
	smoosh_tween.tween_interval(1.)
	smoosh_tween.tween_callback(func(): $InflateSound.play())
	smoosh_tween.tween_method(func(w: float):
		basis.z = lerp(basis.z, original_transform.basis.z, w)
		rotation = lerp(rotation, original_rotation, w),
		0., 1., 1.5
	).set_ease(Tween.EASE_OUT)
	smoosh_tween.tween_callback(func(): 
		smoosh_tween = null
		_is_being_smooshed = false
	)
