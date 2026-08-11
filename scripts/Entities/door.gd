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
@export var door_material := DoorMaterial.WOOD_MODERN
@export var door_state := DoorState.CLOSED
@export var object_id: String = ""
# سرعت باز و بسته شدن
@export var open_speed := 0.5

var last_state = -1
var last_material = -1
var original_material: Material
var highlight_material: Material
# Reference the StaticBody3D using its scene path
@onready var collision := $door/CollisionShape3D
@onready var mesh := $door/MeshInstance3D
@onready var door := $door
@onready var navigation_link: NavigationLink3D = $NavigationLink3D

@onready var frame_left: MeshInstance3D = $frame/LeftSide
@onready var frame_right: MeshInstance3D = $frame/RightSide
@onready var frame_top: MeshInstance3D = $frame/UpSide

# حداقل قاصله برای فعال شدن
var interaction_range: float:
	get:
		if collision.shape is BoxShape3D:
			return collision.shape.size.z * 0.9
		return 1
# زاویه بسته و باز
var closed_rotation := Vector3(0, 0, 0)
var open_rotation := Vector3(0, PI/2, 0)

var Icon_default = preload("res://data/Pic/info.png")

func get_hover_text():
	return "Door_Caption"

func get_cursor():
	if door_state==DoorState.LOCKED:
		return (CursorManager.CursorState.LOCKED)
	else:
		return (CursorManager.CursorState.INTERACT)

func set_outline(enable: bool):
	if enable:
		if highlight_material == null:
			highlight_material = StandardMaterial3D.new()
			highlight_material.albedo_color = Color(1.0, 1.0, 0.102, 0.8)
			highlight_material.emission_enabled = true
			highlight_material.emission = Color(1.0, 0.85, 0.1)
		
		mesh.material_override = highlight_material
	else:
		mesh.material_override = null
		apply_material()
	
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
	original_material = mesh.material_override
	# حالت اولیه در
	#print("Door:", name)
	#print("Interaction range before:", interaction_range)
	#if interaction_range <= 0:
	#	interaction_range = collision.shape.size.z * 0.2
	#	print(interaction_range)
	if door_state == DoorState.OPEN:
		door.rotation = open_rotation
	else:
		door.rotation = closed_rotation

	original_material = mesh.get_active_material(0)
	
func interact():
	if door_state == DoorState.LOCKED:
		DialogueSystem.show_dialogue(Icon_default, "door_locked", 1)
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
	tween.tween_property(door, "rotation", target_rotation, open_speed)

func _update_navigation_link():
	navigation_link.enabled = door_state == DoorState.OPEN

func apply_material():
	if not is_instance_valid(mesh):
		return
	var door_mat: Material
	var frame_mat: Material
	match door_material:
		DoorMaterial.WOOD_MODERN:
			door_mat = preload("res://data/materials/doors/wood_modern.tres")
			frame_mat = preload("res://data/materials/doors/wood_modern_frame.tres")
		DoorMaterial.WOOD_BARN:
			door_mat = preload("res://data/materials/doors/wood_barn.tres")
			frame_mat = preload("res://data/materials/doors/wood_barn_frame.tres")
		DoorMaterial.METAL_GREEN:
			door_mat = preload("res://data/materials/doors/metal_green.tres")
			frame_mat = preload("res://data/materials/doors/metal_green_frame.tres")
		DoorMaterial.METAL_BLACK:
			door_mat = preload("res://data/materials/doors/metal_black.tres")
			frame_mat = preload("res://data/materials/doors/metal_black_frame.tres")
	mesh.material_override = door_mat
	frame_left.material_override = frame_mat
	frame_right.material_override = frame_mat
	frame_top.material_override = frame_mat

func _process(delta):
	if last_material != door_material or last_state != door_state:
		refresh_visual()
		last_material = door_material
		last_state = door_state

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
