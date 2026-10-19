extends PhysicalBoneSimulator3D

@export var angular_damping: float = 3.0
@export var minimum_fall_time: float = 0.45
@export var maximum_fall_time: float = 1.80
@export var settle_speed: float = 0.55
@export var required_settle_time: float = 0.15

var ragdoll_active: bool = false
var pose_frozen: bool = false

var _fall_elapsed: float = 0.0
var _settle_elapsed: float = 0.0
var _last_poses: Array[Transform3D] = []
var _has_pose_sample: bool = false

@onready var _skeleton: Skeleton3D = get_skeleton()
@onready var _hips: PhysicalBone3D = get_node_or_null("Physical Bone Hips") as PhysicalBone3D
@onready var _spine: PhysicalBone3D = get_node_or_null("Physical Bone Spine") as PhysicalBone3D
@onready var _neck: PhysicalBone3D = get_node_or_null("Physical Bone Neck") as PhysicalBone3D

func _ready() -> void:
	physical_bones_stop_simulation()
	for child in get_children():
		if child is PhysicalBone3D:
			child.angular_damp = angular_damping
	modification_processed.connect(_capture_simulated_pose)
	set_physics_process(false)
	set_process_unhandled_key_input(true)


func start_ragdoll(hit_direction: Vector3 = Vector3.ZERO, impulse_strength: float = 0.0) -> void:
	if ragdoll_active or pose_frozen:
		return

	if _skeleton == null:
		push_error("RagdollDriver: Skeleton3D was not found")
		return

	_fall_elapsed = 0.0
	_settle_elapsed = 0.0
	_has_pose_sample = false
	_last_poses.clear()
	ragdoll_active = true

	physical_bones_start_simulation([&"Hips"])
	set_physics_process(true)

	var direction := hit_direction
	direction.y = 0.0
	if impulse_strength <= 0.0 or direction.length_squared() <= 0.0001:
		return

	await get_tree().physics_frame
	if not is_inside_tree() or not ragdoll_active:
		return
	if _neck != null and _neck.is_simulating_physics():
		var impulse := direction.normalized() * impulse_strength * 2
		_neck.apply_central_impulse(impulse)

		if _spine != null and _spine.is_simulating_physics():
			var impact_offset := Vector3.UP * 0.45
			_spine.apply_impulse(impulse * 0.5, impact_offset)


func _capture_simulated_pose() -> void:
	if not ragdoll_active or _skeleton == null:
		return

	_last_poses.clear()
	for bone_index in range(_skeleton.get_bone_count()):
		_last_poses.append(_skeleton.get_bone_pose(bone_index))
	_has_pose_sample = true


func _physics_process(delta: float) -> void:
	if not ragdoll_active:
		return

	_fall_elapsed += delta
	if _fall_elapsed < minimum_fall_time or not _has_pose_sample:
		return

	var speed := INF
	if _hips != null and _hips.is_simulating_physics():
		speed = _hips.linear_velocity.length()

	if _neck != null and _neck.is_simulating_physics():
		speed = maxf(speed, _neck.linear_velocity.length())

	if speed < settle_speed:
		_settle_elapsed += delta
	else:
		_settle_elapsed = 0.0

	if _settle_elapsed >= required_settle_time or _fall_elapsed >= maximum_fall_time:
		stop_ragdoll()


func stop_ragdoll() -> void:
	if not ragdoll_active or not _has_pose_sample or _skeleton == null:
		return
	if _hips != null and _neck != null:
		var fallen_axis := _neck.global_position - _hips.global_position
		fallen_axis.y = 0.0

	# The modifier has already supplied the final visible local bone poses.
	physical_bones_stop_simulation()
	for bone_index in range(mini(_skeleton.get_bone_count(), _last_poses.size())):
		_skeleton.set_bone_pose(bone_index, _last_poses[bone_index])

	ragdoll_active = false
	pose_frozen = true
	set_physics_process(false)


func _exit_tree() -> void:
	if ragdoll_active:
		physical_bones_stop_simulation()
		ragdoll_active = false
