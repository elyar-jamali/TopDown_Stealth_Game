extends Control

signal button_pressed(index)

@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Title
@onready var message_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Message
@onready var buttons_container: HBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/HBoxContainer

var cancel_button_index := -1


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER

	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()


func show_dialog(
	title_text: String,
	message_text: String,
	buttons: Array,
	cancel_index: int = -1
):
	title_label.text = title_text
	message_label.text = message_text
	cancel_button_index = cancel_index

	_clear_buttons()

	for i in range(buttons.size()):
		var button := Button.new()

		button.text = buttons[i]
		button.custom_minimum_size = Vector2(120, 40)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		button.pressed.connect(
			func():
				_on_button_pressed(i)
		)

		buttons_container.add_child(button)

	show()


func cancel() -> void:
	if not visible:
		return

	if cancel_button_index >= 0:
		_on_button_pressed(cancel_button_index)
	else:
		hide()


func _clear_buttons():
	for child in buttons_container.get_children():
		child.queue_free()


func _on_button_pressed(index):
	hide()

	cancel_button_index = -1

	button_pressed.emit(index)