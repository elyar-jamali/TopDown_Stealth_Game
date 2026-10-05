extends CharacterBody3D 
 
@export_group("Game Settings")
@export var move_speed := 3.0 
@export var stuck_time_limit := 0.10 
@export var stuck_move_threshold := 0.01 
 
#پارامترهای مربوط به گیر کردن و تغییر مسیر برای عبور از گیر 
@export var detour_distance := 2.0 
@export var detour_reach_distance := 0.12 
 
@export var standing_height := 1.75 
@export var crouching_height := 1.10 

@export var max_health := 100
var current_health := 100

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
var detour_target := Vector3.ZERO 
var detour_points: Array[Vector3] = [] 
var detour_index := 0 
var is_using_detour := false 
var stuck_time := 0.0 
var previous_position := Vector3.ZERO 
 
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
		"speed": 0.0, 
		"animation": "human_animations/M_idle", 
		"height": 1.75 
	}, 
	MovementState.WALK: { 
		"speed": 3.0, 
		"animation": "human_animations/M_walk", 
		"height": 1.75 
	}, 
	MovementState.RUN: { 
		"speed": 7.0, 
		"animation": "human_animations/M_run", 
		"height": 1.75 
	}, 
	MovementState.CROUCH_IDLE: { 
		"speed": 0.0, 
		"animation": "human_animations/M_crouchidle", 
		"height": 0.95 
	}, 
	MovementState.CROUCH_WALK: { 
		"speed": 1.5, 
		"animation": "human_animations/M_crouchwalk", 
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
	agent.radius = 0.6 
	agent.height = 1.8 
	agent.neighbor_distance = 4.0 
	agent.max_neighbors = 8 
	agent.time_horizon_agents = 1.0 
 
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
 
 
		elif _horizontal_distance( 
			global_position, 
			detour_target 
		) <= detour_reach_distance: 
 
			is_using_detour = false 
			stuck_time = 0.0 
			agent.target_position = final_target 
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
	 
	velocity.x = new_safe_velocity.x 
	velocity.z = new_safe_velocity.z 
 
	move_and_slide() 
	update_movement_state() 
 
 
func _update_stuck_state(delta: float): 
	var moved_distance := _horizontal_distance(global_position, previous_position) 
	var active_target := final_target 
 
	if is_using_detour: 
		if detour_points.size() > 0: 
			active_target = detour_points[detour_index] 
		else: 
			active_target = detour_target 
 
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
	var navigation_map := agent.get_navigation_map() 
 
	if not navigation_map.is_valid(): 
		return 
 
	var next_position := agent.get_next_path_position() 
 
	var path_direction := next_position - global_position 
	path_direction.y = 0.0 
 
	if path_direction.length_squared() <= 0.0001: 
		return 
 
	path_direction = path_direction.normalized() 
 
	# دو جهت عمود بر مسیر؛ 
	# فقط برای fallback عمومی استفاده می‌شوند. 
	var perpendicular_a := Vector3( 
		-path_direction.z, 
		0.0, 
		path_direction.x 
	) 
 
	var perpendicular_b := -perpendicular_a 
 
	var detour_direction := perpendicular_a 
	var door_detour := false 
	var gameplay_object: Node = null 
	var actual_detour_distance := detour_distance 
 
	if get_slide_collision_count() > 0: 
		var collision := get_slide_collision( 
			get_slide_collision_count() - 1 
		) 
 
		var collider = collision.get_collider() 
 
		if collider is Node: 
			gameplay_object = _find_gameplay_object(collider) 
 
		# ----------------------------- 
		# دیتور اختصاصی برای برگ متحرک در 
		# ----------------------------- 
		if gameplay_object != null and gameplay_object.has_method("get_detour_points"): 
			var points: Array[Vector3] = gameplay_object.get_detour_points( 
				global_position, 
				_get_collision_radius() 
			) 
 
			if points.size() >= 2: 
				for i in range(points.size()): 
					points[i] = NavigationServer3D.map_get_closest_point( 
						navigation_map, 
						points[i] 
					) 
				detour_points = points 
				detour_index = 0 
				is_using_detour = true 
				agent.target_position = detour_points[0] 
				return 
		# ----------------------------- 
		# دیتور عمومی سایر موانع 
		# ----------------------------- 
		if not door_detour: 
			var collision_normal := collision.get_normal() 
			collision_normal.y = 0.0 
 
			if collision_normal.length_squared() > 0.0001: 
				collision_normal = ( 
					collision_normal.normalized() 
				) 
 
				if ( 
					perpendicular_b.dot( 
						collision_normal 
					) 
					> 
					perpendicular_a.dot( 
						collision_normal 
					) 
				): 
					detour_direction = perpendicular_b 
 
	var candidate := ( 
		global_position 
		+ detour_direction * actual_detour_distance 
	) 
 
	candidate = NavigationServer3D.map_get_closest_point( 
		navigation_map, 
		candidate 
	) 
 
	if _horizontal_distance( 
		candidate, 
		global_position 
	) < 0.2: 
		return 
 
	detour_target = candidate 
	is_using_detour = true 
	agent.target_position = detour_target 
 
	 
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
 
 
	final_target = target 
	is_using_detour = false 
	detour_points.clear() 
	detour_index = 0 
	stuck_time = 0.0 
	agent.target_position = final_target 
 
 
func _stop_movement(): 
	agent.velocity = Vector3.ZERO 
	agent.target_position = global_position 
 
	final_target = global_position 
	is_using_detour = false 
	stuck_time = 0.0 
 
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
 
 
func update_movement_state(): 
 
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
 
func play_animation(anim_name: String): 
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
	move_speed = data.speed 
	play_animation(data.animation) 
	_set_player_height(data.height) 
	agent.height = data.height
	movement_state_changed.emit(movement_state)

func take_damage(amount: int):
	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)