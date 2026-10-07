extends CharacterBody3D

enum NPCType {
	Civilian_Male,
	Civilian_Female,
	Guard,
	Worker
}

enum PatrolMode {
	LOOP,
	PING_PONG,
	ONCE
}

@onready var collision := $CollisionShape3D
@onready var agent: NavigationAgent3D = $NavigationAgent3D
#@onready var animation_player: AnimationPlayer = $"Visual/NPC Femaled/AnimationPlayer"
@onready var animation_player: AnimationPlayer = $"Visual/NPC Female/AnimationPlayer"
@onready var vision_component = $VisionComponent

@export_group("Vision Settings")
@export_range(0.5, 60.0, 0.5) var vision_distance: float = 12.0
@export_range(10.0, 170.0, 1.0) var vision_horizontal_angle: float = 60.0
@export_range(10.0, 170.0, 1.0) var vision_vertical_angle: float = 120.0
@export_range(0.1, 3.0, 0.05) var vision_eye_height: float = 1.6
@export var vision_color: GameColors.Preset = GameColors.Preset.GREEN
@export var vision_opacity: GameColors.Opacity = GameColors.Opacity.NORMAL

@export_group("Vision Scan")
@export var vision_scan_enabled: bool = true
# این مقدار نیمه‌ی زاویه اسکن است.
# مثلا 30 یعنی از -30 تا +30 = مجموع 60 درجه.
@export_range(0.0, 90.0, 1.0) var vision_scan_half_angle: float = 30.0
@export_range(0.0, 90.0, 1.0) var vision_scan_speed: float = 15.0
@export_range(0.0, 5.0, 0.1) var vision_scan_pause_time: float = 0.5

@export_group("Animation Settings")
@export var animation_set: CharacterAnimationData.Set = CharacterAnimationData.Set.FEMALE

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

@export_group("Patrol Settings")
@export var patrol_enabled: bool = false
@export var patrol_route: PatrolRoute
@export var patrol_mode: PatrolMode = PatrolMode.LOOP
@export_range(0, 100, 1) var patrol_start_point: int = 0
@export_range(0.1, 10.0, 0.1) var patrol_speed: float = 2.0
@export_range(0.0, 10.0, 0.1) var patrol_wait_time: float = 0.5
@export_range(1.0, 20.0, 0.5) var patrol_turn_speed: float = 8.0

@export_group("Target Rules")
@export var can_kill: bool = true
@export var can_knockout: bool = true
@export var gravity: float = 20.0

var patrol_point_index := 0
var patrol_direction := 1
var patrol_waiting := false
var patrol_wait_remaining := 0.0
var patrol_running := false

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
	agent.path_desired_distance = 0.75
	agent.target_desired_distance = 0.1

	if not agent.velocity_computed.is_connected(_on_safe_velocity_computed):
		agent.velocity_computed.connect(_on_safe_velocity_computed)

	if patrol_enabled and patrol_route != null:
		call_deferred("start_patrol")
		
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	if not patrol_running:
		agent.velocity = Vector3.ZERO
		_play_action(CharacterAnimationData.Action.IDLE)
		return

	if patrol_waiting:
		agent.velocity = Vector3.ZERO
		_play_action(CharacterAnimationData.Action.IDLE)

		patrol_wait_remaining -= delta

		if patrol_wait_remaining <= 0.0:
			patrol_waiting = false
			_advance_patrol_point()

		return

	if agent.is_navigation_finished():
		if patrol_wait_time > 0.0 :
			agent.velocity = Vector3.ZERO
			_play_action(CharacterAnimationData.Action.IDLE)
			patrol_waiting = true
			patrol_wait_remaining = patrol_wait_time
		else:
			_advance_patrol_point()
		return

	var next_position := agent.get_next_path_position()
	var direction := next_position - global_position
	direction.y = 0.0

	if direction.length_squared() < 0.0001:
		agent.velocity = Vector3.ZERO
		return

	direction = direction.normalized()

	var target_rotation := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, patrol_turn_speed * delta)

	###_play_animation(walk_animation)
	agent.velocity = direction * patrol_speed

func get_hover_anchor_position() -> Vector3:
	var shape = collision.shape
	if shape is CapsuleShape3D:
		return collision.global_position + Vector3.UP * (shape.height * 0.5 + 0.2)
	return global_position + Vector3.UP * 2.0

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

func _play_action(action: CharacterAnimationData.Action, movement_speed: float = 0.0) -> void:
	var animation_name := CharacterAnimationData.get_animation(animation_set, action)
	var playback_speed := 1.0

	if movement_speed > 0.0:
		playback_speed = CharacterAnimationData.get_playback_speed(
			animation_set,
			action,
			movement_speed
		)

	_play_animation(animation_name, playback_speed)

##Patrol functions
func start_patrol() -> void:
	await get_tree().physics_frame

	if patrol_route == null:
		push_warning("PatrolRoute not assigned on NPC: %s" % name)
		return

	var point_count := patrol_route.get_point_count()

	if point_count < 2:
		push_warning("PatrolRoute needs at least 2 points: %s" % patrol_route.name)
		return

	patrol_point_index = clampi(patrol_start_point, 0, point_count - 1)
	patrol_direction = 1
	patrol_waiting = false
	patrol_wait_remaining = 0.0
	patrol_running = true

	_set_patrol_target()

func stop_patrol() -> void:
	patrol_running = false
	patrol_waiting = false
	patrol_wait_remaining = 0.0
	agent.velocity = Vector3.ZERO
	agent.target_position = global_position


func _set_patrol_target() -> void:
	if patrol_route == null:
		return

	agent.target_position = patrol_route.get_point_position(patrol_point_index)


func _advance_patrol_point() -> void:
	if patrol_route == null:
		stop_patrol()
		return

	var point_count := patrol_route.get_point_count()

	match patrol_mode:
		PatrolMode.LOOP:
			patrol_point_index = (patrol_point_index + 1) % point_count

		PatrolMode.PING_PONG:
			patrol_point_index += patrol_direction

			if patrol_point_index >= point_count:
				patrol_direction = -1
				patrol_point_index = point_count - 2
			elif patrol_point_index < 0:
				patrol_direction = 1
				patrol_point_index = 1

		PatrolMode.ONCE:
			if patrol_point_index >= point_count - 1:
				stop_patrol()
				return

			patrol_point_index += 1

	_set_patrol_target()

func _on_safe_velocity_computed(safe_velocity: Vector3) -> void:
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide()
	if patrol_running and not patrol_waiting:
		var real_velocity := get_real_velocity()
		var actual_speed := Vector2(real_velocity.x, real_velocity.z).length()

		if actual_speed > 0.05:
			_play_action(
				CharacterAnimationData.Action.WALK,
				actual_speed
			)

func _play_animation(animation_name: StringName, playback_speed: float = 1.0) -> void:
	if animation_name == &"":
		return

	if not animation_player.has_animation(animation_name):
		push_warning("Animation not found: %s" % animation_name)
		return

	animation_player.speed_scale = playback_speed

	if animation_player.current_animation == animation_name:
		return

	animation_player.play(animation_name)

