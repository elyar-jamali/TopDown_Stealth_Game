@tool
extends EditorScript

const LIBRARY_PATH := "res://data/characters/animations/human_animations.res"

const ANIMATION_NAME := &"M_wakeup"

# اختلاف موقعیت پایان Knockout و شروع Wakeup
const START_OFFSET := Vector3(-0.297, 0.063, 1.043)


func _run() -> void:
	var library := load(LIBRARY_PATH) as AnimationLibrary

	if library == null:
		push_error("Animation library not found.")
		return

	var animation := library.get_animation(ANIMATION_NAME)

	if animation == null:
		push_error("M_wakeup animation not found.")
		return

	var animation_length := animation.length

	if animation_length <= 0.0:
		push_error("Invalid animation length.")
		return

	var fixed := false

	for track_index in range(animation.get_track_count()):

		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue

		var track_path := str(animation.track_get_path(track_index))

		if not track_path.contains("Hips"):
			continue

		var key_count := animation.track_get_key_count(track_index)

		for key_index in range(key_count):

			var key_time := animation.track_get_key_time(
				track_index,
				key_index
			)

			var original_position: Vector3 = animation.track_get_key_value(
				track_index,
				key_index
			)

			# پیشرفت انیمیشن از صفر تا یک
			var progress := clampf(
				key_time / animation_length,
				0.0,
				1.0
			)

			# کاهش تدریجی Offset
			var weight := 1.0 - smoothstep(
				0.0,
				1.0,
				progress
			)

			var corrected_position := (
				original_position + START_OFFSET * weight
			)

			animation.track_set_key_value(
				track_index,
				key_index,
				corrected_position
			)

		fixed = true

		print("Fixed Wakeup Hips track: ", track_path)

	if not fixed:
		push_error("Hips position track not found.")
		return

	var result := ResourceSaver.save(
		library,
		LIBRARY_PATH
	)

	if result == OK:
		print("M_wakeup position fixed successfully.")
	else:
		push_error("Failed to save animation library.")
