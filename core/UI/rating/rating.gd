extends Control

@export var current_rating = 3
func show_rating(num: int = current_rating) -> void: # num corresponds to the rating hand you want to show
	var hand = "Hand%d" % num
	var hand_node: Hand = get_node(hand)
	hand_node.appear()

func hide_rating(num: int = current_rating) -> void:
	var hand = "Hand%d" % num
	var hand_node: Hand = get_node(hand)
	hand_node.disappear()
