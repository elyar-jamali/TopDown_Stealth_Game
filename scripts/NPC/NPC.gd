extends Node3D
#extends CharacterBody3D

enum NPCType {
	Civilian_Male,
	Civilian_Female,
	Guard,
	Worker
}

@onready var collision := $NPC/CollisionShape3D
@onready var agent: NavigationAgent3D = $NPC/NavigationAgent3D
#@onready var animation_player: AnimationPlayer = $"Visual/NPC Femaled/AnimationPlayer"
@onready var animation_player: AnimationPlayer = $"NPC/Visual/NPC Female/AnimationPlayer"


@export_group("Gameplay Properties")
## آیا Interaction معمولی با این آبجکت مجاز است؟
@export var interactable: bool = true
## آیا این آبجکت اجازه Outline شدن دارد؟
@export var highlightable: bool = true
## آیا بازیکن می‌تواند این Character را انتخاب و کنترل کند؟
@export var selectable: bool = false
## آیا Actionها و Skillها می‌توانند این آبجکت را Target کنند؟
@export var targetable: bool = true
## رنگ اوتلاین
@export var outline_color: Color = Color.YELLOW
#نوع npc
@export var npc_name := NPCType.Civilian_Male
@export var can_talk := true
@export var hostile := false
@export var Icon_default = load("res://data/Pic/civil1.jpg")
@export var interaction_range := 0.0

@export_group("Target Rules")
@export var can_kill: bool = true
@export var can_knockout: bool = true

func _ready():
	
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

	var animation := animation_player.get_animation("human_animations/F_walk")
	animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play("human_animations/F_walk")

func _physics_process(_delta):
	# فعلاً NPC ثابت است، ولی Agent در سیستم Avoidance ثبت می‌ماند
	agent.velocity = Vector3.ZERO


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
	if not highlightable:
		OutlineSystem.set_target(self, false, outline_color)
		return

	OutlineSystem.set_target(self, enable, outline_color)
