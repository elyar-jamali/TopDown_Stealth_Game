@tool
extends EditorInspectorPlugin

var preview_callback: Callable

func _init(callback: Callable) -> void:
	preview_callback = callback


func _can_handle(object: Object) -> bool:
	if not object is Node3D:
		return false

	if not object.has_node("Visual"):
		return false

	var required := [
		"character_gender",
		"male_appearance",
		"female_appearance"
	]

	var properties := {}

	for property in object.get_property_list():
		properties[property["name"]] = true

	for property_name in required:
		if not properties.has(property_name):
			return false

	return true


func _parse_begin(object: Object) -> void:
	var button := Button.new()
	button.text = "Update Visual Preview"
	button.tooltip_text = "Apply the selected NPC gender and appearance in the editor."
	button.pressed.connect(
		func() -> void:
			preview_callback.call(object)
	)
	add_custom_control(button)
