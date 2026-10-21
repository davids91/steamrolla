class_name Music extends Node

## Thoughts:
## With a manager there's no need to have individual audio players for each track,
## we can swap out the music resource at runtime, as long as we don't need them to overlap.
## Saving memory.  Otherwise a simple system can be made for that feature.
## 
## For now we only have one track so I'm not bothering with the boilerplate for that, TODO
## feel free to make this as complex or simple as needed.

enum Track {
	MAIN_MENU_MUSIC_LOOP,
}

@onready var steam_rolla_main_menu_music_loop: AudioStreamPlayer = $SteamRollaMainMenuMusicLoop

static var instance: Music
static func get_instance() -> Music:
	assert(instance)
	return instance

func _enter_tree() -> void:
	assert(instance == null)
	instance = self

func _ready() -> void:
	for child in get_players():
		child.set_meta(VOL_META, child.volume_linear)

func _exit_tree() -> void:
	if instance == self:
		instance = null
		



static var tweens: Dictionary[AudioStreamPlayer, Tween]
static func start_music(track: Track, fade_in_duration: float = 2.0) -> void:
	var player: AudioStreamPlayer
	match track:
		Track.MAIN_MENU_MUSIC_LOOP:
			player = get_instance().steam_rolla_main_menu_music_loop
		_:
			push_error("Invalid track provided to Music.start_music().")
			return
	
	var was_fading: bool = false
	if player.playing:
		if check_tweens_for(player):
			was_fading = true
			tweens[player].kill()
		else:
			push_warning("Music is already playing, ignoring...")
			return
	
	if fade_in_duration > 0.05:
		if not was_fading:
			player.volume_linear = 0.0
		var fade := player.create_tween();  fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) ## not affected by pause
		fade.tween_property(player, ^"volume_linear", get_set_volume(player), fade_in_duration)
		fade.parallel()
		if not player.playing:
			fade.tween_callback(player.play)
		tweens[player] = fade
		
	else:
		player.volume_linear = get_set_volume(player)
		player.play()


static func stop_music(fade_out_duration: float = 5.0) -> void:
	if fade_out_duration < 0.05:
		for player: AudioStreamPlayer in get_players():
			player.stop()
	
	else:
		for player: AudioStreamPlayer in get_players():
			if check_tweens_for(player):
				tweens[player].kill()
			
			var fade := player.create_tween();  fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) ## not affected by pause
			fade.tween_property(player, ^"volume_linear", 0.0, fade_out_duration)
			fade.tween_callback(player.stop)
			
			tweens[player] = fade


static func get_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for ch in get_instance().get_children():
		if ch is AudioStreamPlayer:
			players.append(ch)
	return players

const VOL_META: StringName = "setvol"
static func get_set_volume(player: AudioStreamPlayer) -> float:
	return player.get_meta(VOL_META, 1.0)


static func check_tweens_for(player: AudioStreamPlayer) -> bool:
	if player in tweens.keys():
		if tweens[player].is_running():
			return true
		else:
			tweens.erase(player)
	return false
