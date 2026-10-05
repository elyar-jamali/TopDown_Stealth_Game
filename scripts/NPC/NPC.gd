extends CharacterBody3D

enum NPCType {
	Civilian_Male,
	Civilian_Female,
	Guard,
	Worker
}

@onready var collision := $CollisionShape3D
@onready var agent: NavigationAgent3D = $NavigationAgent3D
#@onready var animation_player: AnimationPlayer = $"Visual/NPC Femaled/AnimationPlayer"
@onready var animation_player: AnimationPlayer = $"Visual/NPC Female/AnimationPlayer"
@onready var vision_component = $VisionComponent

@export_group("Vision Settings")
@export_range(0.5, 60.0, 0.5)
var vision_distance: float = 12.0
@export_range(10.0, 170.0, 1.0)
var vision_horizontal_angle: float = 60.0
@export_range(10.0, 170.0, 1.0)
var vision_vertical_angle: float = 120.0
@export_range(0.1, 3.0, 0.05)
var vision_eye_height: float = 1.6
@export var vision_color: GameColors.Preset = GameColors.Preset.GREEN
@export var vision_opacity: GameColors.Opacity = GameColors.Opacity.NORMAL

@export_group("Vision Scan")
@export var vision_scan_enabled: bool = true
# این مقدار نیمه‌ی زاویه اسکن است.
# مثلا 30 یعنی از -30 تا +30 = مجموع 60 درجه.
@export_range(0.0, 90.0, 1.0)
var vision_scan_half_angle: float = 30.0
@export_range(0.0, 90.0, 1.0)
var vision_scan_speed: float = 15.0
@export_range(0.0, 5.0, 0.1)
var vision_scan_pause_time: float = 0.5

@export_group("Gameplay Properties")
## آیا Interaction معمولی با این آبجکت مجاز است؟
@export var interactable: bool = true
## آیا این آبجکت اجازه Outline شدن دارد؟
@export var highlightable: bool = true
## آیا بازیکن می‌تواند این Character را انتخاب و کنترل کند؟
@export var selectable: bool = false
## آیا Actionها و Skillها می‌توانند این آبجکت را Target کنند؟
@export var targetable: bool = true

#نوع npc
@export var npc_name := NPCType.Civilian_Male
@export var highlight_color: GameColors.Preset = GameColors.Preset.GREEN
@export var map_marker_color: GameColors.Preset = GameColors.Preset.RED
@onready var map_marker_fill: Polygon2D = $MapMarker/Fill
@export var can_talk := true
@export var hostile := false
@export var Icon_default = load("res://data/Pic/civil1.jpg")
@export var interaction_range := 0.0

@export_group("Target Rules")
@export var can_kill: bool = true
@export var can_knockout: bool = true
@export var gravity: float = 20.0


func _ready():
	_apply_vision_settings()
	map_marker_fill.color = GameColors.get_color(map_marker_color)
	if interaction_range <= 0:
		var shape = collision.shape

		if shape is CapsuleShape3D or shape is SphereShape3D:
			interaction_range = shape.radius * 6
		else:
			interaction_range = 1.5

	# تنظیمات NavigationAgent برای حرکت و Avoidance
	agent.avoidance_enabled = true
	agent.radius = 0.6
	agent.height = 1.8
	agent.neighbor_distance = 4.0
	agent.max_neighbors = 8
	agent.time_horizon_agents = 1.0
	#تست انیمیشن بعدا حذف میشود
	var animation := animation_player.get_animation("human_animations/F_talk")
	animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play("human_animations/F_talk")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.1

	velocity.x = 0.0
	velocity.z = 0.0

	move_and_slide()

	# NPC فعلاً ثابت است ولی Agent در Avoidance ثبت می‌ماند.
	agent.velocity = Vector3.ZERO

func get_outline_color() -> Color:
	return GameColors.get_color(highlight_color)

func get_hover_text():
	return "NPC" + var_to_str(npc_name)


func get_interaction_position():
	return collision.global_position


func interact():
	if hostile:
		_handle_hostile()

	if can_talk:
		_handle_talk()


func _handle_talk():
	DialogueSystem.show_dialogue(
		Icon_default,
		"npc_guard_hello"
	)


func _handle_hostile():
	DialogueSystem.show_dialogue(
		Icon_default,
		"npc_hostile_warning"
	)

func set_outline(enable: bool) -> void:
	var color := get_outline_color()

	if not highlightable:
		OutlineSystem.set_target(
			self,
			false,
			color
		)
		return

	OutlineSystem.set_target(
		self,
		enable,
		color
	)

func toggle_vision() -> void:
	var vision := get_node_or_null("VisionComponent")

	if vision != null:
		vision.toggle_vision()

func _apply_vision_settings() -> void:
	if vision_component == null:
		push_warning("VisionComponent not found on NPC: %s"	% name)
		return
	vision_component.vision_color = GameColors.get_color(vision_color, vision_opacity)
	vision_component.view_distance = (vision_distance)
	vision_component.horizontal_view_angle = (vision_horizontal_angle)
	vision_component.vertical_view_angle = (vision_vertical_angle)
	vision_component.eye_height = (vision_eye_height)
	
	if vision_scan_enabled:
		vision_component.scan_angle = (vision_scan_half_angle)
		vision_component.scan_speed = (vision_scan_speed)
		vision_component.scan_pause_time = (vision_scan_pause_time)
	else:
		vision_component.scan_angle = 0.0
