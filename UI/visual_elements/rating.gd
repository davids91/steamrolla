@tool
extends Control

@export var current_rating = 3
@export_tool_button("Display Rating", "Verified") var show_rating_button: Callable = show_rating
@export_tool_button("Reset rating", "StatusError") var reset_rating_button: Callable = hide_rating

@export var delay_sec: float = 0.1
@export var delay_randomness_ratio: float = 0.1
var display_tween: Tween:
	set(v):
		if display_tween: display_tween.kill()
		display_tween = v
func show_rating(rating: int = current_rating) -> void:
	current_rating = rating
	display_tween = create_tween()
	for i in current_rating:
		display_tween.tween_callback(show_hand.bind(i)).set_delay(
			delay_sec + delay_sec * randf() * delay_randomness_ratio
		)

func hide_rating() -> void:
	for i in range(get_child_count()): hide_hand(i)

func show_hand(num: int) -> void: # num corresponds to the rating hand you want to show
	var hand = "Hand%d" % num
	var hand_node: Hand = get_node(hand)
	hand_node.appear()

func hide_hand(num: int) -> void:
	var hand = "Hand%d" % num
	var hand_node: Hand = get_node(hand)
	hand_node.disappear()
