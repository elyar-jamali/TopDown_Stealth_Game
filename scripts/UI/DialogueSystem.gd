extends Node

var timer: Timer = null
var ui = null
var can_close := false
var dialogue_paused_game := false
var dialogue_open := false


func register_ui(_ui):
	ui = _ui

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func close_dialogue() -> void:
	if not dialogue_open:
		return

	dialogue_open = false
	can_close = false

	if timer != null:
		timer.stop()
		timer.queue_free()
		timer = null

	if ui != null:
		ui.close()

	if dialogue_paused_game:
		dialogue_paused_game = false
		get_tree().paused = false


func show_dialogue(icon: Texture2D, key: String, duration: float = 0.0) -> void:
	# اگر پیام قبلی هنوز باز است، ابتدا آن را ببند.
	if dialogue_open:
		close_dialogue()

	var translated_text = LocalizationManager.translate(key)

	if ui == null:
		return

	HoverSystem.clear_hover()
	ui.show_text(icon, translated_text)

	dialogue_open = true
	can_close = false

	_enable_close_next_frame()

	if duration > 0.0:
		# پیام اطلاع‌رسانی: بازی ادامه دارد.
		_start_timer(duration)
	else:
		# گفتگوی معمولی: بازی متوقف می‌شود.
		dialogue_paused_game = true
		get_tree().paused = true


func _enable_close_next_frame() -> void:
	await get_tree().process_frame

	if dialogue_open:
		can_close = true


func _start_timer(duration: float) -> void:
	timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true

	add_child(timer)

	timer.timeout.connect(_on_timer_end)
	timer.start()


func _on_timer_end() -> void:
	close_dialogue()


func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_open or not can_close:
		return

	if event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		close_dialogue()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_interact"):
		close_dialogue()
		get_viewport().set_input_as_handled()