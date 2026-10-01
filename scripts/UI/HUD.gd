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
@onready var map_shortcut: Label = $RightHUD/RightRoot/MapMargin/MapContainer/MapHead/MapShortcut
@onready var map_image: TextureRect = $RightHUD/RightRoot/MapMargin/MapContainer/MapArea/MapImage
@onready var log_slot = $RightHUD/RightRoot/ActionsArea/ActionsColumn/LogSlot

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
			player.movement_state_changed.connect(_on_player_movement_state_changed)

		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)

		_on_player_movement_state_changed(player.movement_state)
		_on_player_health_changed(80, 100)#player.current_health, player.max_health)

	#connecting buttons to functions
	crouch_slot.pressed.connect(_on_crouch_slot_pressed)
	knockout_slot.pressed.connect(_on_knockout_pressed)
	kill_slot.pressed.connect(_on_lethal_takedown_pressed)
	pistol_slot.pressed.connect(_on_pistol_pressed)
	rifle_slot.pressed.connect(_on_rifle_pressed)
	heal_slot.pressed.connect(_on_heal_pressed)
	log_slot.pressed.connect(_open_log)
	if not map_image.gui_input.is_connected(_on_map_image_gui_input):
		map_image.gui_input.connect(_on_map_image_gui_input)

	#all buttons settings
	portrait.texture = agent_portrait
	map_image.texture = map_image_icon
	crouch_slot.setup_action(stand_icon, get_action_key_name("crouch"), "", "Stand")
	knockout_slot.setup_action(knockout_icon, get_action_key_name("knockout"), "", "Knokout enemy without killing")
	kill_slot.setup_action(kill_icon, get_action_key_name("lethal_takedown"), "", "Silent close range killing")
	pistol_slot.setup_action(pistol_icon, get_action_key_name("pistol"), "10", "Short range pistol")
	rifle_slot.setup_action(rifle_icon, get_action_key_name("rifle"), "3", "Long range sniper rifle")
	heal_slot.setup_action(heal_icon, get_action_key_name("heal"), "2", "Bandage")
	
	log_slot.setup_action(log_icon, get_action_key_name("open_log"), "51", "Show all messages")
	# Placeholder text
	agent_name.text = "Agent"
	map_shortcut.text = get_action_key_name("open_map")
	#message_preview.text = "No messages yet."

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

	var is_crouched : bool = (
		new_state == player.MovementState.CROUCH_IDLE
		or
		new_state == player.MovementState.CROUCH_WALK
	)

	if is_crouched:
		crouch_slot.setup_action(crouch_icon, "Space", "", "Crouch")
	else:
		crouch_slot.setup_action(stand_icon, "Space", "", "Stand")


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

func _open_full_map() -> void:
	print("_open_full_map")
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
