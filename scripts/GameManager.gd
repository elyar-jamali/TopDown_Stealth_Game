extends Node

var active_character: Node = null


func set_active_character(character: Node):
	if active_character and active_character.has_method("on_control_lost"):
		active_character.on_control_lost()

	active_character = character

	if active_character and active_character.has_method("on_control_gained"):
		active_character.on_control_gained()


func get_active_character():
	return active_character
