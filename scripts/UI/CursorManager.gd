extends Node

enum CursorState {
	DEFAULT,
	INTERACT,
	ROTATE,
	AIM,
	LOCKED,
	KNOCKOUT,
	GARROTE
}

var current_state: CursorState = CursorState.DEFAULT
var hover_state: CursorState = CursorState.DEFAULT
var action_state: CursorState = CursorState.DEFAULT

var force_default_cursor: bool = false
var ui_cursor = null
var rotate_active: bool = false


func register_ui(cursor_node) -> void:
	ui_cursor = cursor_node
	_refresh_cursor()


# درخواست کرسر از طرف Hover یا سایر سیستم‌های معمولی
func set_state(new_state: CursorState) -> void:
	hover_state = new_state
	_refresh_cursor()


# درخواست کرسر از طرف اکشن انتخاب‌شده
func set_action_state(new_state: CursorState) -> void:
	action_state = new_state
	_refresh_cursor()


func clear_action_state() -> void:
	action_state = CursorState.DEFAULT
	_refresh_cursor()


# func _refresh_cursor() -> void:
# 	if force_default_cursor:
# 		ui_cursor.update_cursor(CursorState.DEFAULT)
# 		return
# 	var desired_state: CursorState = hover_state
# 	if action_state != CursorState.DEFAULT:
# 		desired_state = action_state
# 	if current_state == desired_state:
# 		return
# 	current_state = desired_state
# 	if ui_cursor != null:
# 		ui_cursor.update_cursor(current_state)

func _refresh_cursor() -> void:
	if not is_instance_valid(ui_cursor):
		ui_cursor = null
		return
	var desired_state: CursorState = hover_state
	if action_state != CursorState.DEFAULT:
		desired_state = action_state
	if rotate_active:
		desired_state = CursorState.ROTATE
	if force_default_cursor:
		desired_state = CursorState.DEFAULT
	current_state = desired_state
	ui_cursor.update_cursor(desired_state)

func set_force_default(enabled: bool) -> void:
	force_default_cursor = enabled
	_refresh_cursor()

func _process(_delta: float) -> void:
	if not InputMap.has_action("camera_rotate_modifier"):
		return
	var pressed := Input.is_action_pressed("camera_rotate_modifier")
	if pressed == rotate_active:
		return
	rotate_active = pressed
	_refresh_cursor()