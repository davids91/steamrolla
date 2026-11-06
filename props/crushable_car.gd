extends Crushable
@export var alarm_pitch_for_crush_progress: Curve
func _process(delta: float) -> void:
	super(delta)
	if scale.y < 1.:
		var crushed_ratio: float = 1. - ((scale.y - crushed_scale_threshold) / (1. - crushed_scale_threshold))
		if 0. < crushed_ratio and 1. >= crushed_ratio:
			$AlarmSound.pitch_scale = alarm_pitch_for_crush_progress.sample(crushed_ratio)
		if crushed_ratio >= 0.17 and crushed_ratio < 0.95:
			if not $AlarmSound.playing: $AlarmSound.play()
		elif not $AlarmSound.playing: $AlarmSound.play()
