extends Node

var current_hover_text := ""
var current_hover: Node = null
var ui = null

func register_ui(_ui):
	ui = _ui

func set_hover_text(text: String):
	var trtext = LocalizationManager.translate(text)
	if current_hover_text == trtext:
		return
	current_hover_text = trtext
	if ui:
		ui.update_hover_text(trtext)


func set_hover_target(target: Node):
	if target == current_hover:
		return
	if current_hover and current_hover.has_method("set_outline"):
		current_hover.set_outline(false)
	current_hover = target
	if current_hover and current_hover.has_method("get_cursor"):
		CursorManager.set_state(current_hover.get_cursor())
	if current_hover and current_hover.has_method("set_outline"):
		current_hover.set_outline(true)
	if current_hover and current_hover.has_method("get_hover_text"):
		set_hover_text(current_hover.get_hover_text())
	else:
		set_hover_text("")

func clear_hover():
	if current_hover and current_hover.has_method("set_outline"):
		current_hover.set_outline(false)
	current_hover = null
	#CursorManager.set_state(CursorManager.CursorState.DEFAULT)
	set_hover_text("")
