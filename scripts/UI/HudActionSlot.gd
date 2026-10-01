extends HBoxContainer

signal pressed

@export var icon_on_right := false

@onready var info_box: VBoxContainer = $InfoBox

@onready var action_button: Button = $Control/ButtonMargin/ActionButton
@onready var icon_texture: TextureRect = $Control/ButtonMargin/ActionButton/IconMargin/Icon
@onready var shortcut_label: Label = $InfoBox/ShortcutLabel
@onready var count_label: Label = $InfoBox/CountLabel
@onready var icon_container: Control = $Control

func _ready() -> void:
	if not action_button.pressed.is_connected(_on_action_button_pressed):
		action_button.pressed.connect(_on_action_button_pressed)
	if icon_on_right:
		move_child(info_box, 0)
		move_child(icon_container, 1)

		shortcut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func setup_action(icon: Texture2D, shortcut: String, count: String = "", tooltip: String = ""):
	set_icon(icon)
	set_shortcut(shortcut)
	set_count(count)
	action_button.tooltip_text = tooltip

func _on_action_button_pressed() -> void:
	pressed.emit()


func set_icon(texture: Texture2D) -> void:
	icon_texture.texture = texture


func set_shortcut(text: String) -> void:
	shortcut_label.text = text


func set_count(text: String) -> void:
	count_label.text = text


func set_disabled(value: bool) -> void:
	action_button.disabled = value

func set_selected(value: bool):
	action_button.modulate = Color(1.2,1.2,1.2) if value else Color(1,1,1)
