extends GPUParticles3D
class_name BulletImpact

func _ready() -> void:
	emitting = false


func play_impact() -> void:
	restart()
	emitting = true

	await get_tree().create_timer(lifetime + 0.5).timeout
	queue_free()