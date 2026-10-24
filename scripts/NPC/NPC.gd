extends CharacterBody3D

############################Character Visual############################
enum CharacterAppearance {
	MALE_SUIT,
	MALE_WORKER,
	FEMALE_CASUAL,
	FEMALE_ELEGANT
}
@export_group("Character Visual")
@export var character_appearance: CharacterAppearance = CharacterAppearance.MALE_SUIT

@onready var animation_controller: CharacterAnimationController = $CharacterAnimationController
@onready var animation_player: AnimationPlayer = animation_controller.animation_player
@onready var ragdoll_driver: PhysicalBoneSimulator3D = find_child(
	"PhysicalBoneSimulator3D", true, false
) as PhysicalBoneSimulator3D

const CHARACTER_VISUALS: Array[PackedScene] = [
	preload("res://scenes/characters/male_visual.tscn"),
	preload("res://scenes/characters/female_visual.tscn")
]
const APPEARANCE_SCENES: Array[PackedScene] = [
	preload("res://data/characters/appearances/male_suit/male_suit_appearance.tscn"),
	preload("res://data/characters/appearances/male_worker/male_worker_appearance.tscn"),
	preload("res://data/characters/appearances/female_casual/female_casual_appearance.tscn"),
	preload("res://data/characters/appearances/female_elegant/female_elegant_appearance.tscn")
]
############################Vision Settings############################
@export_group("Vision Settings")
@export_range(0.5, 60.0, 0.5) var vision_distance: float = 12.0
@export_range(10.0, 170.0, 1.0) var vision_horizontal_angle: float = 60.0
@export_range(10.0, 170.0, 1.0) var vision_vertical_angle: float = 120.0
@export_range(0.1, 3.0, 0.05) var vision_eye_height: float = 1.6
@export var vision_color: GameColors.Preset = GameColors.Preset.GREEN
@export var vision_opacity: GameColors.Opacity = GameColors.Opacity.NORMAL
#@export_group("Vision Scan")
@export var vision_scan_enabled: bool = true
# این مقدار نیمه‌ی زاویه اسکن است.
# مثلا 30 یعنی از -30 تا +30 = مجموع 60 درجه.
@export_range(0.0, 90.0, 1.0) var vision_scan_half_angle: float = 30.0
@export_range(0.0, 90.0, 1.0) var vision_scan_speed: float = 15.0
@export_range(0.0, 5.0, 0.1) var vision_scan_pause_time: float = 0.5

@onready var vision_component = $VisionComponent
############################Map & Animation Settings############################
@export_group("Map Marker")
@export var map_marker_color: GameColors.Preset = GameColors.Preset.RED
@onready var map_marker_fill: Polygon2D = $MapMarker/Fill
############################Knockout & Status Bar############################
@export_group("Knockout & Status Bar")
@export_range(1.0, 300.0, 1.0) var knockout_duration: float = 30.0
@export var knockout_bar_color: GameColors.Preset = GameColors.Preset.YELLOW

@onready var status_bar_3d: Sprite3D = $StatusBar3D
@onready var status_viewport: SubViewport = $StatusBar3D/StatusViewport
@onready var status_progress: ProgressBar = $StatusBar3D/StatusViewport/ProgressBar

var knockout_time_remaining: float = 0.0
var status_fill_style: StyleBoxFlat
var is_waking_up: bool = false
############################Alert System############################
@export_group("Alert System")
@export_range(1.0, 120.0, 1.0) var alert_duration: float = 12.0
@export_range(1.0, 20.0, 0.5) var alert_search_radius: float = 6.0
@export_range(1.0, 3.0, 0.1) var alert_speed_multiplier: float = 1.5
@export_range(1.0, 4.0, 0.1) var alert_scan_speed_multiplier: float = 2.0
@export var alert_bar_color: GameColors.Preset = GameColors.Preset.ORANGE

