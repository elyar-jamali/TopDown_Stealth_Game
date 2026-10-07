extends Control
@onready var icon: TextureRect = $CursorIcon
var tex_default = preload("res://data/cursor/cursor_default.png")
var tex_interact = preload("res://data/cursor/cursor_hand.png")
var tex_rotate = preload("res://data/cursor/cursor_rotate.png")
var tex_crossair = preload("res://data/cursor/cursor_crossair.png")
var tex_locked = preload("res://data/cursor/cursor_locked.png")
var hotspot = Vector2(0, 0)
@onready var hover_label: Label = $HoverLabel

func update_hover_text(text: String):
	hover_label.text = text

func _ready():
	# موس واقعی سیستم رو مخفی می‌کنیم (همیشه)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	CursorManager.register_ui(self)
	# تنظیمات UI کاملاً از کد
	icon.texture = tex_default
	_setup_icon("topleft")
	HoverSystem.register_ui(self)
	
func _setup_icon(mainspot):
	# جلوگیری از دریافت input
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# اندازه ثابت (مثل بازی‌های حرفه‌ای)
	icon.size = Vector2(32, 32)
	# تنظیم نقطه مهم هر کرسر نصبت به موس
	match mainspot:
		"topleft":
			hotspot = Vector2(0, 0)
			#icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			#icon.set_offsets_preset(Control.PRESET_TOP_LEFT)
		"center":
			hotspot = Vector2(16, 16)
			#icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func _process(_delta):
	global_position = get_viewport().get_mouse_position() - hotspot

	var text_size := hover_label.get_minimum_size()
	var target = HoverSystem.current_hover

	if target != null and target.has_method("get_hover_anchor_position"):
		var camera := get_viewport().get_camera_3d()

		if camera != null:
			var world_position: Vector3 = target.get_hover_anchor_position()
			var screen_position := camera.unproject_position(world_position)

			hover_label.global_position = Vector2(
				screen_position.x - text_size.x * 0.5,
				screen_position.y - text_size.y
			)
			return

	hover_label.position = Vector2(
		-text_size.x * 0.5 + hotspot.x,
		-30
	)

func update_cursor(state):
	match state:
		CursorManager.CursorState.DEFAULT:
			icon.texture = tex_default
			_setup_icon("topleft")
		CursorManager.CursorState.INTERACT:
			icon.texture = tex_interact
			_setup_icon("center")
		CursorManager.CursorState.ROTATE:
			icon.texture = tex_rotate
			_setup_icon("center")
		CursorManager.CursorState.AIM:
			icon.texture = tex_crossair
			_setup_icon("center")
		CursorManager.CursorState.LOCKED:
			icon.texture = tex_locked
			_setup_icon("center")
			
