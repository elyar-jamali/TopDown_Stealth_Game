extends CharacterBody3D 
 
@export_group("Movement Speeds")
@export var walk_speed: float = 2.5
@export var run_speed: float = 5.5
@export var crouch_walk_speed: float = 1.5
var move_speed := 0.0

var stuck_time_limit := 0.10 
var stuck_move_threshold := 0.01 
#پارامترهای مربوط به گیر کردن و تغییر مسیر برای عبور از گیر 
var detour_reach_distance := 0.12 
 
@export_group("Gameplay Settings")
@export var max_health := 100
var current_health : int

@export_group("Animation Settings")
@export var animation_set: CharacterAnimationData.Set = CharacterAnimationData.Set.MALE

@export_group("Map Settings")
@export var map_marker_color: GameColors.Preset = GameColors.Preset.GREEN

signal movement_state_changed(new_state)
signal health_changed(current_health, max_health)

@onready var agent: NavigationAgent3D = $NavigationAgent3D 
@onready var path_drawer := PathDrawer.new() 
@onready var animation_player: AnimationPlayer = $Visual/player_rigged/AnimationPlayer 
@onready var collision_shape: CollisionShape3D = $CollisionShape3D 
@onready var map_marker_fill: Polygon2D = $MapMarker/Fill

var pending_interaction = null 
var last_click_time := 0.0 
var double_click_threshold := 0.25 
var final_target := Vector3.ZERO 
var detour_points: Array[Vector3] = [] 
var detour_index := 0 
var is_using_detour := false 
var stuck_time := 0.0 
var previous_position := Vector3.ZERO 

var is_using_short_escape := false
var short_escape_points: Array[Vector3] = []
var short_escape_index := 0
var short_escape_velocity := Vector3.ZERO
var short_escape_stuck_time := 0.0
var short_escape_attempts := 0

enum MovementState { 
	IDLE, 
	WALK, 
	RUN, 
	CROUCH_IDLE, 
	CROUCH_WALK 
} 
var movement_state: MovementState = MovementState.IDLE 
var desired_movement_state: MovementState = MovementState.IDLE 
var return_state_after_run := MovementState.IDLE 
 
const MOVEMENT_DATA = {
	MovementState.IDLE: {
		"action": CharacterAnimationData.Action.IDLE,
		"height": 1.75
	},
	MovementState.WALK: {
		"action": CharacterAnimationData.Action.WALK,
		"height": 1.75
	},
	MovementState.RUN: {
		"action": CharacterAnimationData.Action.RUN,
		"height": 1.75
	},
	MovementState.CROUCH_IDLE: {
		"action": CharacterAnimationData.Action.CROUCH_IDLE,
		"height": 0.95
	},
	MovementState.CROUCH_WALK: {
		"action": CharacterAnimationData.Action.CROUCH_WALK,
		"height": 0.95
	}
}
 
func is_crouched() -> bool:
	return (
		movement_state == MovementState.CROUCH_IDLE
		or movement_state == MovementState.CROUCH_WALK
	)

func toggle_crouch():
	var moving := Vector2(
		velocity.x,
		velocity.z
	).length() > 0.1

	if is_crouched():
		return_state_after_run = MovementState.IDLE

		if moving:
			change_movement_state(MovementState.WALK)
		else:
			change_movement_state(MovementState.IDLE)
	else:
		if moving:
			change_movement_state(MovementState.CROUCH_WALK)
		else:
			change_movement_state(MovementState.CROUCH_IDLE)

func _ready(): 
	map_marker_fill.color = GameColors.get_color(map_marker_color)
	floor_max_angle = deg_to_rad(45.0) 
	floor_snap_length = 0.5 
	max_slides = 6 
	floor_block_on_wall = false 
	 
	agent.avoidance_enabled = true 
	agent.radius = _get_collision_radius() + 0.05
	agent.height = 1.8 
	agent.neighbor_distance = 4.0 
	agent.max_neighbors = 8 
	agent.time_horizon_agents = 1.0 
	agent.avoidance_priority = 1.0

	if not agent.velocity_computed.is_connected(_on_safe_velocity_computed): 
		agent.velocity_computed.connect(_on_safe_velocity_computed) 
 
	add_child(path_drawer) 
	path_drawer.setup(self) 
 
	#پارامتر مقدار مجاز انحراف از مسیر 
	agent.path_desired_distance = 0.75 
	#پارامتر فاصله تا رسیدن به مقصد 
	agent.target_desired_distance = 0.1 
 
	previous_position = global_position 
	final_target = global_position 
	
	current_health = max_health
	health_changed.emit(current_health, max_health)
	movement_state_changed.emit(movement_state)
 
 
