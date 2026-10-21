class_name SceneManager extends Node

const SCENE_TITLE_SCREEN: String = "res://core/scenes/menus/title_screen.tscn"
const SCENE_LEVEL_SELECT: String = "res://core/scenes/menus/level_select.tscn"

var instanced_root: Node
var is_scene_changing: bool


static var instance
func _enter_tree() -> void:
	assert(instance == null, "Unmanaged scene change (get_tree().change_scene -- use SceneManager methods)")
	instance = self

func _exit_tree() -> void:
	if instance == self: instance = null

func _ready() -> void:
	## Here is the place to add anything before the title screen (precompiler, splash, etc)
	## Boot to the title screen
	_change_scene_to_file(SCENE_TITLE_SCREEN)



static func get_instance() -> SceneManager:
	assert(instance, "SceneManager isn't in the scene.")
	return instance

## Returns the root node of the currently loaded scene.
## Optionally print the scene tree to the console.
static func get_scene_root(print_tree_to_terminal: bool = false) -> Node:
	var container: Node = get_instance()
	if print_tree_to_terminal and OS.is_debug_build():
		container.print_tree_pretty()
	if container.instanced_root:
		return container.instanced_root
	else:
		return null



## Changes the running scene to the one at the given path, after loading it into a PackedScene and creating a new instance.
static func change_scene_to_file(path: String) -> void:
	get_instance()._change_scene_to_file(path)

## Changes the running scene to a new instance of [param packed_scene].
static func change_scene_to_packed(packed_scene: PackedScene) -> void:
	get_instance()._change_scene_to_packed(packed_scene)

## Changes the running scene to the provided node instance by first unloading the current scene, then adding the new scene as a child.
static func change_scene_to_node(scene: Node) -> void:
	get_instance()._change_scene_to_node(scene)


static func return_to_level_select(coming_from: String) -> void:
	var level_select_scene: LevelSelectScene = load(SCENE_LEVEL_SELECT).instantiate()
	level_select_scene.coming_from = coming_from
	get_instance()._change_scene_to_node(level_select_scene)

static func return_to_title_screen() -> void: change_scene_to_file(SCENE_TITLE_SCREEN)


func _change_scene_to_file(path: String): _change_scene_to_packed(load(path))
func _change_scene_to_packed(packed_scene: PackedScene) -> void:
	assert(packed_scene.can_instantiate())
	var scene: Node = packed_scene.instantiate()
	_change_scene_to_node(scene)

func _change_scene_to_node(scene: Node) -> void:
	assert(not is_scene_changing, "Multiple calls to change scene. (currently changing scene...)")
	is_scene_changing = true
	await _unload()
	add_child(scene)
	instanced_root = scene
	is_scene_changing = false

func _unload() -> void:
	if instanced_root:
		instanced_root.queue_free()
		await instanced_root.tree_exited
		instanced_root = null
