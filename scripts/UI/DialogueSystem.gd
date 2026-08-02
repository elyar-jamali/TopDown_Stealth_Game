extends Node

#var on_finish_callback = null
var timer: Timer = null
var ui = null


func register_ui(_ui):
	ui = _ui

func close_dialogue():
	if timer:
		timer.queue_free()
		timer = null

	if ui:
		ui.close()

	
func show_dialogue(icon:Texture2D ,key: String, duration := 0.0):
	var text = LocalizationManager.translate(key)
	if ui:
		ui.show_text(icon, text)
		# TIMED MODE
		if duration > 0:
			_start_timer(duration)

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

# -------------------------
# INPUT HANDLING
# -------------------------
func _unhandled_input(event):
	if ui == null:
		return
	# OK dialog (press to close)
	if event.is_action_pressed("ui_accept") or event is InputEventMouseButton:
		ui.close()
