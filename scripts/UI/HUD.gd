extends CanvasLayer

@export var player_path: NodePath

@onready var left_hud: MarginContainer = $LeftHUD
@onready var portrait: TextureRect = $LeftHUD/LeftRoot/AgentMargin/AgentContent/PortraitArea/Portrait
@onready var agent_name: Label = $LeftHUD/LeftRoot/AgentMargin/AgentContent/AgentHeader/AgentName
@onready var health_value: Label = $LeftHUD/LeftRoot/AgentMargin/AgentContent/AgentHeader/HealthValue
@onready var health_bar: ProgressBar = $LeftHUD/LeftRoot/AgentMargin/AgentContent/HealthBar
@onready var crouch_slot = $LeftHUD/LeftRoot/ActionsArea/ActionsColumn/CrouchSlot
@onready var knockout_slot = $LeftHUD/LeftRoot/ActionsArea/ActionsColumn/KnockoutSlot
@onready var kill_slot = $LeftHUD/LeftRoot/ActionsArea/ActionsColumn/KillSlot
@onready var pistol_slot = $LeftHUD/LeftRoot/ActionsArea/ActionsColumn/PistolSlot
@onready var rifle_slot = $LeftHUD/LeftRoot/ActionsArea/ActionsColumn/RifleSlot
@onready var heal_slot = $LeftHUD/LeftRoot/ActionsArea/ActionsColumn/HealSlot

@onready var right_hud: MarginContainer = $RightHUD
@onready var map_title: Label = $RightHUD/RightRoot/MapMargin/MapContainer/MapHead/MapTitle
@onready var map_shortcut: Label = $RightHUD/RightRoot/MapMargin/MapContainer/MapHead/MapShortcut
@onready var map_image: TextureRect = $RightHUD/RightRoot/MapMargin/MapContainer/MapArea/MapImage
@onready var log_slot = $RightHUD/RightRoot/ActionsArea/ActionsColumn/LogSlot

@onready var map_panel: Control = $MapMargin/MapPanel
@onready var map_viewport_container: SubViewportContainer = $MapMargin/MapPanel/MapContent/MapViewportContainer
@onready var map_viewport: SubViewport = $MapMargin/MapPanel/MapContent/MapViewportContainer/MapViewport
@onready var camera_view_frame: Line2D = $MapMargin/MapPanel/MapContent/MapMarkers/CameraViewFrame
@onready var map_rig: Node3D = $MapMargin/MapPanel/MapContent/MapViewportContainer/MapViewport/MapRig
@onready var map_camera: Camera3D = $MapMargin/MapPanel/MapContent/MapViewportContainer/MapViewport/MapRig/MapCamera
@onready var resize_handle: Control = $MapMargin/MapPanel/MapContent/ResizeHandle
#Markers
@onready var map_markers: Control = $MapMargin/MapPanel/MapContent/MapMarkers
var map_entities: Dictionary = {}
#Main Camera For refrence
@onready var camera_rig: Node3D = get_tree().current_scene.get_node("CameraRig")
@onready var main_camera: Camera3D = get_tree().current_scene.get_node("CameraRig/Camera3D")

#Map Zoom
const MAP_ZOOM_MIN := 15.0
const MAP_ZOOM_MAX := 60.0
const MAP_ZOOM_STEP := 3.0

const MAP_MIN_SIZE := Vector2(200, 200)
const MAP_MAX_SIZE := Vector2(750, 750)
const CAMERA_SURFACE_MASK := 1 << 6
const MAP_CAMERA_MOVE_TIME := 0.28

var map_camera_move_tween: Tween
var is_resizing_map := false
var resize_start_mouse := Vector2.ZERO
var resize_start_size := Vector2.ZERO

var player = null
#Left HUD
const agent_portrait: Texture2D = preload("res://data/Pic/agent.png")
const stand_icon: Texture2D = preload("res://data/icons/stand.png")
const crouch_icon: Texture2D = preload("res://data/icons/crouch.png")
const knockout_icon: Texture2D = preload("res://data/icons/knockout.png")
const kill_icon: Texture2D = preload("res://data/icons/kill.png")
const pistol_icon: Texture2D = preload("res://data/icons/pistol.png")
const rifle_icon: Texture2D = preload("res://data/icons/rifle.png")
const heal_icon: Texture2D = preload("res://data/icons/heal.png")
#Right HUD
const map_image_icon: Texture2D = preload("res://data/Pic/map.png")
const log_icon: Texture2D = preload("res://data/icons/log.png")