@onready var alert_behavior: AlertBehavior = $AlertBehavior
############################NPC Identity & Interaction############################
enum NPCType {
	Male_Suit,
	Female_Casual,
	Guard,
	Worker
}
@export_group("NPC Identity & Interaction")
## آیا بازیکن می‌تواند این Character را انتخاب و کنترل کند؟
@export var selectable: bool = false
## آیا Interaction معمولی با این آبجکت مجاز است؟
@export var interactable: bool = true
## آیا این آبجکت اجازه Outline شدن دارد؟
@export var highlightable: bool = true
@export var highlight_color: GameColors.Preset = GameColors.Preset.GREEN
@export var npc_name := NPCType.Male_Suit
@export var Icon_default = load("res://data/Pic/civil1.jpg")
@export var interaction_range := 0.0

############################Patrol & Navigation############################
enum PatrolMode {
	LOOP,
	PING_PONG,
	ONCE
}
@export_group("Patrol & Navigation")
@export var patrol_enabled: bool = false
@export var patrol_route: PatrolRoute
@export var patrol_mode: PatrolMode = PatrolMode.LOOP
@export_range(0, 100, 1) var patrol_start_point: int = 0
@export_range(0.1, 10.0, 0.1) var patrol_speed: float = 2.0
@export_range(0.0, 10.0, 0.1) var patrol_wait_time: float = 0.5
@export_range(1.0, 20.0, 0.5) var patrol_turn_speed: float = 8.0

@onready var agent: NavigationAgent3D = $NavigationAgent3D
var patrol_point_index := 0
var patrol_direction := 1
var patrol_waiting := false
var patrol_wait_remaining := 0.0
var patrol_running := false
var previous_position := Vector3.ZERO

############################NPC State & Target Rules############################
enum NPCState {
	ALIVE,
	UNCONSCIOUS,
	DEAD
}
enum NPCBehavior {
	NORMAL,
	ALERT
}
@export_group("NPC State & Target Rules")
## آیا Actionها و Skillها می‌توانند این آبجکت را Target کنند؟
@export var targetable: bool = true
@export var can_kill: bool = true
@export var can_knockout: bool = true
@export var can_talk := true
@export var hostile := false

var npc_state: NPCState = NPCState.ALIVE
var npc_behavior: NPCBehavior = NPCBehavior.NORMAL

############################Ragdoll & Wakeup############################
@export_group("Ragdoll & Wakeup")
@export_range(0.10, 1.5, 0.05) var wake_blend_duration: float = 1.5
@export_range(0.0, 1.0, 0.05) var knockout_impact_delay: float = 0.35
@export_range(0.5, 6.0, 0.25) var head_impact_strength: float = 3.0

var _ragdoll_mode: bool = false
var _wake_blending: bool = false
var _wake_blend_elapsed: float = 0.0
var _wake_source_poses: Array[Transform3D] = []
var _wake_target_poses: Array[Transform3D] = []
var _wake_root_start: Vector3 = Vector3.ZERO
var _wake_root_target: Vector3 = Vector3.ZERO
var _wake_yaw_start: float = 0.0
var _wake_yaw_target: float = 0.0
var _wake_animation: StringName = &""
var _wake_action: CharacterAnimationController.Action = CharacterAnimationController.Action.WAKEUP_FRONT

############################Physics & Collision############################
@export_group("Physics & Collision")
@export var gravity: float = 10.0

@onready var collision := $CollisionShape3D
@onready var standing_collision_rotation: Vector3 = collision.rotation_degrees
@onready var standing_collision_position: Vector3 = collision.position

############################Navigation Recovery & Detour############################
var stuck_time_limit := 0.10
var stuck_move_threshold := 0.01
var detour_reach_distance := 0.12
var stuck_time := 0.0
var detour_points: Array[Vector3] = []
var detour_index := 0
var is_using_detour := false
var is_using_short_escape := false
var short_escape_points: Array[Vector3] = []
var short_escape_index := 0
var short_escape_velocity := Vector3.ZERO
var short_escape_stuck_time := 0.0
var short_escape_attempts := 0
var detour_retry_delay := 0.0

############################Functions############################

