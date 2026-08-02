extends CharacterBody3D
class_name CharacterBase

@export var move_speed := 3.0

var move_target: Vector3
var has_target := false

func handle_input():
	pass

func _physics_process(delta):
	if GameManager.get_active_character() != self:
		return

	_handle_movement()


func _handle_movement():
	if not has_target:
		return

	var dir = (move_target - global_position)
	dir.y = 0

	if dir.length() < 0.2:
		has_target = false
		return

	dir = dir.normalized()

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	move_and_slide()


func set_move_target(pos: Vector3):
	move_target = pos
	has_target = true


func on_control_gained():
	pass


func on_control_lost():
	velocity = Vector3.ZERO
