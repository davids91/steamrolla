extends Control

@onready var anim = $AnimationPlayer

func show_rating(num): # num corresponds to the rating hand you want to show
	var animation = "hand_%d" % num
	anim.play(animation)

func hide_rating(num):
	var animation = "hand_%d" % num
	anim.play_backwards(animation)
