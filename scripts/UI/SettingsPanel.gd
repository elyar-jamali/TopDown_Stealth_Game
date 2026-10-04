extends Control

signal back_requested
signal bindings_changed

@onready var settings_content: Control = $CenterContainer
@onready var settings_title: Label = $CenterContainer/Panel/VBoxContainer/SettingsTitle
@onready var language_label: Label = $CenterContainer/Panel/VBoxContainer/LanguageLabel
@onready var language_button: OptionButton = $CenterContainer/Panel/VBoxContainer/Language
@onready var theme_label: Label = $CenterContainer/Panel/VBoxContainer/ThemeLabel
@onready var theme_button: OptionButton = $CenterContainer/Panel/VBoxContainer/Theme
@onready var controls_button: Button = $CenterContainer/Panel/VBoxContainer/Controls
@onready var back_button: Button = $CenterContainer/Panel/VBoxContainer/Back
@onready var key_mapping_panel = $KeyMappingPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_signals()
	_setup_languages()
	_setup_themes()
	_setup_texts()
	_show_settings_content()

func _connect_signals() -> void:
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if not language_button.item_selected.is_connected(_on_language_selected):
		language_button.item_selected.connect(_on_language_selected)
	if not theme_button.item_selected.is_connected(_on_theme_selected):
		theme_button.item_selected.connect(_on_theme_selected)
	if not controls_button.pressed.is_connected(_on_controls_pressed):
		controls_button.pressed.connect(_on_controls_pressed)
	if not key_mapping_panel.back_requested.is_connected(_on_key_mapping_back_requested):
		key_mapping_panel.back_requested.connect(_on_key_mapping_back_requested)
	if not key_mapping_panel.bindings_changed.is_connected(_on_key_mapping_bindings_changed):
		key_mapping_panel.bindings_changed.connect(_on_key_mapping_bindings_changed)
	if not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)

func open_panel() -> void:
	_show_settings_content()
	_setup_themes()
	_setup_texts()
	show()
	language_button.grab_focus()

func _show_settings_content() -> void:
	key_mapping_panel.hide()
	settings_content.show()

func _on_controls_pressed() -> void:
	settings_content.hide()
	key_mapping_panel.refresh()
	key_mapping_panel.show()

func _on_key_mapping_back_requested() -> void:
	key_mapping_panel.hide()
	settings_content.show()
	controls_button.grab_focus()

func _on_key_mapping_bindings_changed() -> void:
	bindings_changed.emit()

func _on_back_pressed() -> void:
	back_requested.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if key_mapping_panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()

func _setup_languages() -> void:
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

func _on_language_selected(index: int) -> void:
	if index < 0 or index >= language_button.item_count:
		return
	var language_code := str(language_button.get_item_metadata(index))
	GameManager.selected_language = language_code
	GameManager.save_settings()
	if LocalizationManager.load_lang(language_code):
		_setup_texts()

func _setup_themes() -> void:
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

func _on_theme_selected(index: int) -> void:
	if index < 0 or index >= theme_button.item_count:
		return
	var theme_id := str(theme_button.get_item_metadata(index))
	ThemeManager.set_theme(theme_id)

func _on_language_changed() -> void:
	_setup_texts()

func _setup_texts() -> void:
	settings_title.text = LocalizationManager.translate("settings.title")
	language_label.text = LocalizationManager.translate("settings.language")
	theme_label.text = LocalizationManager.translate("settings.theme")
	controls_button.text = LocalizationManager.translate("controls.title")
	back_button.text = LocalizationManager.translate("settings.back")