func _ready():
	_apply_theme(ThemeManager.get_current_theme())

	if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
		ThemeManager.theme_changed.connect(_on_theme_changed)

	if player_path != NodePath():
		player = get_node(player_path)

	if player != null:
		if player.has_signal("movement_state_changed"):
			if not player.movement_state_changed.is_connected(_on_player_movement_state_changed):
				player.movement_state_changed.connect(_on_player_movement_state_changed)

		if player.has_signal("health_changed"):
			if not player.health_changed.is_connected(_on_player_health_changed):
				player.health_changed.connect(_on_player_health_changed)

		_on_player_health_changed(player.current_health, player.max_health)
		_on_player_movement_state_changed(player.movement_state)

	if not resize_handle.gui_input.is_connected(_on_resize_handle_gui_input):
		resize_handle.gui_input.connect(_on_resize_handle_gui_input)

	if not map_viewport_container.gui_input.is_connected(_on_map_viewport_gui_input):
		map_viewport_container.gui_input.connect(_on_map_viewport_gui_input)

	if not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)

	if not crouch_slot.pressed.is_connected(_on_crouch_slot_pressed):
		crouch_slot.pressed.connect(_on_crouch_slot_pressed)

	if not knockout_slot.pressed.is_connected(_on_knockout_pressed):
		knockout_slot.pressed.connect(_on_knockout_pressed)

	if not kill_slot.pressed.is_connected(_on_lethal_takedown_pressed):
		kill_slot.pressed.connect(_on_lethal_takedown_pressed)

	if not pistol_slot.pressed.is_connected(_on_pistol_pressed):
		pistol_slot.pressed.connect(_on_pistol_pressed)

	if not rifle_slot.pressed.is_connected(_on_rifle_pressed):
		rifle_slot.pressed.connect(_on_rifle_pressed)

	if not heal_slot.pressed.is_connected(_on_heal_pressed):
		heal_slot.pressed.connect(_on_heal_pressed)

	if not log_slot.pressed.is_connected(_open_log):
		log_slot.pressed.connect(_open_log)

	if not map_image.gui_input.is_connected(_on_map_image_gui_input):
		map_image.gui_input.connect(_on_map_image_gui_input)

	portrait.texture = agent_portrait
	map_image.texture = map_image_icon

	crouch_slot.setup_action(stand_icon, get_action_key_name("crouch"))
	knockout_slot.setup_action(knockout_icon, get_action_key_name("knockout"))
	kill_slot.setup_action(kill_icon, get_action_key_name("lethal_takedown"))
	pistol_slot.setup_action(pistol_icon, get_action_key_name("pistol"), "10")
	rifle_slot.setup_action(rifle_icon, get_action_key_name("rifle"), "3")
	heal_slot.setup_action(heal_icon, get_action_key_name("heal"), "2")
	log_slot.setup_action(log_icon, get_action_key_name("open_log"), "51")

	agent_name.text = "Agent"

	refresh_shortcuts()
	map_panel.hide()

	if GameManager.map_panel_size != Vector2.ZERO:
		_set_map_size(GameManager.map_panel_size)
	else:
		GameManager.map_panel_size = map_panel.size

func _process(_delta: float) -> void:
	if map_panel.visible:
		map_rig.rotation.y = camera_rig.rotation.y
		map_rig.global_position = Vector3(camera_rig.global_position.x, map_rig.global_position.y, camera_rig.global_position.z)
		_update_map_markers()
		_update_camera_view_frame()
	if not is_resizing_map:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var mouse_delta := mouse_position - resize_start_mouse
	var new_size := Vector2(resize_start_size.x - mouse_delta.x, resize_start_size.y + mouse_delta.y)
	new_size.x = clamp(new_size.x, MAP_MIN_SIZE.x, MAP_MAX_SIZE.x)
	new_size.y = clamp(new_size.y, MAP_MIN_SIZE.y, MAP_MAX_SIZE.y)
	_set_map_size(new_size)

#Map functions
func _on_map_viewport_gui_input(event: InputEvent) -> void:
	if not map_panel.visible:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			map_camera.size = maxf(map_camera.size - MAP_ZOOM_STEP, MAP_ZOOM_MIN)
			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			map_camera.size = minf(map_camera.size + MAP_ZOOM_STEP, MAP_ZOOM_MAX)
			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_LEFT:
			var world_position = _map_position_to_world(event.position)

			if world_position != null:
				_move_camera_from_map(world_position)

			get_viewport().set_input_as_handled()