func _physics_process(delta): 
	_apply_gravity(delta) 
 
	if _try_pending_interaction(): 
		previous_position = global_position 
		return 
	if is_using_short_escape:
		_update_short_escape(delta)
		previous_position = global_position
		return
	if is_using_detour: 
		if detour_points.size() > 0: 
 
			if _horizontal_distance( 
				global_position, 
				detour_points[detour_index] 
			) <= detour_reach_distance: 
 
				detour_index += 1 
 
				if detour_index >= detour_points.size(): 
 
					detour_points.clear() 
					detour_index = 0 
					is_using_detour = false 
					stuck_time = 0.0 
					agent.target_position = final_target 
 
				else: 
 
					agent.target_position = detour_points[detour_index] 
 
	elif ( 
		not is_using_detour 
		and _horizontal_distance(global_position, final_target) 
			<= agent.target_desired_distance 
	): 
		_stop_movement() 
		previous_position = global_position 
		return 
 
	elif agent.is_navigation_finished(): 
		_stop_movement() 
 
		if desired_movement_state == MovementState.RUN: 
			change_movement_state(return_state_after_run) 
		else: 
			change_movement_state(MovementState.IDLE) 
 
		previous_position = global_position 
		return 
 
	var next_position := agent.get_next_path_position() 
 
	var direction := next_position - global_position 
	direction.y = 0.0 
 
	if direction.length_squared() > 0.0001: 
		direction = direction.normalized() 
 
		var target_angle := atan2(direction.x, direction.z) 
		rotation.y = lerp_angle(rotation.y, target_angle, 5.0 * delta) 
	else: 
		direction = Vector3.ZERO 
 
	agent.velocity = direction * move_speed 
 
	_update_stuck_state(delta) 
	path_drawer.update_path_display(self, agent) 
 
	previous_position = global_position 
 
func _get_movement_speed(state: MovementState) -> float:
	match state:
		MovementState.WALK:
			return walk_speed
		MovementState.RUN:
			return run_speed
		MovementState.CROUCH_WALK:
			return crouch_walk_speed
		_:
			return 0.0

func _get_collision_radius() -> float: 
	if collision_shape.shape is CapsuleShape3D: 
		var capsule := collision_shape.shape as CapsuleShape3D 
		return capsule.radius 
 
	return 0.3 
 
 
func _apply_gravity(delta: float): 
	if not is_on_floor(): 
		velocity.y -= 9.8 * delta 
	elif velocity.y < 0.0: 
		velocity.y = 0.0 
 
 
func _on_safe_velocity_computed(new_safe_velocity: Vector3):
	var applied_velocity: Vector3 = new_safe_velocity

	if is_using_short_escape:
		applied_velocity = short_escape_velocity

	velocity.x = applied_velocity.x
	velocity.z = applied_velocity.z

	move_and_slide()
	_update_movement_state()
	_update_animation_speed()
 
 
func _update_stuck_state(delta: float): 
	var moved_distance := _horizontal_distance(global_position, previous_position) 
	var active_target := final_target 
 
	if is_using_detour and not detour_points.is_empty():
		active_target = detour_points[detour_index]
 
	var wants_to_move := _horizontal_distance( 
		global_position, 
		active_target 
	) > agent.target_desired_distance 
 
	if wants_to_move and moved_distance < stuck_move_threshold: 
		stuck_time += delta 
	else: 
		stuck_time = 0.0 
 
	if stuck_time >= stuck_time_limit: 
		stuck_time = 0.0 
 
		if not is_using_detour: 
			_create_detour() 
 
func _create_detour():
	#Detour requested
	var navigation_map := agent.get_navigation_map()

	if not navigation_map.is_valid():
		return

	var next_position := agent.get_next_path_position()
	var path_direction := next_position - global_position
	path_direction.y = 0.0

	if path_direction.length_squared() <= 0.0001:
		return

	path_direction = path_direction.normalized()

	var blocking_line := _get_blocking_collision_line()

	var planned_path: Array[Vector3] = DetourPlanner.find_path(
		self,
		collision_shape,
		agent,
		final_target,
		path_direction,
		blocking_line
	)

	if planned_path.is_empty():
		if short_escape_attempts >= 2:
			#SHORT ESCAPE: RETRY LIMIT REACHED
			_stop_movement()
			return

		var escape_path: Array[Vector3] = DetourPlanner.find_short_escape(
			self,
			collision_shape,
			agent,
			path_direction
		)

		if escape_path.is_empty():
			#SHORT ESCAPE: SEARCH FAILED
			_stop_movement()
			return

		short_escape_attempts += 1
		short_escape_points = escape_path
		short_escape_index = 0
		short_escape_stuck_time = 0.0
		short_escape_velocity = Vector3.ZERO
		is_using_short_escape = true
		agent.velocity = Vector3.ZERO

		#SHORT ESCAPE: STARTED
		return

	#DETOUR FOUND, planned_path
	detour_points = planned_path
	detour_index = 0
	is_using_detour = true
	agent.target_position = detour_points[0]

