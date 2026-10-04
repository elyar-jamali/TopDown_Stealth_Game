extends MarginContainer

signal back_requested
signal bindings_changed

enum DialogMode {
	NONE,
	CONFLICT,
	RESET_DEFAULTS
}

const ACTION_GROUPS := [
	{
		"title": "controls.gameplay",
		"actions": [
			{
				"action": "crouch",
				"label": "controls.crouch"
			},
			{
				"action": "knockout",
				"label": "controls.knockout"
			},
			{
				"action": "lethal_takedown",
				"label": "controls.lethal_takedown"
			},
			{
				"action": "pistol",
				"label": "controls.pistol"
			},
			{
				"action": "rifle",
				"label": "controls.rifle"
			},
			{
				"action": "heal",
				"label": "controls.heal"
			},
			{
				"action": "open_map",
				"label": "controls.map"
			},
			{
				"action": "open_log",
				"label": "controls.log"
			}
		]
	},

	{
		"title": "controls.camera",
		"actions": [
			{
				"action": "camera_move_forward",
				"label": "controls.camera_move_forward"
			},
			{
				"action": "camera_move_backward",
				"label": "controls.camera_move_backward"
			},
			{
				"action": "camera_move_left",
				"label": "controls.camera_move_left"
			},
			{
				"action": "camera_move_right",
				"label": "controls.camera_move_right"
			},
			{
				"action": "camera_rotate_left",
				"label": "controls.camera_rotate_left"
			},
			{
				"action": "camera_rotate_right",
				"label": "controls.camera_rotate_right"
			},
			{
				"action": "camera_rotate_modifier",
				"label": "controls.camera_rotate_modifier"
			},
			{
				"action": "camera_zoom_in",
				"label": "controls.camera_zoom_in"
			},
			{
				"action": "camera_zoom_out",
				"label": "controls.camera_zoom_out"
			}
		]
	},

	{
		"title": "controls.mouse",
		"actions": [
			{
				"action": "move_interact",
				"label": "controls.move_interact"
			},
			{
				"action": "cancel_action",
				"label": "controls.cancel_action"
			}
		]
	}
]

@onready var title_label: Label = \
	$CenterContainer/PanelContainer/ContentMargin/MainColumn/Title
@onready var scroll_container: ScrollContainer = \
	$CenterContainer/PanelContainer/ContentMargin/MainColumn/ScrollContainer
@onready var bindings_list: VBoxContainer = \
	$CenterContainer/PanelContainer/ContentMargin/MainColumn/ScrollContainer/BindingsList
@onready var reset_defaults_button: Button = \
	$CenterContainer/PanelContainer/ContentMargin/MainColumn/BottomBar/ResetDefaultsButton
@onready var back_button: Button = \
	$CenterContainer/PanelContainer/ContentMargin/MainColumn/BottomBar/BackButton
@onready var custom_dialog = $CustomDialog

var _capture_action: StringName = &""

var _pending_event: InputEvent = null

var _conflicting_action: StringName = &""
var _conflicting_event: InputEvent = null

var _dialog_mode := DialogMode.NONE

var _row_buttons: Dictionary = {}
var _binding_labels: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# چون Inspector این گزینه‌ها را بهت نشان نمی‌داد،
	# همین‌جا اعمالشان می‌کنیم.
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bindings_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not reset_defaults_button.pressed.is_connected(
		_on_reset_defaults_pressed
	):
		reset_defaults_button.pressed.connect(_on_reset_defaults_pressed)
	if not back_button.pressed.is_connected(
		_on_back_pressed
	):
		back_button.pressed.connect(_on_back_pressed)
	if not custom_dialog.button_pressed.is_connected(
		_on_dialog_button_pressed
	):
		custom_dialog.button_pressed.connect(_on_dialog_button_pressed)
	if not LocalizationManager.language_changed.is_connected(
		_on_language_changed
	):
		LocalizationManager.language_changed.connect(_on_language_changed)
	_setup_static_texts()
	_rebuild_list()

func refresh() -> void:
	_cancel_capture()
	_setup_static_texts()
	_rebuild_list()
	
# ---------------------------------------------------------
# INPUT
# ---------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# وقتی CustomDialog باز است، خودش Esc و ورودی‌ها را مدیریت می‌کند.
	if custom_dialog.visible:
		return
	# -----------------------------------------------------
	# در حال انتظار برای کلید جدید
	# -----------------------------------------------------
	if _capture_action != &"":
		# Esc یعنی لغو Remapping، نه Bind کردن Escape.
		if event.is_action_pressed("ui_cancel"):
			_cancel_capture()
			get_viewport().set_input_as_handled()
			return
		var captured_event := _create_binding_event(event)
		if captured_event != null:
			_try_assign_event(_capture_action, captured_event)
			get_viewport().set_input_as_handled()
		return
	# -----------------------------------------------------
	# حالت عادی
	# -----------------------------------------------------
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()
# ---------------------------------------------------------
# TEXT / LOCALIZATION
# ---------------------------------------------------------
func _setup_static_texts() -> void:
	title_label.text = LocalizationManager.translate("controls.title")
	reset_defaults_button.text = LocalizationManager.translate("controls.reset_defaults")
	back_button.text = LocalizationManager.translate("controls.back")

