extends Node3D

enum DoorType {
	NORMAL,
	LOCKED
}
var original_material: Material
@export var door_type := DoorType.NORMAL
# وضعیت در (باز یا بسته)
@export var is_open := false
# Reference the StaticBody3D using its scene path
@onready var collision := $CollisionShape3D
@onready var mesh := $MeshInstance3D
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
	if door_type==DoorType.NORMAL:
		return (CursorManager.CursorState.INTERACT)
	else:
		return (CursorManager.CursorState.LOCKED)

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
	if is_open:
		self.rotate(Vector3.UP, PI/2)
		#open_door()
	original_material = mesh.get_active_material(0)
	
func interact():
	if door_type == DoorType.LOCKED:
		DialogueSystem.show_dialogue(Icon_default, "door_locked", 1)
		return
	# تغییر وضعیت در
	is_open = !is_open
	if is_open:
		open_door()
	else:
		close_door()

func open_door():
	# چرخش نرم به حالت باز
	rotate_to(open_rotation)

func close_door():
	# چرخش نرم به حالت بسته
	rotate_to(closed_rotation)

func rotate_to(target_rotation: Vector3):
	# tween برای چرخش نرم
	var tween = get_tree().create_tween()
	tween.tween_property(self, "rotation", target_rotation, 0.5)
