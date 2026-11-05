class_name SniperRecoil
extends SkeletonModifier3D

@export_group("Sniper Recoil")
@export_range(0.01, 0.3, 0.01) var kick_duration: float = 0.08
@export_range(0.1, 1.5, 0.01) var total_duration: float = 0.45

@export_range(-20.0, 20.0, 0.5) var recoil_angle: float = -15.0
@export var recoil_axis: Vector3 = Vector3.RIGHT

var recoil_start_time: float = -1.0
var upper_body_bone_index: int = -1


func _ready() -> void:
	var skeleton: Skeleton3D = get_skeleton()

	if skeleton == null:
		push_error("SniperRecoil: Skeleton3D not found.")
		return

	upper_body_bone_index = _find_upper_body_bone(skeleton)

	if upper_body_bone_index == -1:
		push_error("SniperRecoil: Upper body bone not found.")
		return


func fire() -> void:
	recoil_start_time = Time.get_ticks_msec() / 1000.0


func _process_modification() -> void:
	if recoil_start_time < 0.0:
		return

	if upper_body_bone_index == -1:
		return

	var elapsed: float = (
		Time.get_ticks_msec() / 1000.0 - recoil_start_time
	)

	if elapsed >= total_duration:
		recoil_start_time = -1.0
		return

	var strength: float = 0.0

	if elapsed <= kick_duration:
		strength = elapsed / maxf(kick_duration, 0.001)
	else:
		var recovery: float = (
			(elapsed - kick_duration)
			/ maxf(total_duration - kick_duration, 0.001)
		)

		strength = 1.0 - smoothstep(0.0, 1.0, recovery)

	strength = clampf(strength, 0.0, 1.0)

	if recoil_axis.length_squared() < 0.0001:
		return

	var skeleton: Skeleton3D = get_skeleton()

	if skeleton == null:
		return

	var original_rotation: Quaternion = (
		skeleton.get_bone_pose_rotation(upper_body_bone_index)
	)

	var rotation_offset := Quaternion(
		recoil_axis.normalized(),
		deg_to_rad(recoil_angle * strength)
	)

	skeleton.set_bone_pose_rotation(
		upper_body_bone_index,
		original_rotation * rotation_offset
	)


func _find_upper_body_bone(skeleton: Skeleton3D) -> int:
	var right_index: int = skeleton.find_bone("RightArm")
	var left_index: int = skeleton.find_bone("LeftArm")

	if right_index == -1 or left_index == -1:
		return -1

	var right_ancestors: Dictionary = {}
	var current_index: int = skeleton.get_bone_parent(right_index)

	while current_index != -1:
		right_ancestors[current_index] = true
		current_index = skeleton.get_bone_parent(current_index)

	current_index = skeleton.get_bone_parent(left_index)

	while current_index != -1:
		if right_ancestors.has(current_index):
			return current_index

		current_index = skeleton.get_bone_parent(current_index)

	return -1