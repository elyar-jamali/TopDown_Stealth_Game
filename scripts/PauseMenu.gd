extends Control

@onready var dim_background: ColorRect = $DimBackground
@onready var panel: PanelContainer = $Panel
@onready var box: VBoxContainer = $Panel/VBoxContainer
@onready var title: Label = $Panel/VBoxContainer/Title
@onready var resume_button: Button = $Panel/VBoxContainer/Resume
@onready var save_button: Button = $Panel/VBoxContainer/Save
@onready var load_button: Button = $Panel/VBoxContainer/Load
@onready var settings_button: Button = $Panel/VBoxContainer/Settings
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenu
@onready var quit_button: Button = $Panel/VBoxContainer/Quit
@onready var confirm_dialog: ConfirmationDialog = $ConfirmationDialog
var confirm_action := ""

func _ready():
	confirm_dialog.confirmed.connect(_on_confirmed)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_setup_layout()
	_setup_texts()
	_connect_buttons()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	if get_tree().paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	get_tree().paused = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()

func resume_game():
	visible = false
	get_tree().paused = false

func _setup_layout():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	dim_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_background.color = Color(0, 0, 0, 0.55)
	dim_background.mouse_filter = Control.MOUSE_FILTER_STOP

	panel.custom_minimum_size = Vector2(460, 420)
	panel.position = (get_viewport_rect().size - panel.custom_minimum_size) / 2.0

	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)

	for button in [
		resume_button,
		save_button,
		load_button,
		settings_button,
		main_menu_button,
		quit_button
	]:
		button.custom_minimum_size = Vector2(280, 44)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.disabled = false

func _setup_texts():
	title.text = LocalizationManager.translate("pause_menu.title_text")
	resume_button.text = LocalizationManager.translate("pause_menu.resume")
	save_button.text = LocalizationManager.translate("pause_menu.save")
	load_button.text = LocalizationManager.translate("pause_menu.load")
	settings_button.text = LocalizationManager.translate("pause_menu.settings")
	main_menu_button.text = LocalizationManager.translate("pause_menu.main_menu")
	quit_button.text = LocalizationManager.translate("pause_menu.exit_to_desktop")

func _connect_buttons():
	resume_button.pressed.connect(resume_game)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_save_pressed():
	print("SAVE")

func _on_load_pressed():
	print("LOAD")

func _on_settings_pressed():
	print("SETTINGS")

func _on_main_menu_pressed():
	confirm_action = "main_menu"
	confirm_dialog.title = LocalizationManager.translate("confirm_dialoge.exit_game")
	confirm_dialog.dialog_text = LocalizationManager.translate("confirm_dialoge.exit_to_main_menu")
	confirm_dialog.ok_button_text = LocalizationManager.translate("confirm_dialoge.yes")
	confirm_dialog.cancel_button_text = LocalizationManager.translate("confirm_dialoge.no")

	confirm_dialog.popup_centered()
	
func _on_quit_pressed():
	confirm_action = "quit"
	confirm_dialog.title = LocalizationManager.translate("confirm_dialoge.exit_game")
	confirm_dialog.dialog_text = LocalizationManager.translate("confirm_dialoge.exit_to_desktop")
	confirm_dialog.ok_button_text = LocalizationManager.translate("confirm_dialoge.yes")
	confirm_dialog.cancel_button_text = LocalizationManager.translate("confirm_dialoge.no")

	confirm_dialog.popup_centered()
	
func _on_confirmed():
	match confirm_action:
		"quit":
			GameManager.quit_game()

		"main_menu":
			GameManager.go_to_main_menu()
