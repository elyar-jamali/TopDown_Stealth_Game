# scripts/Main.gd
extends Node3D

@onready var level_holder: Node3D = $LevelHolder

func _ready():
	LocalizationManager.load_lang(GameManager.selected_language)

	if GameManager.current_level_path != "":
		load_level(GameManager.current_level_path)

func load_level(path: String):
	for child in level_holder.get_children():
		child.queue_free()

	var level_scene = load(path)
	var level = level_scene.instantiate()
	level_holder.add_child(level)
