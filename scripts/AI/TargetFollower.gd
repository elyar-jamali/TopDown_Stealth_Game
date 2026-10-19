class_name TargetFollower
extends RefCounted

enum UpdateResult { UNCHANGED, MOVED, LOST }

const REPATH_INTERVAL := 0.2
const REPATH_DISTANCE := 0.05
const UNREACHABLE_GRACE := 0.6

var target: Node3D
var last_position := Vector3.ZERO
var repath_elapsed := 0.0
var unreachable_elapsed := 0.0

func begin(new_target: Node3D) -> void:
    target = new_target
    last_position = target.call("get_interaction_position")
    repath_elapsed = 0.0
    unreachable_elapsed = 0.0

func cancel() -> void:
    target = null
    repath_elapsed = 0.0
    unreachable_elapsed = 0.0

func is_active() -> bool:
    return target != null

func update(delta: float, actor_position: Vector3, interaction_range: float, navigation_finished: bool, recovering: bool, max_distance: float) -> UpdateResult:
    if not is_instance_valid(target) or not target.is_inside_tree():
        return UpdateResult.LOST
    if not target.has_method("get_interaction_position"):
        return UpdateResult.LOST
    var target_position: Vector3 = target.call("get_interaction_position")
    var distance := actor_position.distance_to(target_position)
    if distance > max_distance:
        return UpdateResult.LOST
    if not recovering and navigation_finished and distance >= interaction_range:
        unreachable_elapsed += delta
        if unreachable_elapsed >= UNREACHABLE_GRACE:
            return UpdateResult.LOST
    else:
        unreachable_elapsed = 0.0
    repath_elapsed += delta
    if repath_elapsed >= REPATH_INTERVAL and _horizontal_distance(last_position, target_position) >= REPATH_DISTANCE:
        last_position = target_position
        repath_elapsed = 0.0
        return UpdateResult.MOVED
    return UpdateResult.UNCHANGED

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
