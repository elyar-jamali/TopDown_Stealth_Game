extends Node

var timer: Timer = null
var ui = null
var can_close := false

func register_ui(_ui):
	ui = _ui

func close_dialogue():
	if timer:
		timer.queue_free()
		timer = null

	if ui:
		ui.close()

func show_dialogue(icon: Texture2D, key: String, duration := 0.0):
	var text = LocalizationManager.translate(key)

	if ui:
		ui.show_text(icon, text)

	can_close = false
	_enable_close_next_frame()
	# حالت تایم دار
	if duration > 0:
		_start_timer(duration)

func _enable_close_next_frame():
	await get_tree().process_frame
	can_close = true

func _start_timer(duration: float):
	if timer:
		timer.queue_free()

	timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)

	timer.timeout.connect(_on_timer_end)
	timer.start()

func _on_timer_end():
	if ui:
		ui.close()

	timer = null

func _unhandled_input(event):
	if ui == null or not can_close:
		return

	if event.is_action_pressed("ui_accept"):
		close_dialogue()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close_dialogue()