func _on_language_changed() -> void:
	_cancel_capture()
	_setup_static_texts()
	_rebuild_list()
# ---------------------------------------------------------
# BUILD UI
# ---------------------------------------------------------
func _rebuild_list() -> void:
	for child in bindings_list.get_children():
		child.queue_free()
	_row_buttons.clear()
	_binding_labels.clear()
	for group_index in range(ACTION_GROUPS.size()):
		var group: Dictionary = ACTION_GROUPS[group_index]
		_create_section(LocalizationManager.translate(str(group["title"])))
		var actions: Array = group["actions"]
		for action_info in actions:
			var action_name := StringName(
				action_info["action"]
			)
			if not InputMap.has_action(action_name):
				push_warning("InputMap action not found: "
					+ str(action_name)
				)
				continue
			_create_action_row(action_name,
				str(action_info["label"])
			)
		if group_index < ACTION_GROUPS.size() - 1:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 10)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bindings_list.add_child(spacer)

func _create_section(text: String) -> void:
	var section_label := Label.new()
	section_label.text = text
	section_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section_label.add_theme_font_size_override("font_size", 16)
	section_label.custom_minimum_size.y = 28
	bindings_list.add_child(section_label)
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bindings_list.add_child(separator)


func _create_action_row(action_name: StringName, label_key: String) -> void:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.focus_mode = Control.FOCUS_NONE
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.clip_contents = true
	bindings_list.add_child(row)
	_apply_normal_row_style(row)
	# -----------------------------------------------------
	# MarginContainer
	# -----------------------------------------------------
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left",12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom",	6)
	row.add_child(margin)
	# -----------------------------------------------------
	# Row Content
	# -----------------------------------------------------
	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)
	# -----------------------------------------------------
	# Action Label
	# -----------------------------------------------------
	var action_label := Label.new()
	action_label.text = LocalizationManager.translate(label_key)
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(action_label)
	# -----------------------------------------------------
	# Binding Label
	# -----------------------------------------------------
	var binding_label := Label.new()
	binding_label.text = _get_binding_text(action_name)
	binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	binding_label.custom_minimum_size.x = 160
	binding_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(binding_label)
	# -----------------------------------------------------
	# Store references
	# -----------------------------------------------------
	_row_buttons[action_name] = row
	_binding_labels[action_name] = binding_label
	row.pressed.connect(_on_binding_row_pressed.bind(action_name))
