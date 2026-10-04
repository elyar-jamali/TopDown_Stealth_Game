extends Control

@onready var main_panel: PanelContainer = $MarginContainer/CenterContainer/MenuPanel
@onready var GameTitle: Label = $MarginContainer/CenterContainer/MenuPanel/VBoxContainer/GameTitle
@onready var Subtitle: Label = $MarginContainer/CenterContainer/MenuPanel/VBoxContainer/Subtitle
@onready var start_button: Button = $MarginContainer/CenterContainer/MenuPanel/VBoxContainer/Start
@onready var settings_button: Button = $MarginContainer/CenterContainer/MenuPanel/VBoxContainer/Settings
@onready var exit_button: Button = $MarginContainer/CenterContainer/MenuPanel/VBoxContainer/Exit
@onready var settings_panel = $SettingsPanel
@onready var custom_dialog = $CustomDialog

var confirm_action := ""

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_theme(ThemeManager.get_current_theme())
	if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
		ThemeManager.theme_changed.connect(_on_theme_changed)
	if not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)
	if not custom_dialog.button_pressed.is_connected(_on_dialog_button_pressed):
		custom_dialog.button_pressed.connect(_on_dialog_button_pressed)
	_connect_buttons()
	_setup_texts()
	_show_main_menu()

func _connect_buttons() -> void:
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	if not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)
	if not settings_panel.back_requested.is_connected(_on_settings_back_requested):
		settings_panel.back_requested.connect(_on_settings_back_requested)

func _on_start_pressed() -> void:
	GameManager.start_level("res://scenes/levels/level01.tscn")

func _on_settings_pressed() -> void:
	main_panel.hide()
	settings_panel.open_panel()

func _on_settings_back_requested() -> void:
	_show_main_menu()

func _show_main_menu() -> void:
	settings_panel.hide()
	main_panel.show()
	start_button.grab_focus()

func _on_exit_pressed() -> void:
	confirm_action = "quit"
	custom_dialog.show_dialog(
		LocalizationManager.translate("confirm_dialoge.exit_game"),
		LocalizationManager.translate("confirm_dialoge.exit_to_desktop"),
		[
			LocalizationManager.translate("confirm_dialoge.yes"),
			LocalizationManager.translate("confirm_dialoge.no")
		],
		1
	)

func _on_dialog_button_pressed(index: int) -> void:
	match confirm_action:
		"quit":
			if index == 0:
				GameManager.quit_game()
	confirm_action = ""

func _on_theme_changed(_theme_id: String, theme_resource: Theme) -> void:
	_apply_theme(theme_resource)

func _apply_theme(theme_resource: Theme) -> void:
	theme = theme_resource
	custom_dialog.theme = theme_resource

func _on_language_changed() -> void:
	_setup_texts()

func _setup_texts() -> void:
	GameTitle.text = LocalizationManager.translate("main_menu.gametitle")
	Subtitle.text = LocalizationManager.translate("main_menu.subtitle")
	start_button.text = LocalizationManager.translate("main_menu.start_game")
	settings_button.text = LocalizationManager.translate("main_menu.settings")
	exit_button.text = LocalizationManager.translate("main_menu.quit_game")
