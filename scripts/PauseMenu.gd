extends Control

@onready var hud = get_tree().current_scene.get_node("Hud")

@onready var pause_content: Control = $CenterContainer
@onready var title: Label = $CenterContainer/Panel/VBoxContainer/Title
@onready var resume_button: Button = $CenterContainer/Panel/VBoxContainer/Resume
@onready var save_button: Button = $CenterContainer/Panel/VBoxContainer/Save
@onready var load_button: Button = $CenterContainer/Panel/VBoxContainer/Load
@onready var settings_button: Button = $CenterContainer/Panel/VBoxContainer/Settings
@onready var main_menu_button: Button = $CenterContainer/Panel/VBoxContainer/MainMenu
@onready var quit_button: Button = $CenterContainer/Panel/VBoxContainer/Quit
@onready var settings_panel = $SettingsPanel
@onready var custom_dialog = $CustomDialog

var confirm_action := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not custom_dialog.button_pressed.is_connected(_on_dialog_button_pressed):
		custom_dialog.button_pressed.connect(_on_dialog_button_pressed)
	if not LocalizationManager.language_changed.is_connected(_setup_texts):
		LocalizationManager.language_changed.connect(_setup_texts)
	if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
		ThemeManager.theme_changed.connect(_on_theme_changed)
	if not settings_panel.back_requested.is_connected(_on_settings_back_requested):
		settings_panel.back_requested.connect(_on_settings_back_requested)
	if not settings_panel.bindings_changed.is_connected(_on_bindings_changed):
		settings_panel.bindings_changed.connect(_on_bindings_changed)
	_apply_theme(ThemeManager.get_current_theme())
	_setup_texts()
	_connect_buttons()
	settings_panel.hide()

func _on_bindings_changed() -> void:
	hud.refresh_shortcuts()
		
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			return
		toggle_pause()

func toggle_pause() -> void:
	if get_tree().paused:
		resume_game()
	else:
		pause_game()

func pause_game() -> void:
	get_tree().paused = true
	visible = true
	settings_panel.hide()
	pause_content.show()
	resume_button.grab_focus()

func resume_game() -> void:
	settings_panel.hide()
	pause_content.show()
	visible = false
	get_tree().paused = false

func _setup_texts() -> void:
	title.text = LocalizationManager.translate("pause_menu.title_text")
	resume_button.text = LocalizationManager.translate("pause_menu.resume")
	save_button.text = LocalizationManager.translate("pause_menu.save")
	load_button.text = LocalizationManager.translate("pause_menu.load")
	settings_button.text = LocalizationManager.translate("pause_menu.settings")
	main_menu_button.text = LocalizationManager.translate("pause_menu.main_menu")
	quit_button.text = LocalizationManager.translate("pause_menu.exit_to_desktop")

func _connect_buttons() -> void:
	if not resume_button.pressed.is_connected(resume_game):
		resume_button.pressed.connect(resume_game)
	if not save_button.pressed.is_connected(_on_save_pressed):
		save_button.pressed.connect(_on_save_pressed)
	if not load_button.pressed.is_connected(_on_load_pressed):
		load_button.pressed.connect(_on_load_pressed)
	if not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

func _on_save_pressed() -> void:
	print("SAVE")

func _on_load_pressed() -> void:
	print("LOAD")

func _on_settings_pressed() -> void:
	pause_content.hide()
	settings_panel.open_panel()

func _on_settings_back_requested() -> void:
	settings_panel.hide()
	pause_content.show()
	settings_button.grab_focus()

func _on_main_menu_pressed() -> void:
	confirm_action = "main_menu"
	custom_dialog.show_dialog(
		LocalizationManager.translate("confirm_dialoge.exit_game"),
		LocalizationManager.translate("confirm_dialoge.exit_to_main_menu"),
		[
			LocalizationManager.translate("confirm_dialoge.yes"),
			LocalizationManager.translate("confirm_dialoge.no")
		],
		1
	)

func _on_quit_pressed() -> void:
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

func _on_theme_changed(_theme_id: String, theme_resource: Theme) -> void:
	_apply_theme(theme_resource)

func _apply_theme(theme_resource: Theme) -> void:
	theme = theme_resource
	custom_dialog.theme = theme_resource

func _on_dialog_button_pressed(index: int) -> void:
	var action := confirm_action
	confirm_action = ""
	if index != 0:
		return
	match action:
		"quit":
			GameManager.quit_game()
		"main_menu":
			GameManager.go_to_main_menu()