func _ready():
	_apply_character_visual()
	set_process(false)
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
	agent.radius = _get_collision_radius() + 0.05
	agent.height = 1.8
	agent.neighbor_distance = 4.0
	agent.max_neighbors = 8
	agent.time_horizon_agents = 1.0
	agent.avoidance_priority = 1.0
	agent.path_desired_distance = 0.75
	agent.target_desired_distance = 0.1
	if not agent.velocity_computed.is_connected(_on_safe_velocity_computed):
		agent.velocity_computed.connect(_on_safe_velocity_computed)
	
	previous_position = global_position
	if patrol_enabled and patrol_route != null:
		call_deferred("start_patrol")
	
	status_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	status_bar_3d.texture = status_viewport.get_texture()
	status_bar_3d.hide()
	status_progress.min_value = 0.0
	status_progress.max_value = knockout_duration
	status_progress.value = knockout_duration
	var original_fill := status_progress.get_theme_stylebox("fill")
	if original_fill is StyleBoxFlat:
		status_fill_style = original_fill.duplicate() as StyleBoxFlat
		status_progress.add_theme_stylebox_override(
			"fill",
			status_fill_style
		)
	else:
		push_warning("StatusBar fill must be StyleBoxFlat")

	alert_behavior.alert_finished.connect(_on_alert_finished)
	animation_player.animation_finished.connect(_on_npc_animation_finished)
	
	if ragdoll_driver != null:
		for bone in ragdoll_driver.get_children():
			if bone is PhysicalBone3D:
				add_collision_exception_with(bone)
				bone.add_collision_exception_with(self)


func _physics_process(delta: float) -> void:
	if _ragdoll_mode:
		if not is_waking_up:
			_update_knockout_timer(delta)
		return

	_update_knockout_timer(delta)
	alert_behavior.update_alert(delta)
	if npc_behavior == NPCBehavior.ALERT:
		status_progress.value = alert_behavior.time_remaining

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1
	if not is_alive():# or not patrol_running:
		agent.velocity = Vector3.ZERO
		#_play_action(CharacterAnimationController.Action.IDLE)
		previous_position = global_position
		return
	if not patrol_running:
		agent.velocity = Vector3.ZERO
		_play_action(CharacterAnimationController.Action.IDLE)
		previous_position = global_position
		return
	if patrol_waiting:
		agent.velocity = Vector3.ZERO
		_play_action(CharacterAnimationController.Action.IDLE)
		patrol_wait_remaining -= delta
		if patrol_wait_remaining <= 0.0:
			patrol_waiting = false
			_advance_patrol_point()
		previous_position = global_position
		return
	if is_using_short_escape:
		_update_short_escape(delta)
		previous_position = global_position
		return
	if is_using_detour:
		if detour_points.size() > 0:
			if _horizontal_distance(global_position, detour_points[detour_index]) <= detour_reach_distance:
				detour_index += 1
				if detour_index >= detour_points.size():
					_finish_detour()
				else:
					agent.target_position = detour_points[detour_index]
	if not is_using_detour and agent.is_navigation_finished():
		if patrol_wait_time > 0.0:
			agent.velocity = Vector3.ZERO
			_play_action(CharacterAnimationController.Action.IDLE)
			patrol_waiting = true
			patrol_wait_remaining = patrol_wait_time
		else:
			_advance_patrol_point()
		previous_position = global_position
		return
	var next_position := agent.get_next_path_position()
	var direction := next_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		agent.velocity = Vector3.ZERO
		_update_stuck_state(delta)
		previous_position = global_position
		return
	direction = direction.normalized()
	var target_rotation := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, patrol_turn_speed * delta)
	agent.velocity = direction * patrol_speed
	_update_stuck_state(delta)
	previous_position = global_position

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
	if not is_alive():
		return
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
	if not is_alive():
		return
	if vision_component != null:
		vision_component.toggle_vision()

func _apply_vision_settings() -> void:
	if vision_component == null:
		push_warning("VisionComponent not found on NPC: %s" % name)
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

func _play_action(action: CharacterAnimationController.Action, movement_speed: float = 0.0) -> void:
	if animation_controller == null:
		return
	animation_controller.play_action(action, -1.0, movement_speed)

func _get_collision_radius() -> float:
	if collision.shape is CapsuleShape3D:
		var capsule := collision.shape as CapsuleShape3D
		return capsule.radius
	if collision.shape is SphereShape3D:
		var sphere := collision.shape as SphereShape3D
		return sphere.radius
	return 0.3

