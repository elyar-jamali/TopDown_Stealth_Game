@tool
extends Node3D

enum AppearanceType {
	CASUAL,
	ELEGANT
}

const APPEARANCES: Array[PackedScene] = [
	preload("res://data/characters/appearances/female_casual/female_casual_appearance.tscn"),
	preload("res://data/characters/appearances/female_elegant/female_elegant_appearance.tscn")
]

@export var appearance_type: AppearanceType = AppearanceType.CASUAL:
	set(value):
		appearance_type = value
		if is_node_ready():
			_apply_appearance()

func _ready() -> void:
	_apply_appearance()

func _apply_appearance() -> void:
	var skeleton := find_child("Skeleton3D", true, true) as Skeleton3D
	if skeleton == null:
		return

	var old_appearance := skeleton.get_node_or_null("Appearance")
	if old_appearance != null:
		skeleton.remove_child(old_appearance)
		old_appearance.queue_free()

	var new_appearance := APPEARANCES[appearance_type].instantiate()
	new_appearance.name = "Appearance"
	skeleton.add_child(new_appearance)

	if Engine.is_editor_hint():
		new_appearance.owner = get_tree().edited_scene_root