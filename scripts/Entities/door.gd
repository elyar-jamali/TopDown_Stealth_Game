@tool
extends Node3D

enum DoorState {
	CLOSED,
	OPEN,
	LOCKED
}

enum DoorMaterial {
	WOOD_MODERN,
	WOOD_BARN,
	METAL_GREEN,
	METAL_BLACK
}

@export_group("Gameplay Properties")
@export var interactable: bool = true
@export var highlightable: bool = true
@export var targetable: bool = false
@export var outline_color: GameColors.Preset = GameColors.Preset.YELLOW
@export var door_material := DoorMaterial.WOOD_MODERN
@export var door_state := DoorState.CLOSED
@export var object_id: String = ""
# Minimum distance to interact
@export_range(0.0, 1.0, 0.1) var interaction_range: float = 0.3
# Door speed
@export var open_speed := 0.5
@export_group("Map Settings")
@export var map_marker_color: GameColors.Preset = GameColors.Preset.YELLOW

var last_material = -1
var last_state = -1

# Reference the StaticBody3D using its scene path
@onready var collision := $door/CollisionShape3D
@onready var mesh := $door/MeshInstance3D
@onready var door := $door
@onready var navigation_link: NavigationLink3D = $NavigationLink3D

@onready var frame_left: MeshInstance3D = $frame/LeftSide
@onready var frame_right: MeshInstance3D = $frame/RightSide
@onready var frame_top: MeshInstance3D = $frame/TopSide

@onready var map_marker_fill: Polygon2D = $MapMarker/Fill

@onready var interaction_front: Marker3D = $InteractionFront
@onready var interaction_back: Marker3D = $InteractionBack
@onready var door_threshold: Marker3D = $DoorThreshold

# زاویه بسته و باز
var closed_rotation := Vector3(0, 0, 0)
var open_rotation := Vector3(0, PI/2, 0)

var Icon_default = preload("res://data/Pic/info.png")

func get_hover_text():
	return "Door_Caption"

func get_hover_anchor_position() -> Vector3:
	var shape = collision.shape

	if shape is BoxShape3D:
		return collision.global_position + Vector3.UP * (shape.size.y * 0.5 + 0.75)

	return global_position + Vector3.UP * 2.0

func get_cursor():
	if door_state == DoorState.LOCKED:
		return CursorManager.CursorState.LOCKED
	return CursorManager.CursorState.INTERACT

func set_outline(enable: bool) -> void:
	var color := GameColors.get_color(outline_color)
	if not highlightable:
		OutlineSystem.set_target(self, false, color)
		return
	OutlineSystem.set_target(self, enable, color)

func get_interaction_position() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return get_interaction_position_for_actor(player)


func get_interaction_position_for_actor(actor: Node3D) -> Vector3:
	if actor == null:
		return global_position

	var threshold_position := door_threshold.global_position
	var door_normal := door_threshold.global_transform.basis.z.normalized()

	var actor_side := (
		actor.global_position - threshold_position
	).dot(door_normal)

	var front_side := (
		interaction_front.global_position - threshold_position
	).dot(door_normal)

	if actor_side * front_side >= 0.0:
		return interaction_front.global_position

	return interaction_back.global_position


func _ready():
	map_marker_fill.color = GameColors.get_color(map_marker_color)
	refresh_visual()

	# حالت اولیه در
	if door_state == DoorState.OPEN:
		door.rotation = open_rotation
	else:
		door.rotation = closed_rotation


func interact():
	if door_state == DoorState.LOCKED:
		DialogueSystem.show_dialogue(
			Icon_default,
			"door_locked",
			1
		)
		return

	# تغییر وضعیت در
	if door_state == DoorState.OPEN:
		close_door()
	elif door_state == DoorState.CLOSED:
		open_door()


func needs_navigation_open() -> bool:
	return door_state == DoorState.CLOSED


func is_ready_for_navigation() -> bool:
	return door_state == DoorState.OPEN and door.rotation.distance_to(open_rotation) < 0.05


func open_door():
	# چرخش نرم به حالت باز
	door_state = DoorState.OPEN
	rotate_to(open_rotation)


func close_door():
	# چرخش نرم به حالت بسته
	door_state = DoorState.CLOSED
	rotate_to(closed_rotation)


func rotate_to(target_rotation: Vector3):
	if Engine.is_editor_hint():
		door.rotation = target_rotation
		return

	# tween برای چرخش نرم
	var tween = get_tree().create_tween()

	tween.tween_property(
		door,
		"rotation",
		target_rotation,
		open_speed
	)
	tween.finished.connect(
		func():
			_update_navigation_link()
	)

func _update_navigation_link():
	# Layer 1: all agents, for physically open doors.
	# Layer 2: player only, for closed but openable doors.
	# A locked door provides no navigation connection.
	navigation_link.enabled = door_state != DoorState.LOCKED
	navigation_link.navigation_layers = 1 if door_state == DoorState.OPEN else 2


func apply_material():
	if not is_instance_valid(mesh):
		return

	var door_mat: Material
	var frame_mat: Material

	match door_material:
		DoorMaterial.WOOD_MODERN:
			door_mat = preload(
				"res://data/materials/doors/wood_modern.tres"
			)

			frame_mat = preload(
				"res://data/materials/doors/wood_modern_frame.tres"
			)

		DoorMaterial.WOOD_BARN:
			door_mat = preload(
				"res://data/materials/doors/wood_barn.tres"
			)

			frame_mat = preload(
				"res://data/materials/doors/wood_barn_frame.tres"
			)

		DoorMaterial.METAL_GREEN:
			door_mat = preload(
				"res://data/materials/doors/metal_green.tres"
			)

			frame_mat = preload(
				"res://data/materials/doors/metal_green_frame.tres"
			)

		DoorMaterial.METAL_BLACK:
			door_mat = preload(
				"res://data/materials/doors/metal_black.tres"
			)

			frame_mat = preload(
				"res://data/materials/doors/metal_black_frame.tres"
			)

	mesh.material_override = door_mat
	frame_left.material_override = frame_mat
	frame_right.material_override = frame_mat
	frame_top.material_override = frame_mat


func _process(_delta):
	if not Engine.is_editor_hint():
		return

	if last_state != door_state or last_material != door_material:
		refresh_visual()
		last_state = door_state
		last_material = door_material


func apply_door_state():
	if Engine.is_editor_hint():
		if door_state == DoorState.OPEN:
			door.rotation = open_rotation
		else:
			door.rotation = closed_rotation


func refresh_visual():
	apply_material()
	apply_door_state()
	_update_navigation_link()
