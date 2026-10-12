extends Control

func show_rating(num): # num corresponds to the rating hand you want to show
	var hand = "Hand%d" % num
	var hand_node: Hand = get_node(hand)
	hand_node.appear()

func hide_rating(num):
	var hand = "Hand%d" % num
	var hand_node: Hand = get_node(hand)
	hand_node.disappear()
