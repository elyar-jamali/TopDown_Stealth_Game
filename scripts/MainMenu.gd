extends Control
@onready var background: TextureRect = $Background
@onready var margin: MarginContainer = $MarginContainer
@onready var center: CenterContainer = $MarginContainer/CenterContainer
@onready var main_box: VBoxContainer = $MarginContainer/CenterContainer/VBoxContainer
@onready var start_button: Button = $MarginContainer/CenterContainer/VBoxContainer/Start
@onready var settings_button: Button = $MarginContainer/CenterContainer/VBoxContainer/Settings
@onready var exit_button: Button = $MarginContainer/CenterContainer/VBoxContainer/Exit
@onready var settings_panel: Control = $SettingsPanel
@onready var settings_center: CenterContainer = $SettingsPanel/CenterContainer
@onready var settings_box: VBoxContainer = $SettingsPanel/CenterContainer/VBoxContainer
@onready var settings_title: Label = $SettingsPanel/CenterContainer/VBoxContainer/SettingsTitle
@onready var language_label: Label = $SettingsPanel/CenterContainer/VBoxContainer/LanguageLabel
@onready var language_button: OptionButton = $SettingsPanel/CenterContainer/VBoxContainer/Language
@onready var back_button: Button = $SettingsPanel/CenterContainer/VBoxContainer/Back
@onready var fade: ColorRect = $Fade
@onready var confirm_dialog: ConfirmationDialog = $ConfirmationDialog
func _ready():
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_layout()
	_setup_languages()
	_setup_texts()
	_connect_buttons()
	_show_main_menu()
	
func _setup_layout():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -20
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	main_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_theme_constant_override("separation", 16)
	for button in [start_button, settings_button, exit_button]:
		button.custom_minimum_size = Vector2(260, 48)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = false
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	settings_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_box.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_box.add_theme_constant_override("separation", 16)
	language_button.custom_minimum_size = Vector2(260, 48)
	language_button.mouse_filter = Control.MOUSE_FILTER_STOP
	language_button.focus_mode = Control.FOCUS_ALL
	back_button.custom_minimum_size = Vector2(260, 48)
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	back_button.focus_mode = Control.FOCUS_ALL
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.visible = false
	fade.z_index = -10
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
	if not confirm_dialog.confirmed.is_connected(_on_confirmed):
		confirm_dialog.confirmed.connect(_on_confirmed)
func _on_start_pressed():
	GameManager.start_level("res://scenes/levels/Level01.tscn")
func _on_settings_pressed():
	main_box.visible = false
	settings_panel.visible = true
	language_button.grab_focus()
func _on_back_pressed():
	_show_main_menu()
func _show_main_menu():
	settings_panel.visible = false
	main_box.visible = true
	start_button.grab_focus()
func _on_exit_pressed():
	confirm_dialog.title = LocalizationManager.translate("confirm_dialoge.exit_game")
	confirm_dialog.dialog_text = LocalizationManager.translate("confirm_dialoge.exit_to_desktop")
	confirm_dialog.ok_button_text = LocalizationManager.translate("confirm_dialoge.yes")
	confirm_dialog.cancel_button_text = LocalizationManager.translate("confirm_dialoge.no")
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
		
func _setup_texts():
	start_button.text = LocalizationManager.translate("main_menu.start_game")
	settings_button.text = LocalizationManager.translate("main_menu.settings")
	exit_button.text = LocalizationManager.translate("main_menu.quit_game")
	settings_title.text = LocalizationManager.translate("settings.title")
	language_label.text = LocalizationManager.translate("settings.language")
	back_button.text = LocalizationManager.translate("settings.back")
