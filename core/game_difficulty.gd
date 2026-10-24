class_name GameDifficulty
extends Node

@export var completion_to_rating: Curve

static var _instance: GameDifficulty = null
static var instance: GameDifficulty:
	get: return _instance

func _enter_tree() -> void:
	if instance == null:
		_instance = self

func _exit_tree() -> void:
	if instance == self:
		_instance = null