# --------------------------------------------------------
# ROW STYLE
# ---------------------------------------------------------
func _apply_normal_row_style(row: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	var base_color := row.get_theme_color("font_color",	"Button")
	var hover := _create_row_style(base_color, 0.08, 0.18)
	var pressed := _create_row_style(base_color, 0.14, 0.25)
	row.add_theme_stylebox_override("normal", normal)
	row.add_theme_stylebox_override("hover", hover)
	row.add_theme_stylebox_override("pressed", pressed)
	row.add_theme_stylebox_override("focus", normal)

func _apply_capture_row_style(row: Button) -> void:
	var base_color := row.get_theme_color("font_color",	"Button")
	var active := _create_row_style(base_color,	0.16, 0.35)
	row.add_theme_stylebox_override("normal", active)
	row.add_theme_stylebox_override("hover", active)

func _create_row_style(base_color: Color, background_alpha: float, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var background := base_color
	background.a = background_alpha
	var border := base_color
	border.a = border_alpha
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
# ---------------------------------------------------------
# START / CANCEL CAPTURE
# ---------------------------------------------------------
func _on_binding_row_pressed(action_name: StringName) -> void:
	if custom_dialog.visible:
		return
	if _capture_action != &"":
		_cancel_capture()
	_capture_action = action_name
	var binding_label: Label = _binding_labels.get(action_name)
	if binding_label:
		binding_label.text = LocalizationManager.translate("controls.press_key")
	var row: Button = _row_buttons.get(action_name)
	if row:
		_apply_capture_row_style(row)

func _cancel_capture() -> void:
	if _capture_action == &"":
		return
	var previous_action := _capture_action
	_capture_action = &""
	var binding_label: Label = _binding_labels.get(previous_action)
	if binding_label:
		binding_label.text = _get_binding_text(previous_action)
	var row: Button = _row_buttons.get(previous_action)
	if row:
		_apply_normal_row_style(row)
# ---------------------------------------------------------
# CAPTURE KEY / MOUSE
# ---------------------------------------------------------
func _create_binding_event(event: InputEvent) -> InputEvent:
	# -----------------------------------------------------
	# Keyboard
	# -----------------------------------------------------
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed:
			return null
		if key_event.echo:
			return null
		var result := InputEventKey.new()
		if key_event.physical_keycode != 0:
			result.physical_keycode = key_event.physical_keycode
		else:
			result.keycode = key_event.keycode
		var code := _get_key_code(key_event)
		result.shift_pressed = key_event.shift_pressed and code != KEY_SHIFT
		result.ctrl_pressed = key_event.ctrl_pressed and code != KEY_CTRL
		result.alt_pressed = key_event.alt_pressed and code != KEY_ALT
		result.meta_pressed = key_event.meta_pressed and code != KEY_META
		return result
	# -----------------------------------------------------
	# Mouse buttons + Wheel
	# -----------------------------------------------------
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return null
		var result := InputEventMouseButton.new()
		result.button_index = mouse_event.button_index
		result.shift_pressed = mouse_event.shift_pressed
		result.ctrl_pressed = mouse_event.ctrl_pressed
		result.alt_pressed = mouse_event.alt_pressed
		result.meta_pressed = mouse_event.meta_pressed
		return result
	return null
# ---------------------------------------------------------
# TRY ASSIGN
# ---------------------------------------------------------
func _try_assign_event(action_name: StringName,	new_event: InputEvent) -> void:
	# اگر کاربر همان Binding فعلی را دوباره زد،
	# هیچ کاری نکن.
	for current_event in InputMap.action_get_events(action_name):
		if _events_are_equal(current_event, new_event):
			_cancel_capture()
			return
	var conflict := _find_conflict(action_name,	new_event)
	if not conflict.is_empty():
		_pending_event = new_event
		_conflicting_action = conflict["action"]
		_conflicting_event = conflict["event"]
		_dialog_mode = DialogMode.CONFLICT
		_show_conflict_dialog()
		return

	_assign_event(action_name, new_event)
# ---------------------------------------------------------
# CONFLICT
# ---------------------------------------------------------
func _find_conflict(target_action: StringName, new_event: InputEvent) -> Dictionary:
	for group in ACTION_GROUPS:
		var actions: Array = group["actions"]
		for action_info in actions:
			var action_name := StringName(action_info["action"])
			if action_name == target_action:
				continue
			if not InputMap.has_action(action_name):
				continue
			for existing_event in InputMap.action_get_events(action_name):
				if _events_are_equal(existing_event, new_event):
					return {
						"action": action_name,
						"event": existing_event
					}
	return {}

func _show_conflict_dialog() -> void:
	var key_text := _event_to_text(_pending_event)
	var action_text := _get_action_label(_conflicting_action)
	var message := LocalizationManager.translate("controls.conflict_message")
	message = message.replace("{key}", key_text)
	message = message.replace("{action}", action_text)
	custom_dialog.show_dialog(
		LocalizationManager.translate("controls.conflict_title"),
		message,
		[
			LocalizationManager.translate(
				"controls.replace"
			),
			LocalizationManager.translate(
				"controls.cancel"
			)
		],
		1
	)
# ---------------------------------------------------------
# ASSIGN
# ---------------------------------------------------------
func _assign_event(action_name: StringName,	new_event: InputEvent) -> void:
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, new_event)
	_capture_action = &""
	_rebuild_list()
	GameManager.save_settings()
	bindings_changed.emit()
# ---------------------------------------------------------
# RESET DEFAULTS
# ---------------------------------------------------------
func _on_reset_defaults_pressed() -> void:
	if _capture_action != &"":
		_cancel_capture()
	_dialog_mode = \
		DialogMode.RESET_DEFAULTS
	custom_dialog.show_dialog(
		LocalizationManager.translate("controls.reset_title"),
		LocalizationManager.translate("controls.reset_message"),
		[
			LocalizationManager.translate(
				"controls.reset"
			),
			LocalizationManager.translate(
				"controls.cancel"
			)
		],
		1
	)
# ---------------------------------------------------------
# CUSTOM DIALOG RESULT
# ---------------------------------------------------------
func _on_dialog_button_pressed(index: int) -> void:
	match _dialog_mode:
		DialogMode.CONFLICT:
			if index == 0:
				if (
					_conflicting_action != &""
					and
					_conflicting_event != null
				):
					InputMap.action_erase_event(
						_conflicting_action,
						_conflicting_event
					)
				if (
					_capture_action != &""
					and
					_pending_event != null
				):
					_assign_event(
						_capture_action,
						_pending_event
					)
			else:
				_cancel_capture()
		DialogMode.RESET_DEFAULTS:
			if index == 0:
				InputMap.load_from_project_settings()
				_capture_action = &""
				_rebuild_list()
				GameManager.save_settings()
				bindings_changed.emit()
	_clear_dialog_state()

func _clear_dialog_state() -> void:
	_dialog_mode = DialogMode.NONE
	_pending_event = null
	_conflicting_action = &""
	_conflicting_event = null
# ---------------------------------------------------------
# BACK
# ---------------------------------------------------------
func _on_back_pressed() -> void:
	if _capture_action != &"":
		_cancel_capture()
		return
	back_requested.emit()
# ---------------------------------------------------------
# EVENT COMPARISON
# ---------------------------------------------------------
func _events_are_equal(first: InputEvent, second: InputEvent) -> bool:
	if first is InputEventKey and second is InputEventKey:
		var key_a := first as InputEventKey
		var key_b := second as InputEventKey
		return (
			_get_key_code(key_a)
			==
			_get_key_code(key_b)
			and
			key_a.shift_pressed
			==
			key_b.shift_pressed
			and
			key_a.ctrl_pressed
			==
			key_b.ctrl_pressed
			and
			key_a.alt_pressed
			==
			key_b.alt_pressed
			and
			key_a.meta_pressed
			==
			key_b.meta_pressed
		)
	if first is InputEventMouseButton and second is InputEventMouseButton:
		var mouse_a := first as InputEventMouseButton
		var mouse_b := second as InputEventMouseButton
		return (
			mouse_a.button_index
			==
			mouse_b.button_index
			and
			mouse_a.shift_pressed
			==
			mouse_b.shift_pressed
			and
			mouse_a.ctrl_pressed
			==
			mouse_b.ctrl_pressed
			and
			mouse_a.alt_pressed
			==
			mouse_b.alt_pressed
			and
			mouse_a.meta_pressed
			==
			mouse_b.meta_pressed
		)
	return false
# ---------------------------------------------------------
# BINDING TEXT
# ---------------------------------------------------------
func _get_binding_text(action_name: StringName) -> String:
	var texts: Array[String] = []
	for event in InputMap.action_get_events(action_name):
		var text := _event_to_text(event)
		if text.is_empty():
			continue
		if not texts.has(text):
			texts.append(text)
	if texts.is_empty():
		return LocalizationManager.translate("controls.unassigned")
	return " / ".join(texts)

func _event_to_text(event: InputEvent) -> String:
	# -----------------------------------------------------
	# Keyboard
	# -----------------------------------------------------
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := _get_key_code(key_event)
		if code == 0:
			return ""
		var parts: Array[String] = []
		if (key_event.ctrl_pressed and code != KEY_CTRL):
			parts.append("Ctrl")
		if (key_event.shift_pressed	and code != KEY_SHIFT):
			parts.append("Shift")
		if (key_event.alt_pressed and code != KEY_ALT):
			parts.append("Alt")
		if (key_event.meta_pressed and code != KEY_META):
			parts.append("Meta")
		parts.append(OS.get_keycode_string(code))
		return " + ".join(parts)
	# -----------------------------------------------------
	# Mouse
	# -----------------------------------------------------
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return LocalizationManager.translate("controls.mouse_left")
			MOUSE_BUTTON_RIGHT:
				return LocalizationManager.translate("controls.mouse_right")
			MOUSE_BUTTON_MIDDLE:
				return LocalizationManager.translate("controls.mouse_middle")
			MOUSE_BUTTON_WHEEL_UP:
				return LocalizationManager.translate("controls.wheel_up")
			MOUSE_BUTTON_WHEEL_DOWN:
				return LocalizationManager.translate("controls.wheel_down")
			MOUSE_BUTTON_WHEEL_LEFT:
				return LocalizationManager.translate("controls.wheel_left")
			MOUSE_BUTTON_WHEEL_RIGHT:
				return LocalizationManager.translate("controls.wheel_right")
			_:
				var text := LocalizationManager.translate("controls.mouse_button")
				return text.replace("{button}",	str(mouse_event.button_index))
	return ""


func _get_key_code(event: InputEventKey) -> Key:
	if event.physical_keycode != 0:
		return event.physical_keycode
	return event.keycode
# ---------------------------------------------------------
# ACTION LABEL
# ---------------------------------------------------------
func _get_action_label(action_name: StringName) -> String:
	for group in ACTION_GROUPS:
		var actions: Array = group["actions"]
		for action_info in actions:
			if StringName(action_info["action"]) == action_name:
				return LocalizationManager.translate(
					str(action_info["label"])
				)
	return str(action_name)
