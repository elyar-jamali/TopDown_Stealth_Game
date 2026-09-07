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
@export var outline_color: Color = Color.YELLOW
@export var door_material := DoorMaterial.WOOD_MODERN
@export var door_state := DoorState.CLOSED
@export var object_id: String = ""
# سرعت باز و بسته شدن
@export var open_speed := 0.5


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

# حداقل قاصله برای فعال شدن
var interaction_range: float:
	get:
		if collision.shape is BoxShape3D:
			return collision.shape.size.z * 2
		return 2

# زاویه بسته و باز
var closed_rotation := Vector3(0, 0, 0)
var open_rotation := Vector3(0, PI/2, 0)

var Icon_default = preload("res://data/Pic/info.png")

# تا زمانی که نویگیشن درحال مسیریابی است مقدار true برمیگرداند
func wait_for_navigation_finish() -> bool:
	return true
	
func get_hover_text():
	return "Door_Caption"


func get_cursor():
	if door_state == DoorState.LOCKED:
		return CursorManager.CursorState.LOCKED

	return CursorManager.CursorState.INTERACT

func set_outline(enable: bool) -> void:
	if not highlightable:
		OutlineSystem.set_target(self, false, outline_color)
		return

	OutlineSystem.set_target(self, enable, outline_color)

func get_interaction_position():
	var shape = collision.shape
	if shape is BoxShape3D:
		var p = global_position
		p.x -= collision.shape.size.z * 0.4
		p.z -= collision.shape.size.z * 0.5
		return p
	return global_position

func _ready():

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


func open_door():
	# چرخش نرم به حالت باز
	rotate_to(open_rotation)
	door_state = DoorState.OPEN
	_update_navigation_link()


func close_door():
	# چرخش نرم به حالت بسته
	rotate_to(closed_rotation)
	door_state = DoorState.CLOSED
	_update_navigation_link()


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


func _update_navigation_link():
	navigation_link.enabled = door_state == DoorState.OPEN


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
