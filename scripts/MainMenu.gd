extends Control

@onready var main_panel: PanelContainer = $MarginContainer/CenterContainer/MenuPanel
@onready var main_box: VBoxContainer = $MarginContainer/CenterContainer/MenuPanel/VBoxContainer
@onready var GameTitle: Label = $MarginContainer/CenterContainer/MenuPanel/VBoxContainer/GameTitle
@onready var Subtitle: Label = $MarginContainer/CenterContainer/MenuPanel/VBoxContainer/Subtitle
@onready var start_button: Button = $MarginContainer/CenterContainer/MenuPanel/VBoxContainer/Start
@onready var settings_button: Button = $MarginContainer/CenterContainer/MenuPanel/VBoxContainer/Settings
@onready var exit_button: Button = $MarginContainer/CenterContainer/MenuPanel/VBoxContainer/Exit
@onready var settings_panel: Control = $SettingsPanel
@onready var settings_box: VBoxContainer = $SettingsPanel/CenterContainer/Panel/VBoxContainer
@onready var settings_title: Label = $SettingsPanel/CenterContainer/Panel/VBoxContainer/SettingsTitle
@onready var language_label: Label = $SettingsPanel/CenterContainer/Panel/VBoxContainer/LanguageLabel
@onready var language_button: OptionButton = $SettingsPanel/CenterContainer/Panel/VBoxContainer/Language
@onready var theme_label: Label = $SettingsPanel/CenterContainer/Panel/VBoxContainer/ThemeLabel
@onready var theme_button: OptionButton = $SettingsPanel/CenterContainer/Panel/VBoxContainer/Theme
@onready var back_button: Button = $SettingsPanel/CenterContainer/Panel/VBoxContainer/Back
@onready var confirm_dialog: ConfirmationDialog = $ConfirmationDialog

func _ready():
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_theme(ThemeManager.get_current_theme())
	if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
		ThemeManager.theme_changed.connect(_on_theme_changed)
	_setup_languages()
	_setup_themes()
	_setup_texts()
	_connect_buttons()
	_show_main_menu()

func _connect_buttons():
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	if not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if not language_button.item_selected.is_connected(_on_language_selected):
		language_button.item_selected.connect(_on_language_selected)
	if not theme_button.item_selected.is_connected(_on_theme_selected):
		theme_button.item_selected.connect(_on_theme_selected)
	if not confirm_dialog.confirmed.is_connected(_on_confirmed):
		confirm_dialog.confirmed.connect(_on_confirmed)

func _on_start_pressed():
	GameManager.start_level("res://scenes/levels/level01.tscn")

func _on_settings_pressed():
	main_panel.visible = false
	settings_panel.visible = true
	language_button.grab_focus()

func _on_back_pressed():
	_show_main_menu()

func _show_main_menu():
	settings_panel.visible = false
	main_panel.visible = true
	start_button.grab_focus()

func _on_exit_pressed():
	confirm_dialog.title = LocalizationManager.translate("confirm_dialoge.exit_game")
	confirm_dialog.dialog_text = LocalizationManager.translate("confirm_dialoge.exit_to_desktop")
	confirm_dialog.ok_button_text = LocalizationManager.translate("confirm_dialoge.yes")
	confirm_dialog.cancel_button_text = LocalizationManager.translate("confirm_dialoge.no")
	await get_tree().process_frame
	confirm_dialog.reset_size()
	confirm_dialog.popup_centered()

func _on_confirmed():
	GameManager.quit_game()

func _setup_languages():
	language_button.clear()
	var languages: Array[Dictionary] = LocalizationManager.scan_languages()
	var selected_index := -1
	for language: Dictionary in languages:
		language_button.add_item(str(language["name"]))
		var index := language_button.item_count - 1
		language_button.set_item_metadata(index, str(language["code"]))
		if str(language["code"]) == GameManager.selected_language:
			selected_index = index
	if selected_index >= 0:
		language_button.select(selected_index)
		LocalizationManager.load_lang(GameManager.selected_language)
	elif language_button.item_count > 0:
		language_button.select(0)
		var default_code := str(language_button.get_item_metadata(0))
		GameManager.selected_language = default_code
		LocalizationManager.load_lang(default_code)

func _on_language_selected(index: int):
	if index < 0 or index >= language_button.item_count:
		return
	var language_code := str(language_button.get_item_metadata(index))
	GameManager.selected_language = language_code
	GameManager.save_settings()
	if LocalizationManager.load_lang(language_code):
		_setup_texts()

func _setup_themes():
	theme_button.clear()
	var selected_index := -1
	var theme_list := ThemeManager.get_theme_list()
	for theme_info: Dictionary in theme_list:
		theme_button.add_item(str(theme_info["name"]))
		var index := theme_button.item_count - 1
		theme_button.set_item_metadata(index, str(theme_info["id"]))
		if str(theme_info["id"]) == ThemeManager.current_theme_id:
			selected_index = index
	if selected_index >= 0:
		theme_button.select(selected_index)

func _on_theme_selected(index: int):
	if index < 0 or index >= theme_button.item_count:
		return
	var theme_id := str(theme_button.get_item_metadata(index))
	ThemeManager.set_theme(theme_id)

func _on_theme_changed(_theme_id: String, theme_resource: Theme):
	_apply_theme(theme_resource)

func _apply_theme(theme_resource: Theme):
	theme = theme_resource
	confirm_dialog.theme = theme_resource

func _setup_texts():
	GameTitle.text = LocalizationManager.translate("main_menu.gametitle")
	Subtitle.text = LocalizationManager.translate("main_menu.subtitle")
	start_button.text = LocalizationManager.translate("main_menu.start_game")
	settings_button.text = LocalizationManager.translate("main_menu.settings")
	exit_button.text = LocalizationManager.translate("main_menu.quit_game")
	settings_title.text = LocalizationManager.translate("settings.title")
	language_label.text = LocalizationManager.translate("settings.language")
	theme_label.text = LocalizationManager.translate("settings.theme")
	back_button.text = LocalizationManager.translate("settings.back")
