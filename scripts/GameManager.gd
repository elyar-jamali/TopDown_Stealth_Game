# scripts/GameManager.gd
extends Node

const SETTINGS_PATH := "user://settings.cfg"

const REMAPPABLE_ACTIONS := [
	"crouch",
	"knockout",
	"lethal_takedown",
	"pistol",
	"rifle",
	"heal",
	"open_map",
	"open_log",

	"camera_move_forward",
	"camera_move_backward",
	"camera_move_left",
	"camera_move_right",
	"camera_rotate_left",
	"camera_rotate_right",
	"camera_rotate_modifier",
	"camera_zoom_in",
	"camera_zoom_out",

	"move_interact",
	"cancel_action"
]

enum ConfirmAction {
	NONE,
	QUIT_GAME,
	MAIN_MENU
}

var current_level_path := ""
var selected_language := "en"
var selected_theme := "dark_stealth"
var pending_confirm_action := ConfirmAction.NONE

func _ready():
	load_settings()

# ---------------------------------------------------------
# SETTINGS SAVE
# ---------------------------------------------------------

func save_settings():
	var config := ConfigFile.new()
	# اگر فایل از قبل وجود دارد، اول بخوانش تا
	# تنظیمات دیگری که ممکن است در آن باشند پاک نشوند.
	config.load(SETTINGS_PATH)
	config.set_value(
		"general",
		"language",
		selected_language
	)
	config.set_value(
		"general",
		"theme",
		selected_theme
	)
	_save_input_bindings(config)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning(
			"Could not save settings: "
			+ str(error)
		)
	else:
		print(
			"Settings saved to: ",
			ProjectSettings.globalize_path(
				SETTINGS_PATH
			)
		)

# ---------------------------------------------------------
# SETTINGS LOAD
# ---------------------------------------------------------

func load_settings():
	var config := ConfigFile.new()

	var error := config.load(SETTINGS_PATH)

	if error != OK:
		selected_language = "en"
		selected_theme = "dark_stealth"
		return

	selected_language = str(
		config.get_value(
			"general",
			"language",
			"en"
		)
	)

	selected_theme = str(
		config.get_value(
			"general",
			"theme",
			"dark_stealth"
		)
	)

	_load_input_bindings(config)


# ---------------------------------------------------------
# INPUT BINDINGS SAVE
# ---------------------------------------------------------

func _save_input_bindings(config: ConfigFile) -> void:
	for action_name in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action_name):
			continue
		var saved_events: Array = []
		for event in InputMap.action_get_events(action_name):
			var event_data := _serialize_input_event(event)
			if not event_data.is_empty():
				saved_events.append(event_data)

		config.set_value(
			"controls",
			action_name,
			saved_events
		)


func _serialize_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {
			"type": "key",
			"keycode": int(key_event.keycode),
			"physical_keycode":	int(key_event.physical_keycode),
			"shift": key_event.shift_pressed,
			"ctrl": key_event.ctrl_pressed,
			"alt": key_event.alt_pressed,
			"meta": key_event.meta_pressed
		}

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		return {
			"type": "mouse",
			"button_index":
				int(mouse_event.button_index),
			"shift": mouse_event.shift_pressed,
			"ctrl": mouse_event.ctrl_pressed,
			"alt": mouse_event.alt_pressed,
			"meta": mouse_event.meta_pressed
		}

	return {}


# ---------------------------------------------------------
# INPUT BINDINGS LOAD
# ---------------------------------------------------------

func _load_input_bindings(config: ConfigFile) -> void:
	if not config.has_section("controls"):
		return
	for action_name in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action_name):
			continue
		if not config.has_section_key(
			"controls",	action_name
		):
			continue

		var saved_events: Array = config.get_value(
			"controls",	action_name, []
		)
		if not saved_events is Array:
			continue

		InputMap.action_erase_events(action_name)

		for data in saved_events:

			if not data is Dictionary:
				continue

			var event := _deserialize_input_event(data)

			if event != null:
				InputMap.action_add_event(
					action_name,
					event
				)


func _deserialize_input_event(data: Dictionary) -> InputEvent:
	if not data.has("type"):
		return null	
	var event_type := str(data["type"])

	if event_type == "key":

		var event := InputEventKey.new()
		if data.has("keycode"):
			event.keycode = int(data["keycode"]) as Key
		if data.has("physical_keycode"):
			event.physical_keycode = int(data["physical_keycode"]) as Key
		if data.has("shift"):
			event.shift_pressed = bool(data["shift"])
		if data.has("ctrl"):
			event.ctrl_pressed = bool(data["ctrl"])
		if data.has("alt"):
			event.alt_pressed = bool(data["alt"])
		if data.has("meta"):
			event.meta_pressed = bool(data["meta"])

		return event


	if event_type == "mouse":

		var event := InputEventMouseButton.new()
		if data.has("button_index"):
			event.button_index = int(data["button_index"]) as MouseButton
		if data.has("shift"):	
			event.shift_pressed = bool(data["shift"])
		if data.has("ctrl"):	
			event.ctrl_pressed = bool(data["ctrl"])
		if data.has("alt"):	
			event.alt_pressed = bool(data["alt"])
		if data.has("meta"):
			event.meta_pressed = bool(data["meta"])

		return event

	return null
# ---------------------------------------------------------
# GAME
# ---------------------------------------------------------
func start_level(path: String):
	current_level_path = path
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func go_to_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")


func quit_game():
	get_tree().quit()