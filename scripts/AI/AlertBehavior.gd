extends Node
class_name AlertBehavior

signal alert_started(reason: AlertReason)
signal alert_finished

enum AlertReason {
	WAKE_UP,
	SUSPICIOUS_SOUND,
	PLAYER_SPOTTED
}

var active: bool = false
var current_reason: AlertReason = AlertReason.WAKE_UP

var duration: float = 0.0
var time_remaining: float = 0.0

var alert_position: Vector3 = Vector3.ZERO
var alert_target: Node3D = null


func start_alert(
	reason: AlertReason,
	alert_time: float,
	position: Vector3,
	target: Node3D = null
) -> void:
	active = true
	current_reason = reason

	duration = maxf(alert_time, 0.01)
	time_remaining = duration

	alert_position = position
	alert_target = target

	alert_started.emit(reason)


func update_alert(delta: float) -> void:
	if not active:
		return

	time_remaining = maxf(time_remaining - delta, 0.0)

	if time_remaining <= 0.0:
		stop_alert()


func stop_alert() -> void:
	if not active:
		return

	active = false
	alert_target = null

	alert_finished.emit()


func get_progress() -> float:
	if duration <= 0.0:
		return 0.0

	return time_remaining / duration