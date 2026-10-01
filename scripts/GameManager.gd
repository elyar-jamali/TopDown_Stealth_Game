# scripts/GameManager.gd
extends Node
const SETTINGS_PATH := "user://settings.cfg"
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
func save_settings():
	var config := ConfigFile.new()
	config.set_value("general", "language", selected_language)
	config.set_value("general", "theme", selected_theme)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save settings: " + str(error))
func load_settings():
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error != OK:
		selected_language = "en"
		selected_theme = "dark_stealth"
		return
	selected_language = str(config.get_value("general", "language", "en"))
	selected_theme = str(config.get_value("general", "theme", "dark_stealth"))

func start_level(path: String):
	current_level_path = path
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func go_to_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")

func quit_game():
	get_tree().quit()
