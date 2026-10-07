class_name CharacterAnimationData
extends RefCounted

enum Set {
	MALE,
	FEMALE
}

enum Action {
	IDLE,
	WALK,
	RUN,
	CROUCH_IDLE,
	CROUCH_WALK,
	TALK
}

const DATA := {
	Set.MALE: {
		Action.IDLE: {
			"animation": &"human_animations/M_idle"
		},
		Action.WALK: {
			"animation": &"human_animations/M_walk",
			"reference_speed": 2.0
		},
		Action.RUN: {
			"animation": &"human_animations/M_run",
			"reference_speed": 4.5
		},
		Action.CROUCH_IDLE: {
			"animation": &"human_animations/M_crouchidle"
		},
		Action.CROUCH_WALK: {
			"animation": &"human_animations/M_crouchwalk",
			"reference_speed": 2.0
		}
	},

	Set.FEMALE: {
		Action.IDLE: {
			"animation": &"human_animations/F_idle"
		},
		Action.WALK: {
			"animation": &"human_animations/F_walk",
			"reference_speed": 1.5
		},
		Action.RUN: {
			"animation": &"human_animations/F_run",
			"reference_speed": 5.0
		},
		Action.TALK: {
			"animation": &"human_animations/F_talk"
		}
	}
}

static func get_animation(animation_set: Set, action: Action) -> StringName:
	var set_data: Dictionary = DATA.get(animation_set, {})
	var action_data: Dictionary = set_data.get(action, {})
	return action_data.get("animation", &"")

static func get_reference_speed(animation_set: Set, action: Action) -> float:
	var set_data: Dictionary = DATA.get(animation_set, {})
	var action_data: Dictionary = set_data.get(action, {})
	return float(action_data.get("reference_speed", 0.0))

static func get_playback_speed(animation_set: Set, action: Action, movement_speed: float) -> float:
	var reference_speed := get_reference_speed(animation_set, action)

	if reference_speed <= 0.0:
		return 1.0

	return movement_speed / reference_speed