extends CharacterBody3D
@export var move_speed := 3.0
@onready var agent: NavigationAgent3D = $NavigationAgent3D

@onready var path_drawer := PathDrawer.new()
var pending_interaction = null
# مربوط به دابل کلیک
var last_click_time := 0.0
var double_click_threshold := 0.25

func _ready():
	# بارگذاری زبان
	LocalizationManager.load_lang("fa")
	# پارامترهای لازم برای گیر نکردن کاراکتر هنگام حرکت
	floor_max_angle = deg_to_rad(60.0)  # allow steeper slopes
	floor_snap_length = 0.5  # helps stick to ground on steps
	max_slides = 6
	floor_block_on_wall = false  # don't stop when hitting a vertical wall/step face

	add_child(path_drawer)
	path_drawer.setup(self)
	#پارامترهای محاسبه حداقل فاصله برای رسیدن کاراکتر به مقصد
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.7

func _physics_process(delta):
	if pending_interaction:
		var distance = global_position.distance_to(pending_interaction.get_interaction_position())
		if distance < pending_interaction.interaction_range:
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			path_drawer.clear()
			#InteractionSystem.interact(pending_interaction)
			InteractionSystem.interact(pending_interaction)
			pending_interaction = null
			agent.target_position = global_position
			return
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	if agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		path_drawer.clear()
		return
	var next_position = agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	if direction.length() > 0.01:
		var target_angle = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 5.0 * delta)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	move_and_slide()
	if is_on_wall() and is_on_floor():
		velocity.y = 2.0
	path_drawer.update_path_display(self, agent)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# برای هندل کردن دابل کلیک
		var now = Time.get_ticks_msec() / 1000.0
		var is_double_click = (now - last_click_time) < double_click_threshold
		last_click_time = now
		
		var result = InteractionSystem.raycast(get_viewport().get_camera_3d(),get_viewport().get_mouse_position(),1000)
		
		if result:
			var collider = result.collider
			if is_double_click:
				pending_interaction = null
				move_speed = 7 # Running speed
				agent.target_position = result.position
				#agent.target_position = agent.get_closest_point(result.position)
			else:
				pending_interaction = null
				move_speed = 3 #Walking Speed
				agent.target_position = result.position
				#agent.target_position = agent.get_closest_point(result.position)
			if collider.is_in_group("interactable"):
				#InteractionSystem_AutoLoad.interact(collider)
				pending_interaction = collider
				agent.target_position = collider.get_interaction_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		agent.target_position = global_position
		velocity = Vector3.ZERO
		path_drawer.clear()

func _process(delta):
	var result = InteractionSystem.raycast(get_viewport().get_camera_3d(),get_viewport().get_mouse_position(),1000)
	if result:
		var collider = result.collider
		if collider.is_in_group("interactable"):
			HoverSystem.set_hover_target(collider)
		else:
			HoverSystem.clear_hover()
		#print(collider)
		"""if collider.is_in_group("interactable"):
			CursorManager.set_state(CursorManager.CursorState.INTERACT)
				"""
	else:
		HoverSystem.clear_hover()
		#CursorManager.set_state(CursorManager.CursorState.DEFAULT)
