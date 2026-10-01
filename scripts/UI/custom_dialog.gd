extends Control

signal button_pressed(index)

@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Title
@onready var message_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Message
@onready var buttons_container: HBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/HBoxContainer


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hide()


func show_dialog(
	title_text: String,
	message_text: String,
	buttons: Array
):

	title_label.text = title_text
	message_label.text = message_text

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


func _clear_buttons():

	for child in buttons_container.get_children():
		child.queue_free()


func _on_button_pressed(index):

	hide()
	button_pressed.emit(index)