func _get_blocking_collision_line() -> PackedVector3Array:
	return DetourPlanner.get_blocking_collision_line(self, collision_shape)

func _try_pending_interaction() -> bool: 
	if pending_interaction == null: 
		return false 
 
	if not is_instance_valid(pending_interaction): 
		pending_interaction = null 
		return false 
 
	if not pending_interaction.has_method("get_interaction_position"): 
		pending_interaction = null 
		return false 
 
	# تا زمانی که کاراکتر می‌تواند به مقصد نزدیک‌تر شود، تعامل انجام نشود 
	# بعضی آبجکت‌ها مثل درب باید تا پایان مسیر صبر کنند 
	if pending_interaction.has_method("wait_for_navigation_finish"): 
		if pending_interaction.wait_for_navigation_finish(): 
			if not agent.is_navigation_finished(): 
				return false 
 
	var interaction_position: Vector3 = pending_interaction.get_interaction_position() 
	var distance := global_position.distance_to(interaction_position) 
 
	if distance >= pending_interaction.interaction_range: 
		return false 
 
	var target = pending_interaction 
 
	pending_interaction = null 
	is_using_detour = false 
 
	_stop_movement() 
	InteractionSystem.interact(target) 
 
	return true 
 
 
func _set_movement_target(target: Vector3):
	var navigation_map := agent.get_navigation_map()

	if navigation_map.is_valid():
		target = NavigationServer3D.map_get_closest_point(
			navigation_map,
			target
		)

		target = DetourPlanner.find_safe_target(
			self,
			collision_shape,
			agent,
			target
		)

	final_target = target
	is_using_detour = false
	detour_points.clear()
	detour_index = 0
	_clear_short_escape()
	short_escape_attempts = 0
	stuck_time = 0.0
	agent.target_position = final_target
 
 
func _stop_movement(): 
	agent.velocity = Vector3.ZERO 
	agent.target_position = global_position 
 
	final_target = global_position 
	is_using_detour = false 
	detour_points.clear()
	detour_index = 0

	stuck_time = 0.0 
 
	_clear_short_escape()
	short_escape_attempts = 0

	velocity.x = 0.0 
	velocity.z = 0.0 
 
	path_drawer.clear() 
 
 
func _unhandled_input(event): 
	if event.is_action_pressed("crouch"): 
		toggle_crouch()			 
		return 
 
	if event.is_action_pressed("move_interact"):
		_handle_left_click() 
 
	elif event.is_action_pressed("cancel_action"):
		pending_interaction = null 
		_stop_movement() 
 
func _handle_left_click(): 
	var now := Time.get_ticks_msec() / 1000.0 
	var is_double_click := now - last_click_time < double_click_threshold 
 
	last_click_time = now 
 
	var result := InteractionSystem.raycast( 
		get_viewport().get_camera_3d(), 
		get_viewport().get_mouse_position(), 
		1000, 
		[get_rid()] 
	) 
 
	if result.is_empty(): 
		return 
 
	pending_interaction = null 
 
	var was_crouched := ( 
		movement_state == MovementState.CROUCH_IDLE 
		or movement_state == MovementState.CROUCH_WALK 
	) 
	 
	if is_double_click: 
		if was_crouched: 
			return_state_after_run = MovementState.CROUCH_IDLE 
		else: 
			return_state_after_run = MovementState.IDLE 
		desired_movement_state = MovementState.RUN 
	else: 
		if return_state_after_run == MovementState.CROUCH_IDLE: 
			desired_movement_state = MovementState.CROUCH_WALK 
		else: 
			desired_movement_state = MovementState.WALK 
	 
	if was_crouched and not is_double_click: 
		change_movement_state(MovementState.CROUCH_WALK) 
	else: 
		change_movement_state(desired_movement_state) 
 
	_set_movement_target(result.position) 
 
	var collider: Node = result.collider 
	var target := _find_gameplay_object(collider) 
 
	if target != null: 
		pending_interaction = target 
		_set_movement_target(target.get_interaction_position()) 
 
 