func _horizontal_distance(point_a: Vector3, point_b: Vector3) -> float:
	return Vector2(point_a.x, point_a.z).distance_to(Vector2(point_b.x, point_b.z))

func _update_stuck_state(delta: float) -> void:
	if detour_retry_delay > 0.0:
		detour_retry_delay = maxf(detour_retry_delay - delta, 0.0)
		return
	var moved_distance := _horizontal_distance(global_position, previous_position)
	var wants_to_move := _horizontal_distance(
		global_position,
		agent.target_position
	) > agent.target_desired_distance
	if wants_to_move and moved_distance < stuck_move_threshold:
		stuck_time += delta
	else:
		stuck_time = 0.0
	var time_limit: float = 0.35 if is_using_detour else stuck_time_limit
	if stuck_time >= time_limit:
		stuck_time = 0.0
		if is_using_detour:
			_clear_detour()
			_set_patrol_target()
			detour_retry_delay = 0.5
		else:
			_create_detour()

func _create_detour() -> void:
	if patrol_route == null:
		return
	var navigation_map := agent.get_navigation_map()
	if not navigation_map.is_valid():
		return
	var path_direction := agent.get_next_path_position() - global_position
	path_direction.y = 0.0
	if path_direction.length_squared() <= 0.0001:
		return
	path_direction = path_direction.normalized()
	var patrol_target: Vector3 = patrol_route.get_point_position(patrol_point_index)
	var blocking_line := DetourPlanner.get_blocking_collision_line(self, collision)
	var planned_path: Array[Vector3] = DetourPlanner.find_path(
		self,
		collision,
		agent,
		patrol_target,
		path_direction,
		blocking_line
	)
	if not planned_path.is_empty():
		detour_points = planned_path
		detour_index = 0
		is_using_detour = true
		agent.target_position = detour_points[0]
		return
	if short_escape_attempts >= 2:
		short_escape_attempts = 0
		detour_retry_delay = 2.0
		return
	short_escape_attempts += 1
	var escape_path: Array[Vector3] = DetourPlanner.find_short_escape(
		self,
		collision,
		agent,
		path_direction
	)
	if escape_path.is_empty():
		detour_retry_delay = 0.5
		return
	short_escape_points = escape_path
	short_escape_index = 0
	short_escape_stuck_time = 0.0
	short_escape_velocity = Vector3.ZERO
	is_using_short_escape = true
	agent.velocity = Vector3.ZERO

func _update_short_escape(delta: float) -> void:
	var moved_distance := _horizontal_distance(global_position, previous_position)
	if short_escape_velocity.length_squared() > 0.0001 and moved_distance < 0.005:
		short_escape_stuck_time += delta
	else:
		short_escape_stuck_time = 0.0
	if short_escape_stuck_time >= 0.25:
		_finish_short_escape(false)
		return
	while short_escape_index < short_escape_points.size():
		var target: Vector3 = short_escape_points[short_escape_index]
		if _horizontal_distance(global_position, target) > 0.04:
			break
		short_escape_index += 1
	if short_escape_index >= short_escape_points.size():
		_finish_short_escape(true)
		return
	var direction: Vector3 = short_escape_points[short_escape_index] - global_position
	direction.y = 0.0
	var remaining_distance: float = direction.length()
	direction = direction.normalized()
	var target_rotation := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, patrol_turn_speed * delta)
	var allowed_speed: float = minf(patrol_speed, remaining_distance / maxf(delta, 0.0001))
	short_escape_velocity = direction * allowed_speed
	agent.velocity = short_escape_velocity

func _finish_short_escape(completed: bool) -> void:
	_clear_short_escape()
	stuck_time = 0.0
	agent.velocity = Vector3.ZERO
	_set_patrol_target()
	if not completed:
		detour_retry_delay = 0.5

func _clear_short_escape() -> void:
	is_using_short_escape = false
	short_escape_points.clear()
	short_escape_index = 0
	short_escape_velocity = Vector3.ZERO
	short_escape_stuck_time = 0.0

func _clear_detour() -> void:
	is_using_detour = false
	detour_points.clear()
	detour_index = 0

