class_name PistolRecoil
extends SkeletonModifier3D

@export_group("Recoil Settings")
@export_range(0.01, 0.2) var kick_duration: float = 0.07
@export_range(0.05, 0.5) var total_duration: float = 0.30

@export_range(-30.0, 30.0) var right_angle: float = 30.0
@export_range(-30.0, 30.0) var left_angle: float = 15.0

@export var right_axis: Vector3 = Vector3.RIGHT
@export var left_axis: Vector3 = Vector3.RIGHT

var recoil_start_time: float = -1.0
################################
@export_group("Aim Pitch Settings")
@export_range(0.0, 2.0, 0.05) var aim_pitch_weight: float = 1.0
@export_range(0.0, 60.0, 1.0) var max_aim_pitch: float = 60.0


@export var upper_body_axis: Vector3 = Vector3.RIGHT
@export_range(-1.0, 1.0, 0.1) var upper_body_direction: float = -1.0

var aim_pitch_degrees: float = 0.0
#################################

func fire() -> void:
	recoil_start_time = Time.get_ticks_msec() / 1000.0

func set_aim_pitch(angle_radians: float) -> void:
	aim_pitch_degrees = clampf(
		rad_to_deg(angle_radians),
		-max_aim_pitch,
		max_aim_pitch
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

# func _process_modification() -> void:
# 	if recoil_start_time < 0.0:
# 		return

# 	var elapsed: float = Time.get_ticks_msec() / 1000.0 - recoil_start_time

# 	if elapsed >= total_duration:
# 		recoil_start_time = -1.0
# 		return

# 	var strength: float = 0.0

# 	if elapsed <= kick_duration:
# 		strength = elapsed / kick_duration
# 	else:
# 		strength = 1.0 - (elapsed - kick_duration) / maxf(total_duration - kick_duration, 0.001)

# 	strength = clampf(strength, 0.0, 1.0)

# 	var skeleton := get_skeleton()
# 	if skeleton == null:
# 		return

# 	_rotate_forearm(skeleton, "RightForeArm", right_axis, right_angle * strength)
# 	_rotate_forearm(skeleton, "LeftForeArm", left_axis, left_angle * strength)

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return

	# Aim Pitch: independent of recoil
	var pitch: float = aim_pitch_degrees * aim_pitch_weight

	if absf(pitch) > 0.001 and upper_body_axis.length_squared() > 0.0001:
		var upper_body_index: int = _find_upper_body_bone(skeleton)

		if upper_body_index != -1:
			var original_rotation: Quaternion = skeleton.get_bone_pose_rotation(
				upper_body_index
			)

			var rotation_offset := Quaternion(
				upper_body_axis.normalized(),
				deg_to_rad(pitch * upper_body_direction)
			)

			skeleton.set_bone_pose_rotation(
				upper_body_index,
				original_rotation * rotation_offset
			)

	# Recoil: only active for a short time after firing
	if recoil_start_time < 0.0:
		return

	var elapsed: float = Time.get_ticks_msec() / 1000.0 - recoil_start_time

	if elapsed >= total_duration:
		recoil_start_time = -1.0
		return

	var strength: float = 0.0

	if elapsed <= kick_duration:
		strength = elapsed / kick_duration
	else:
		strength = 1.0 - (
			elapsed - kick_duration
		) / maxf(total_duration - kick_duration, 0.001)

	strength = clampf(strength, 0.0, 1.0)

	_rotate_forearm(
		skeleton,
		"RightForeArm",
		right_axis,
		right_angle * strength
	)

	_rotate_forearm(
		skeleton,
		"LeftForeArm",
		left_axis,
		left_angle * strength
	)

func _rotate_forearm(
	skeleton: Skeleton3D,
	bone_name: String,
	axis: Vector3,
	angle: float
) -> void:
	var bone_index := skeleton.find_bone(bone_name)
	if bone_index == -1 or axis.length_squared() < 0.0001:
		return

	var original_rotation := skeleton.get_bone_pose_rotation(bone_index)
	var offset := Quaternion(axis.normalized(), deg_to_rad(angle))

	skeleton.set_bone_pose_rotation(bone_index, original_rotation * offset)