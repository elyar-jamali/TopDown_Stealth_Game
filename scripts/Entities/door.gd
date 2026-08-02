extends Node3D

enum DoorState {
	CLOSED,
	OPEN,
	LOCKED
}
var original_material: Material
@export var door_state := DoorState.CLOSED

# Reference the StaticBody3D using its scene path
@onready var collision := $door/CollisionShape3D
@onready var mesh := $door/MeshInstance3D
@onready var door := $door
@onready var navigation_link: NavigationLink3D = $NavigationLink3D

# حداقل قاصله برای فعال شدن
@export var interaction_range := 0.0
# زاویه بسته و باز
@export var closed_rotation := Vector3(0, 0, 0)
@export var open_rotation := Vector3(0, PI/2, 0)
# سرعت باز و بسته شدن
@export var open_speed := 5.0
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
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 1.0, 0.102, 0.51)
		#mat.emission_enabled = true
		#mat.emission = Color(1.0, 0.85, 0.1)
		mesh.set_surface_override_material(0, mat)
	else:
		mesh.set_surface_override_material(0, original_material)
		
func get_interaction_position():
	var shape = collision.shape
	if shape is BoxShape3D:
		var p = global_position
		p.x -= collision.shape.size.z * 0.4
		p.z -= collision.shape.size.z * 0.5
		return p
	return global_position

func _ready():
	# حالت اولیه در
	rotation_degrees = closed_rotation
	if interaction_range <= 0:
		interaction_range = collision.shape.size.z * 0.8
	if door_state == DoorState.OPEN:
		door.rotate(Vector3.UP, PI/2)
		#open_door()
	original_material = mesh.get_active_material(0)
	_update_navigation_link()
	
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
	# tween برای چرخش نرم
	var tween = get_tree().create_tween()
	tween.tween_property(door, "rotation", target_rotation, 0.5)

func _update_navigation_link():
	navigation_link.enabled = door_state == DoorState.OPEN