func _map_position_to_world(map_position: Vector2) -> Variant:
	var viewport_size := Vector2(map_viewport.size)

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return null

	var viewport_position := map_position / map_viewport_container.size * viewport_size
	var from := map_camera.project_ray_origin(viewport_position)
	var direction := map_camera.project_ray_normal(viewport_position)
	var to := from + direction * 500.0
	var query := PhysicsRayQueryParameters3D.create(from, to, CAMERA_SURFACE_MASK)
	var hit := map_camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return null

	return hit.position

func _move_camera_from_map(world_position: Vector3) -> void:
	if map_camera_move_tween != null:
		map_camera_move_tween.kill()

	var target_position := Vector3(
		world_position.x,
		camera_rig.global_position.y,
		world_position.z
	)

	camera_rig.set_process(false)

	map_camera_move_tween = create_tween()
	map_camera_move_tween.tween_property(camera_rig, "global_position", target_position, MAP_CAMERA_MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	map_camera_move_tween.finished.connect(_on_map_camera_move_finished)

func _on_map_camera_move_finished() -> void:
	camera_rig.set_process(true)
	map_camera_move_tween = null

func _rebuild_map_markers() -> void:
	for data in map_entities.values():
		var marker: Node2D = data["marker"]
		if is_instance_valid(marker):
			marker.queue_free()
	map_entities.clear()
	_find_map_entities(get_tree().current_scene)

func _find_map_entities(node: Node) -> void:
	if node is Node3D:
		var marker_template := node.get_node_or_null("MapMarker")

		if marker_template is Node2D:
			var marker := marker_template.duplicate() as Node2D
			marker.visible = true
			map_markers.add_child(marker)

			map_entities[node] = {
				"marker": marker
			}

	for child in node.get_children():
		_find_map_entities(child)

func _update_map_markers() -> void:
	var viewport_size := Vector2(map_viewport.size)

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var display_scale := map_markers.size / viewport_size

	for entity in map_entities.keys():
		if not is_instance_valid(entity):
			continue

		var marker: Node2D = map_entities[entity]["marker"]
		var world_position: Vector3 = entity.global_position
		var forward_position: Vector3 = world_position + (entity.global_transform.basis.z * 2.0)

		var screen_position := map_camera.unproject_position(world_position)
		var forward_screen_position := map_camera.unproject_position(forward_position)

		screen_position *= display_scale
		forward_screen_position *= display_scale

		if screen_position.x < 0.0 or screen_position.y < 0.0 or screen_position.x > map_markers.size.x or screen_position.y > map_markers.size.y:
			marker.hide()
			continue

		marker.show()
		marker.position = screen_position

		var direction := forward_screen_position - screen_position

		if direction.length_squared() > 0.001:
			marker.rotation = direction.angle() + PI / 2.0

func _update_camera_view_frame() -> void:
	var main_view_size := get_viewport().get_visible_rect().size
	var map_view_size := Vector2(map_viewport.size)

	if main_view_size.x <= 0.0 or main_view_size.y <= 0.0 or map_view_size.x <= 0.0 or map_view_size.y <= 0.0:
		camera_view_frame.hide()
		return

	var corners := PackedVector2Array([
		Vector2.ZERO,
		Vector2(main_view_size.x, 0.0),
		main_view_size,
		Vector2(0.0, main_view_size.y)
	])

	var display_scale := map_markers.size / map_view_size
	var frame_points := PackedVector2Array()

	for corner in corners:
		var hit := _raycast_main_camera_corner(corner)

		if hit.is_empty():
			camera_view_frame.hide()
			return

		var map_position: Vector2 = map_camera.unproject_position(hit.position)
		frame_points.append(map_position * display_scale)

	camera_view_frame.points = frame_points
	camera_view_frame.show()

func _raycast_main_camera_corner(screen_position: Vector2) -> Dictionary:
	var from := main_camera.project_ray_origin(screen_position)
	var direction := main_camera.project_ray_normal(screen_position)
	var plane_y := camera_rig.global_position.y

	if direction.y < -0.0001:
		var distance := (plane_y - from.y) / direction.y

		if distance > 0.0:
			return {
				"position": from + direction * distance
			}

	var horizontal_direction := Vector3(direction.x, 0.0, direction.z)

	if horizontal_direction.length_squared() < 0.0001:
		return {
			"position": Vector3(from.x, plane_y, from.z)
		}

	horizontal_direction = horizontal_direction.normalized()

	return {
		"position": Vector3(from.x, plane_y, from.z) + horizontal_direction * main_camera.far
	}

#Other functions
func _on_language_changed() -> void:
	_setup_localized_texts()

func get_action_key_name(action_name: String) -> String:
	var events = InputMap.action_get_events(action_name)

	for event in events:
		if event is InputEventKey:
			var code = event.keycode
			
			if code == 0:
				code = event.physical_keycode
			
			return OS.get_keycode_string(code)

	return ""

func _on_player_movement_state_changed(new_state):
	if player == null:
		return
	var is_crouched: bool = new_state == player.MovementState.CROUCH_IDLE or new_state == player.MovementState.CROUCH_WALK
	if is_crouched:
		crouch_slot.set_icon(crouch_icon)
		crouch_slot.set_tooltip(LocalizationManager.translate("hud.tooltips.crouch"))
	else:
		crouch_slot.set_icon(stand_icon)
		crouch_slot.set_tooltip(LocalizationManager.translate("hud.tooltips.stand"))

func _on_player_health_changed(current_health, max_health):
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_value.text = str(current_health)

func _on_crouch_slot_pressed():
	if player != null and player.has_method("toggle_crouch"):
		player.toggle_crouch()

func _on_heal_button_pressed():
	if player != null and player.has_method("heal"):
		player.heal(20)

func _on_theme_changed(_theme_id: String, theme_resource: Theme):
	_apply_theme(theme_resource)

func _apply_theme(theme_resource: Theme):
	$LeftHUD.theme = theme_resource
	$RightHUD.theme = theme_resource

func _on_map_image_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_interact"):
		print("MAP CLICKED BY Mouse")
		_open_full_map()

func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_resizing_map = true
			resize_start_mouse = get_viewport().get_mouse_position()
			resize_start_size = map_panel.size
		else:
			if is_resizing_map:
				is_resizing_map = false
				GameManager.map_panel_size = map_panel.size
				GameManager.save_settings()
		get_viewport().set_input_as_handled()

func _set_map_size(new_size: Vector2) -> void:
	map_panel.custom_minimum_size = new_size
	_update_map_camera_aspect(new_size)

func _update_map_camera_aspect(panel_size: Vector2) -> void:
	if panel_size.x <= panel_size.y:
		map_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	else:
		map_camera.keep_aspect = Camera3D.KEEP_WIDTH

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_map"):
		_open_full_map()
	elif event.is_action_pressed("open_log"):
		_open_log()
	elif event.is_action_pressed("knockout"):
		_on_knockout_pressed()
	elif event.is_action_pressed("lethal_takedown"):
		_on_lethal_takedown_pressed()
	elif event.is_action_pressed("pistol"):
		_on_pistol_pressed()
	elif event.is_action_pressed("rifle"):
		_on_rifle_pressed()
	elif event.is_action_pressed("heal"):
		_on_heal_pressed()

func refresh_shortcuts() -> void:
	crouch_slot.set_shortcut(get_action_key_name("crouch"))
	knockout_slot.set_shortcut(get_action_key_name("knockout"))
	kill_slot.set_shortcut(get_action_key_name("lethal_takedown"))
	pistol_slot.set_shortcut(get_action_key_name("pistol"))
	rifle_slot.set_shortcut(get_action_key_name("rifle"))
	heal_slot.set_shortcut(get_action_key_name("heal"))
	log_slot.set_shortcut(get_action_key_name("open_log"))
	map_shortcut.text = get_action_key_name("open_map")

func _setup_localized_texts() -> void:
	agent_name.text = LocalizationManager.translate("hud.agent")
	map_title.text = LocalizationManager.translate("controls.map")

	knockout_slot.set_tooltip(LocalizationManager.translate("hud.tooltips.knockout"))
	kill_slot.set_tooltip(LocalizationManager.translate("hud.tooltips.lethal_takedown"))
	pistol_slot.set_tooltip(LocalizationManager.translate("hud.tooltips.pistol"))
	rifle_slot.set_tooltip(LocalizationManager.translate("hud.tooltips.rifle"))
	heal_slot.set_tooltip(LocalizationManager.translate("hud.tooltips.heal"))
	log_slot.set_tooltip(LocalizationManager.translate("hud.tooltips.log"))

	if player != null:
		_on_player_movement_state_changed(player.movement_state)

func _open_full_map() -> void:
	map_panel.visible = not map_panel.visible
	if map_panel.visible:
		_rebuild_map_markers()

func _open_log() -> void:
	print("_open_log")
func _on_knockout_pressed() -> void:
	print("_on_knockout_pressed")
func _on_lethal_takedown_pressed() -> void:
	print("_on_lethal_takedown_pressed")
func _on_pistol_pressed() -> void:
	print("_on_pistol_pressed")
func _on_rifle_pressed() -> void:
	print("_on_rifle_pressed")
func _on_heal_pressed() -> void:
	print("O_on_heal_pressed")