func _process(_delta): 
	var hovered_control := get_viewport().gui_get_hovered_control()

	if hovered_control != null:
		HoverSystem.clear_hover()
		return	
	var result := InteractionSystem.raycast( 
		get_viewport().get_camera_3d(), 
		get_viewport().get_mouse_position(), 
		1000 
	) 
 
	if result.is_empty(): 
		HoverSystem.clear_hover() 
		return 
 
	var collider: Node = result.collider 
	var target := _find_gameplay_object(collider) 
 
	if target != null: 
		HoverSystem.set_hover_target(target) 
	else: 
		HoverSystem.clear_hover() 
 
 
func _find_gameplay_object(node: Node) -> Node: 
	var current := node 
 
	while current != null: 
		if "interactable" in current: 
			return current 
 
		current = current.get_parent() 
 
	return null 
 
 
func _horizontal_distance(point_a: Vector3, point_b: Vector3) -> float: 
	return Vector2( 
		point_a.x, 
		point_a.z 
	).distance_to( 
		Vector2( 
			point_b.x, 
			point_b.z 
		) 
	) 
 
 
func _update_movement_state(): 
 
	var speed = Vector2( 
		velocity.x, 
		velocity.z 
	).length() 
 
	var crouched := ( 
		movement_state == MovementState.CROUCH_IDLE 
		or movement_state == MovementState.CROUCH_WALK 
	) 
 
	if crouched: 
		if speed > 0.1: 
			change_movement_state(MovementState.CROUCH_WALK) 
		else: 
			change_movement_state(MovementState.CROUCH_IDLE) 
	else: 
		if speed > 0.1: 
			change_movement_state(desired_movement_state) 
		else: 
			if agent.is_navigation_finished(): 
				change_movement_state(return_state_after_run) 
 
func play_animation(anim_name: StringName, playback_speed: float = 1.0) -> void:
	animation_player.speed_scale = playback_speed

	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)
 
func _set_player_height(height: float): 
 
	var capsule := collision_shape.shape as CapsuleShape3D 
 
	if capsule == null: 
		return 
 
	capsule.height = height 
	collision_shape.position.y = height * 0.5 
 
 
func change_movement_state(new_state: MovementState): 
	 
	if movement_state == new_state: 
		return 
 
	movement_state = new_state 
 
	var data = MOVEMENT_DATA[movement_state] 
	move_speed = _get_movement_speed(movement_state)
	
	var animation_name := CharacterAnimationData.get_animation(
		animation_set,
		data.action
	)
	play_animation(animation_name)

	_set_player_height(data.height) 
	agent.height = data.height
	movement_state_changed.emit(movement_state)

func take_damage(amount: int):
	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func _update_animation_speed() -> void:
	if movement_state == MovementState.IDLE or movement_state == MovementState.CROUCH_IDLE:
		animation_player.speed_scale = 1.0
		return

	var data = MOVEMENT_DATA[movement_state]

	var real_velocity := get_real_velocity()
	var actual_speed := Vector2(real_velocity.x, real_velocity.z).length()

	if actual_speed <= 0.05:
		return

	animation_player.speed_scale = CharacterAnimationData.get_playback_speed(
		animation_set,
		data.action,
		actual_speed
	)

func _update_short_escape(delta: float) -> void:
	var moved_distance := _horizontal_distance(
		global_position,
		previous_position
	)

	if moved_distance < 0.005:
		short_escape_stuck_time += delta
	else:
		short_escape_stuck_time = 0.0

	if short_escape_stuck_time >= 0.25:
		#SHORT ESCAPE: MOVEMENT BLOCKED
		_finish_short_escape()
		return

	while short_escape_index < short_escape_points.size():
		var target: Vector3 = short_escape_points[short_escape_index]

		if _horizontal_distance(global_position, target) > 0.04:
			break

		short_escape_index += 1

	if short_escape_index >= short_escape_points.size():
		#SHORT ESCAPE: COMPLETED
		_finish_short_escape()
		return

	var direction: Vector3 = (
		short_escape_points[short_escape_index] - global_position
	)

	direction.y = 0.0

	var remaining_distance: float = direction.length()
	direction = direction.normalized()

	var target_angle := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 5.0 * delta)

	var allowed_speed: float = minf(
		move_speed,
		remaining_distance / maxf(delta, 0.0001)
	)

	short_escape_velocity = direction * allowed_speed
	agent.velocity = short_escape_velocity


func _finish_short_escape() -> void:
	_clear_short_escape()
	stuck_time = 0.0
	agent.velocity = Vector3.ZERO
	agent.target_position = final_target


func _clear_short_escape() -> void:
	is_using_short_escape = false
	short_escape_points.clear()
	short_escape_index = 0
	short_escape_velocity = Vector3.ZERO
	short_escape_stuck_time = 0.0