func _finish_detour() -> void:
	_clear_detour()
	stuck_time = 0.0
	_set_patrol_target()

func is_alive() -> bool:
	return npc_state == NPCState.ALIVE


func knockout() -> void:
	if not is_alive() or not can_knockout:
		return

	knockout_time_remaining = knockout_duration

	_set_npc_state(NPCState.UNCONSCIOUS)

	status_progress.max_value = knockout_duration
	status_progress.value = knockout_duration
	_set_status_bar_color(knockout_bar_color)
	status_bar_3d.show()


func kill() -> void:
	if npc_state == NPCState.DEAD or not can_kill:
		return

	knockout_time_remaining = 0.0
	status_bar_3d.hide()

	is_waking_up = false
	_set_npc_state(NPCState.DEAD)


func _set_npc_state(new_state: NPCState) -> void:
	if npc_state == new_state:
		return

	npc_state = new_state

	if not is_alive():
		if alert_behavior.active:
			npc_behavior = NPCBehavior.NORMAL
			alert_behavior.stop_alert()
		stop_patrol()

		agent.avoidance_enabled = false

		if vision_component != null:
			if VisionManager.active_vision == vision_component:
				VisionManager.clear_vision()

			vision_component.set_process(false)
			vision_component.set_physics_process(false)

	else:
		# NPC دوباره زنده شده است.
		agent.avoidance_enabled = true

		if vision_component != null:
			vision_component.set_process(true)
			vision_component.set_physics_process(true)

##Patrol functions

func start_patrol() -> void:
	if not is_alive():
		return
	await get_tree().physics_frame
	if not is_alive():
		return
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
	stuck_time = 0.0
	_clear_detour()
	_clear_short_escape()
	short_escape_attempts = 0
	detour_retry_delay = 0.0
	previous_position = global_position
	_set_patrol_target()

func stop_patrol() -> void:
	patrol_running = false
	patrol_waiting = false
	patrol_wait_remaining = 0.0
	stuck_time = 0.0
	_clear_detour()
	_clear_short_escape()
	short_escape_attempts = 0
	detour_retry_delay = 0.0
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
	short_escape_attempts = 0
	detour_retry_delay = 0.0
	_set_patrol_target()

