extends Control

@onready var panel = $Panel
@onready var label = $Panel/Label
@onready var button = $Panel/OkButton
@onready var picture = $Panel/OkButton/Picture

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	DialogueSystem.register_ui(self)
	if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
		ThemeManager.theme_changed.connect(_on_theme_changed)
	_apply_theme(ThemeManager.get_current_theme())
	hide()
	button.pressed.connect(_on_button_pressed)
	
func _on_button_pressed():
	DialogueSystem.close_dialogue()
	
func show_text(icon, text):
	label.text = text
	picture.texture = icon
	$Panel.size = Vector2(800, 150)
	$Panel.position = Vector2(100, 500)
	show()
	call_deferred("_update_layout")

func _update_layout():
	var screen = get_viewport_rect().size
	panel.size = Vector2(screen.x * 0.8,screen.y * 0.2)
	panel.position = Vector2(
		(screen.x - panel.size.x) * 0.5, screen.y - panel.size.y - 30)
	label.position.x = (panel.size.x - label.size.x + panel.size.y) * 0.5
	label.position.y = (panel.size.y - label.size.y) * 0.5
	
	button.size = panel.size
	button.position = Vector2(0, 0)
	
	picture.size = Vector2(panel.size.y * 0.8,panel.size.y * 0.8)
	picture.position.x = (panel.size.y - picture.size.y) * 0.5
	picture.position.y = (panel.size.y - picture.size.y) * 0.5

func _on_theme_changed(_theme_id: String, theme_resource: Theme):
	_apply_theme(theme_resource)

func _apply_theme(theme_resource: Theme):
	theme = theme_resource
	panel.theme_type_variation = &"DialoguePanel"
	
func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		
func close():
	hide()
