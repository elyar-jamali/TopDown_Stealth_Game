extends Node
enum CursorState {
	DEFAULT,
	INTERACT,
	ROTATE,
	AIM,
	LOCKED
}
var current_state = CursorState.DEFAULT
var ui_cursor = null
func register_ui(cursor_node):
	ui_cursor = cursor_node

func set_state(new_state):
	if current_state == new_state:
		return
	current_state = new_state
	if ui_cursor:
		ui_cursor.update_cursor(current_state)