func resume_patrol_from_nearest_point() -> void:
	if not is_alive():
		return

	if patrol_route == null:
		return

	var point_count: int = patrol_route.get_point_count()

	if point_count < 2:
		return

	# پیدا کردن نزدیک‌ترین نقطه Patrol
	var nearest_index: int = 0
	var nearest_distance: float = INF

	for i in range(point_count):
		var point_position: Vector3 = patrol_route.get_point_position(i)

		var distance: float = Vector2(
			global_position.x,
			global_position.z
		).distance_squared_to(
			Vector2(point_position.x, point_position.z)
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i

	# انتخاب نزدیک‌ترین نقطه
	patrol_point_index = nearest_index

	# آماده‌سازی مجدد Patrol
	patrol_waiting = false
	patrol_wait_remaining = 0.0
	patrol_running = true

	stuck_time = 0.0

	_clear_detour()
	_clear_short_escape()

	short_escape_attempts = 0
	detour_retry_delay = 0.0

	previous_position = global_position

	# حرکت به نزدیک‌ترین نقطه
	_set_patrol_target()

func _on_safe_velocity_computed(safe_velocity: Vector3) -> void:
	if _ragdoll_mode:
		return
	var applied_velocity: Vector3 = safe_velocity
	if is_using_short_escape:
		applied_velocity = short_escape_velocity
	if not is_alive() or not patrol_running or patrol_waiting:
		applied_velocity = Vector3.ZERO
	velocity.x = applied_velocity.x
	velocity.z = applied_velocity.z
	move_and_slide()
	if patrol_running and not patrol_waiting:
		var real_velocity := get_real_velocity()
		var actual_speed := Vector2(real_velocity.x, real_velocity.z).length()
		if actual_speed > 0.05:
			_play_action(
				CharacterAnimationController.Action.WALK,
				actual_speed
			)


func _play_animation(animation_name: StringName, playback_speed: float = 1.0) -> void:
	if animation_name == &"":
		return

	if animation_controller == null:
		push_warning("Animation controller not found.")
		return

	animation_controller.play_named(
		animation_name,
		-1.0,
		playback_speed
	)



func _update_knockout_timer(delta: float) -> void:
	if npc_state != NPCState.UNCONSCIOUS:
		return

	# هنگام اجرای Wakeup دیگر تایمر بیهوشی را بررسی نکن.
	if is_waking_up:
		return

	knockout_time_remaining = maxf(
		knockout_time_remaining - delta,
		0.0
	)

	status_progress.value = knockout_time_remaining

	if knockout_time_remaining <= 0.0:
		_wake_up()
		# بیدارشدن NPC را در مرحله بعد اضافه می‌کنیم.

func _wake_up() -> void:
	if npc_state != NPCState.UNCONSCIOUS or is_waking_up:
		return

	if ragdoll_driver == null:
		return

	# Wait for the freeze stage to finish: do not read a moving skeleton.
	if ragdoll_driver.get("ragdoll_active") == true:
		return
	if ragdoll_driver.get("pose_frozen") != true:
		return

	var skeleton := ragdoll_driver.get_skeleton()
	if skeleton == null:
		return

	_wake_action = CharacterAnimationController.Action.WAKEUP_FRONT

	if _is_fallen_on_back(skeleton):
		_wake_action = CharacterAnimationController.Action.WAKEUP_BACK

	_wake_animation = animation_controller.get_animation(_wake_action)

	if _wake_animation == &"" or not animation_player.has_animation(_wake_animation):
		push_error("Wakeup animation not found: " + str(_wake_animation))
		return

	is_waking_up = true
	knockout_time_remaining = 0.0
	status_bar_3d.hide()

	_wake_source_poses.clear()
	_wake_target_poses.clear()
	for i in range(skeleton.get_bone_count()):
		_wake_source_poses.append(skeleton.get_bone_pose(i))

	var hip_index := skeleton.find_bone("Hips")
	var hip_before := Vector3.ZERO
	if hip_index >= 0:
		hip_before = skeleton.to_global(skeleton.get_bone_global_pose(hip_index).origin)

	_wake_yaw_start = rotation.y
	_wake_yaw_target = _wake_yaw_start

	# Sample the first animation frame while keeping it paused.
	animation_player.play(_wake_animation, 0.0)
	animation_player.seek(0.0, true)
	animation_player.pause()
	for i in range(skeleton.get_bone_count()):
		_wake_target_poses.append(skeleton.get_bone_pose(i))

	_wake_root_start = global_position
	_wake_root_target = global_position
	if hip_index >= 0:
		var animated_hip_world := skeleton.to_global(skeleton.get_bone_global_pose(hip_index).origin)
		var animated_hip_offset := animated_hip_world - global_position
		var yaw_delta := wrapf(_wake_yaw_target - _wake_yaw_start, -PI, PI)
		var rotated_offset := Basis(Vector3.UP, yaw_delta) * animated_hip_offset
		_wake_root_target.x = hip_before.x - rotated_offset.x
		_wake_root_target.z = hip_before.z - rotated_offset.z

	for i in range(_wake_source_poses.size()):
		skeleton.set_bone_pose(i, _wake_source_poses[i])

	_wake_blending = true
	_wake_blend_elapsed = 0.0
	set_process(true)

func _start_alert(
	reason: AlertBehavior.AlertReason,
	position: Vector3,
	target: Node3D = null
) -> void:
	if not is_alive():
		return

	npc_behavior = NPCBehavior.ALERT

	stop_patrol()

	alert_behavior.start_alert(
		reason,
		alert_duration,
		position,
		target
	)

	_set_status_bar_color(alert_bar_color)

	status_progress.min_value = 0.0
	status_progress.max_value = alert_behavior.duration
	status_progress.value = alert_behavior.time_remaining

	status_bar_3d.show()


func _on_alert_finished() -> void:
	if npc_behavior != NPCBehavior.ALERT:
		return

	npc_behavior = NPCBehavior.NORMAL
	status_bar_3d.hide()

	if is_alive() and patrol_enabled:
		resume_patrol_from_nearest_point()

func _set_status_bar_color(color_preset: GameColors.Preset) -> void:
	if status_fill_style == null:
		return

	status_fill_style.bg_color = GameColors.get_color(color_preset)


func _on_npc_animation_finished(animation_name: StringName) -> void:
	var garroted_animation := animation_controller.get_animation(
		CharacterAnimationController.Action.GARROTED
	)
	if animation_name == garroted_animation and npc_state == NPCState.DEAD:
		start_garrote_ragdoll()
		return

	var wakeup_front := animation_controller.get_animation(
		CharacterAnimationController.Action.WAKEUP_FRONT
	)
	var wakeup_back := animation_controller.get_animation(
		CharacterAnimationController.Action.WAKEUP_BACK
	)
	if animation_name != wakeup_front and animation_name != wakeup_back:
		return
	if not is_waking_up or npc_state != NPCState.UNCONSCIOUS:
		return

	is_waking_up = false
	set_collision_standing()
	_set_npc_state(NPCState.ALIVE)
	animation_controller.play_action(CharacterAnimationController.Action.IDLE, 0.3)

	_ragdoll_mode = false
	ragdoll_driver.set("pose_frozen", false)
	collision.set_deferred("disabled", false)

	_start_alert(AlertBehavior.AlertReason.WAKE_UP, global_position)

func align_for_garrote(attacker: Node3D) -> void:
	if not is_alive():
		return

	var direction := global_position - attacker.global_position
	direction.y = 0.0

	if direction.length_squared() < 0.0001:
		return

	# جهت گارد از بازیکن به سمت جلو باشد.
	rotation.y = atan2(direction.x, direction.z)

func play_garroted() -> void:
	animation_controller.play_action(CharacterAnimationController.Action.GARROTED)

func set_collision_lying() -> void:
	var capsule := collision.shape as CapsuleShape3D

	if capsule == null:
		return

	var half_height := capsule.height * 0.5
	var offset := half_height - capsule.radius

	# مقدار جابه‌جایی اضافی به سمت جلوی گارد
	const FORWARD_OFFSET := 0.5

	# خواباندن کپسول در راستای بدن گارد
	collision.rotation_degrees = standing_collision_rotation + Vector3(-90, 0, 0)

	# تنظیم ارتفاع و جابه‌جایی به سمت جلو
	collision.position = standing_collision_position + Vector3(
		0,
		-offset,
		offset + FORWARD_OFFSET
	)

func set_collision_standing() -> void:
	collision.rotation_degrees = standing_collision_rotation
	collision.position = standing_collision_position

func knockout_from(attacker: Node3D) -> void:
	if _ragdoll_mode or not is_alive() or not can_knockout:
		return
	if not is_instance_valid(attacker) or ragdoll_driver == null:
		return

	var hit_direction: Vector3 = global_position - attacker.global_position
	hit_direction.y = 0.0
	if hit_direction.length_squared() < 0.0001:
		hit_direction = global_transform.basis.z

	knockout()
	animation_player.stop(true)

	_ragdoll_mode = true
	stop_patrol()
	agent.avoidance_enabled = false

	await get_tree().create_timer(knockout_impact_delay).timeout
	if not is_inside_tree() or npc_state != NPCState.UNCONSCIOUS or is_waking_up:
		return
	if ragdoll_driver == null:
		return

	animation_player.pause()
	collision.set_deferred("disabled", true)
	ragdoll_driver.call("start_ragdoll", hit_direction.normalized(), head_impact_strength)

func _process(delta: float) -> void:
	if not _wake_blending:
		return
	var skeleton := ragdoll_driver.get_skeleton()
	if skeleton == null:
		return
	_wake_blend_elapsed += delta
	var alpha := clampf(_wake_blend_elapsed / wake_blend_duration, 0.0, 1.0)
	alpha = alpha * alpha * (3.0 - 2.0 * alpha)
	global_position = _wake_root_start.lerp(_wake_root_target, alpha)
	rotation.y = lerp_angle(_wake_yaw_start, _wake_yaw_target, alpha)
	for i in range(mini(_wake_source_poses.size(), _wake_target_poses.size())):
		skeleton.set_bone_pose(i, _wake_source_poses[i].interpolate_with(_wake_target_poses[i], alpha))

	if _wake_blend_elapsed >= wake_blend_duration:
		_wake_blending = false
		set_process(false)
		animation_controller.play_action(_wake_action, 0.0)
		animation_player.seek(0.0, true)

func start_garrote_ragdoll() -> void:
	if not is_inside_tree() or ragdoll_driver == null:
		return

	if npc_state != NPCState.DEAD or _ragdoll_mode:
		return

	_ragdoll_mode = true
	velocity = Vector3.ZERO
	stop_patrol()
	agent.avoidance_enabled = false

	animation_player.pause()
	collision.set_deferred("disabled", true)

	ragdoll_driver.call("start_ragdoll")

func _is_fallen_on_back(skeleton: Skeleton3D) -> bool:
	var left_index := skeleton.find_bone("LeftArm")
	var right_index := skeleton.find_bone("RightArm")
	var hip_index := skeleton.find_bone("Hips")
	var head_index := skeleton.find_bone("Neck1")

	if head_index < 0:
		head_index = skeleton.find_bone("Neck")

	if left_index < 0 or right_index < 0 or hip_index < 0 or head_index < 0:
		push_warning("Cannot determine fallen body orientation.")
		return false

	var left_pos := skeleton.to_global(skeleton.get_bone_global_pose(left_index).origin)
	var right_pos := skeleton.to_global(skeleton.get_bone_global_pose(right_index).origin)
	var hip_pos := skeleton.to_global(skeleton.get_bone_global_pose(hip_index).origin)
	var head_pos := skeleton.to_global(skeleton.get_bone_global_pose(head_index).origin)

	var shoulder_axis := right_pos - left_pos
	var torso_axis := head_pos - hip_pos

	var chest_normal := shoulder_axis.cross(torso_axis).normalized()

	return chest_normal.dot(Vector3.UP) < 0.0


func _apply_character_visual() -> void:
	var appearance_id := int(character_appearance)

	if appearance_id < 0 or appearance_id >= APPEARANCE_SCENES.size():
		push_error("Invalid Character Appearance.")
		return

	var is_female := appearance_id >= CharacterAppearance.FEMALE_CASUAL
	var gender_index := 1 if is_female else 0

	var old_visual := get_node_or_null("Visual") as Node3D
	if old_visual == null:
		push_error("NPC Visual node not found.")
		return

	var new_visual := CHARACTER_VISUALS[gender_index].instantiate() as Node3D
	if new_visual == null:
		push_error("Could not instantiate Character Visual.")
		return

	var skeleton := new_visual.find_child(
		"Skeleton3D", true, false
	) as Skeleton3D

	if skeleton == null:
		push_error("Skeleton3D not found in Character Visual.")
		new_visual.free()
		return

	var new_appearance := APPEARANCE_SCENES[appearance_id].instantiate()
	if new_appearance == null:
		push_error("Could not instantiate Character Appearance.")
		new_visual.free()
		return

	var old_appearance := skeleton.get_node_or_null("Appearance")

	if old_appearance != null:
		skeleton.remove_child(old_appearance)
		old_appearance.free()

	new_appearance.name = "Appearance"
	skeleton.add_child(new_appearance)

	var saved_transform := old_visual.transform

	remove_child(old_visual)
	old_visual.queue_free()

	new_visual.name = "Visual"
	add_child(new_visual)
	new_visual.transform = saved_transform

	# The animation controller must find the new AnimationPlayer.
	animation_controller.refresh_animation_player()
	animation_player = animation_controller.animation_player

	# Configure animations based on the selected appearance.
	animation_controller.configure_gender(
		CharacterAnimationController.Set.FEMALE
		if is_female
		else CharacterAnimationController.Set.MALE
	)

	ragdoll_driver = new_visual.find_child(
		"PhysicalBoneSimulator3D", true, false
	) as PhysicalBoneSimulator3D

	if animation_player == null:
		push_error("AnimationPlayer not found in selected Visual.")

	if ragdoll_driver == null:
		push_error("PhysicalBoneSimulator3D not found in selected Visual.")
