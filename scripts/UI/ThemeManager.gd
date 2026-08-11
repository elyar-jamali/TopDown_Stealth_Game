extends Node

signal theme_changed(theme_id: String, theme_resource: Theme)

const THEME_DARK_STEALTH := "dark_stealth"
const THEME_LIGHT_TACTICAL := "light_tactical"
const THEME_AMBER_CLASSIC := "amber_classic"

var themes := {
	THEME_DARK_STEALTH: {
		"name": "Dark Stealth",
		"resource": preload("res://data/themes/dark_stealth.tres")
	},
	THEME_LIGHT_TACTICAL: {
		"name": "Light Tactical",
		"resource": preload("res://data/themes/light_tactical.tres")
	},
	THEME_AMBER_CLASSIC: {
		"name": "Amber Classic",
		"resource": preload("res://data/themes/amber_classic.tres")
	}
}

var current_theme_id := THEME_DARK_STEALTH

func _ready():
	current_theme_id = GameManager.selected_theme
	if not themes.has(current_theme_id):
		current_theme_id = THEME_DARK_STEALTH

func get_current_theme() -> Theme:
	return themes[current_theme_id]["resource"]

func get_theme_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for theme_id in themes:
		result.append({
			"id": theme_id,
			"name": themes[theme_id]["name"]
		})
	return result

func set_theme(theme_id: String):
	if not themes.has(theme_id):
		return
	if current_theme_id == theme_id:
		return

	current_theme_id = theme_id
	GameManager.selected_theme = theme_id
	GameManager.save_settings()
	theme_changed.emit(current_theme_id, get_current_theme())
