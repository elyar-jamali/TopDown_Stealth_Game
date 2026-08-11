extends CharacterBody3D
@export var move_speed := 3.0
@export var stuck_time_limit := 0.35
@export var stuck_move_threshold := 0.03
@export var detour_distance := 1.0
@export var detour_distance_step := 0.75
@export var max_detour_distance := 4.0
@export var detour_forward_distance := 0.8
@export var detour_reach_distance := 0.5

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var path_drawer := PathDrawer.new()
@onready var animation_player: AnimationPlayer = $Visual/player_rigged/AnimationPlayer

var pending_interaction = null
var last_click_time := 0.0
var double_click_threshold := 0.25
var final_target := Vector3.ZERO
var detour_target := Vector3.ZERO
var is_using_detour := false
var stuck_time := 0.0
var previous_position := Vector3.ZERO
#پارامترهای مربوط به گیر کردن و تغییر مسیر برای عبور از گیر
var detour_side := 1.0
var current_detour_distance := 1.0
var detour_direction := Vector3.ZERO

func _ready():
	floor_max_angle = deg_to_rad(60.0)
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
	#پارامترهای انحراف از مسیر و رسیدن به مقصد
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.2
	
	previous_position = global_position
	final_target = global_position
	current_detour_distance = detour_distance
func _physics_process(delta):
	_apply_gravity(delta)
	if _try_pending_interaction():
		previous_position = global_position
		return
	if is_using_detour:
		if _horizontal_distance(global_position, detour_target) <= detour_reach_distance or agent.is_navigation_finished():
			is_using_detour = false
			stuck_time = 0.0
			current_detour_distance = detour_distance
			detour_direction = Vector3.ZERO
			agent.target_position = final_target
	elif agent.is_navigation_finished():
		_stop_movement()
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
func _apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
func _on_safe_velocity_computed(new_safe_velocity: Vector3):
	velocity.x = new_safe_velocity.x
	velocity.z = new_safe_velocity.z
	move_and_slide()
	update_animation()
func _update_stuck_state(delta: float):
	var moved_distance := _horizontal_distance(global_position, previous_position)
	var active_target := detour_target if is_using_detour else final_target
	var wants_to_move := _horizontal_distance(global_position, active_target) > agent.target_desired_distance
	if wants_to_move and moved_distance < stuck_move_threshold:
		stuck_time += delta
	else:
		stuck_time = 0.0
	if stuck_time >= stuck_time_limit:
		stuck_time = 0.0
		if is_using_detour:
			if current_detour_distance < max_detour_distance:
				current_detour_distance = min(current_detour_distance + detour_distance_step, max_detour_distance)
				_create_detour(true)
			else:
				_try_opposite_detour_side()
		else:
			current_detour_distance = detour_distance
			_create_detour(false)
func _create_detour(keep_direction: bool):
	var target_direction := final_target - global_position
	target_direction.y = 0.0
	if target_direction.length_squared() <= 0.0001:
		return
	target_direction = target_direction.normalized()
	if not keep_direction or detour_direction.length_squared() <= 0.0001:
		var wall_normal := _get_horizontal_collision_normal()
		if wall_normal.length_squared() > 0.0001:
			var tangent_a := Vector3(-wall_normal.z, 0.0, wall_normal.x).normalized()
			var tangent_b := -tangent_a
			if tangent_a.dot(target_direction) >= tangent_b.dot(target_direction):
				detour_direction = tangent_a
			else:
				detour_direction = tangent_b
		else:
			detour_direction = Vector3(-target_direction.z, 0.0, target_direction.x).normalized()
			detour_direction *= detour_side
			detour_side *= -1.0
	var candidate := global_position
	candidate += detour_direction * current_detour_distance
	candidate += target_direction * detour_forward_distance
	var navigation_map := agent.get_navigation_map()
	if navigation_map.is_valid():
		candidate = NavigationServer3D.map_get_closest_point(navigation_map, candidate)
	if _horizontal_distance(candidate, global_position) < 0.2:
		detour_direction = -detour_direction
		candidate = global_position
		candidate += detour_direction * current_detour_distance
		candidate += target_direction * detour_forward_distance
		if navigation_map.is_valid():
			candidate = NavigationServer3D.map_get_closest_point(navigation_map, candidate)
	detour_target = candidate
	is_using_detour = true
	agent.target_position = detour_target
func _try_opposite_detour_side():
	detour_direction = -detour_direction
	current_detour_distance = detour_distance
	_create_detour(true)
func _get_horizontal_collision_normal() -> Vector3:
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		var normal := collision.get_normal()
		normal.y = 0.0
		if normal.length_squared() > 0.0001:
			return normal.normalized()
	return Vector3.ZERO
func _try_pending_interaction() -> bool:
	if pending_interaction == null:
		return false
	if not is_instance_valid(pending_interaction):
		pending_interaction = null
		return false
	if not pending_interaction.has_method("get_interaction_position"):
		pending_interaction = null
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
	final_target = target
	is_using_detour = false
	stuck_time = 0.0
	current_detour_distance = detour_distance
	detour_direction = Vector3.ZERO
	agent.target_position = final_target
func _stop_movement():
	agent.velocity = Vector3.ZERO
	agent.target_position = global_position
	final_target = global_position
	is_using_detour = false
	stuck_time = 0.0
	current_detour_distance = detour_distance
	detour_direction = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	path_drawer.clear()
func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_left_click()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		pending_interaction = null
		_stop_movement()
func _handle_left_click():
	var now := Time.get_ticks_msec() / 1000.0
	var is_double_click := now - last_click_time < double_click_threshold
	last_click_time = now
	var result := InteractionSystem.raycast(get_viewport().get_camera_3d(), get_viewport().get_mouse_position(), 1000)
	if result.is_empty():
		return
	pending_interaction = null
	move_speed = 7.0 if is_double_click else 3.0
	_set_movement_target(result.position)
	var collider: Node = result.collider
	var target := _find_interactable(collider)
	if target != null:
		pending_interaction = target
		_set_movement_target(target.get_interaction_position())
func _process(_delta):
	var result := InteractionSystem.raycast(get_viewport().get_camera_3d(), get_viewport().get_mouse_position(), 1000)
	if result.is_empty():
		HoverSystem.clear_hover()
		return
	var collider: Node = result.collider
	var target := _find_interactable(collider)
	if target != null:
		HoverSystem.set_hover_target(target)
	else:
		HoverSystem.clear_hover()
func _find_interactable(node: Node) -> Node:
	var current := node
	while current != null:
		if current.is_in_group("interactable"):
			return current
		current = current.get_parent()
	return null

func _horizontal_distance(point_a: Vector3, point_b: Vector3) -> float:
	return Vector2(point_a.x, point_a.z).distance_to(Vector2(point_b.x, point_b.z))

func update_animation():
	var speed = Vector2(velocity.x, velocity.z).length()

	if speed < 0.1:
		play_animation("idle")
	elif speed < 5.0:
		play_animation("walk")
	else:
		play_animation("run")

func play_animation(anim_name: String):
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)
