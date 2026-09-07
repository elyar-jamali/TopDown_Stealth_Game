# scripts/Main.gd
extends Node3D

@onready var level_holder: Node3D = $LevelHolder
var show_interactables := false

func _ready():
	OutlineSystem.register_renderers(
		$CameraRig/Camera3D,
		$ActiveOutlineViewport,
		$ActiveOutlineViewport/ActiveOutlineCamera,
		$UI/ActiveOutlineRect,
		$PassiveOutlineViewport,
		$PassiveOutlineViewport/PassiveOutlineCamera,
		$UI/PassiveOutlineRect
	)

	LocalizationManager.load_lang(GameManager.selected_language)

	if GameManager.current_level_path != "":
		load_level(GameManager.current_level_path)

func load_level(path: String):
	for child in level_holder.get_children():
		child.queue_free()

	var level_scene = load(path)
	var level = level_scene.instantiate()
	level_holder.add_child(level)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("show_interactables"):
		show_interactables = not show_interactables
		_update_interactable_outlines()

func _update_interactable_outlines() -> void:
	var root := get_tree().current_scene

	if root == null:
		return

	_update_interactable_recursive(root)


func _update_interactable_recursive(node: Node) -> void:
	if (
		"interactable" in node
		and "highlightable" in node
		and node.interactable
		and node.highlightable
	):
		var color := Color.YELLOW

		if "outline_color" in node:
			color = node.outline_color

		OutlineSystem.set_passive(
			node,
			&"tab",
			show_interactables,
			color
		)

	for child in node.get_children():
		_update_interactable_recursive(child)