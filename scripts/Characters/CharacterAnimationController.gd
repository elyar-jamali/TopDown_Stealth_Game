class_name CharacterAnimationController
extends Node

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
	TALK,
	GARROTE,
	GARROTED,
	WAKEUP_FRONT,
	WAKEUP_BACK,
	PUNCH,
	PISTOL,
	CROUCH_PISTOL
}

var animation_set: Set = Set.MALE
@export_range(0.0, 1.0, 0.01) var default_blend_time: float = 0.2

var animation_player: AnimationPlayer

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
		},
		Action.TALK: {
			"animation": &"human_animations/M_talk"
		},
		Action.GARROTE: {
			"animation": &"human_animations/M_garrote"
		},
		Action.GARROTED: {
			"animation": &"human_animations/M_garroted"
		},
		Action.WAKEUP_FRONT: {
			"animation": &"human_animations/M_wakeup_F",
			"playback_speed": 2.0
		},
		Action.WAKEUP_BACK: {
			"animation": &"human_animations/M_wakeup_B",
			"playback_speed": 0.5
		},
		Action.PUNCH: {
			"animation": &"human_animations/M_punch"
		},
		Action.PISTOL: {
			"animation": &"human_animations/M_pistol"
		},
		Action.CROUCH_PISTOL: {
			"animation": &"human_animations/M_crouchpistol"
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
		Action.CROUCH_IDLE: {
			"animation": &"human_animations/F_crouchidle"
		},
		Action.CROUCH_WALK: {
			"animation": &"human_animations/F_crouchwalk",
			"reference_speed": 2.0
		},
		Action.TALK: {
			"animation": &"human_animations/F_talk"
		},
		Action.GARROTE: {
			"animation": &"human_animations/F_garrote"
		},
		Action.GARROTED: {
			"animation": &"human_animations/F_garroted"
		},
		Action.WAKEUP_FRONT: {
			"animation": &"human_animations/F_wakeup_F",
			"playback_speed": 2.0
		},
		Action.WAKEUP_BACK: {
			"animation": &"human_animations/F_wakeup_B",
			"playback_speed": 0.5
		},
		Action.PUNCH: {
			"animation": &"human_animations/F_punch"
		},
		Action.PISTOL: {
			"animation": &"human_animations/F_pistol"
		},		
		Action.CROUCH_PISTOL: {
			"animation": &"human_animations/F_crouchpistol"
		}		
	}
}


func _ready() -> void:
	call_deferred("refresh_animation_player")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result

	return null


func get_animation(action: Action) -> StringName:
	var set_data: Dictionary = DATA.get(animation_set, {})
	var action_data: Dictionary = set_data.get(action, {})
	return action_data.get("animation", &"")


func get_reference_speed(action: Action) -> float:
	var set_data: Dictionary = DATA.get(animation_set, {})
	var action_data: Dictionary = set_data.get(action, {})
	return float(action_data.get("reference_speed", 0.0))


func get_playback_speed(action: Action, movement_speed: float) -> float:
	var reference_speed := get_reference_speed(action)

	if reference_speed <= 0.0:
		return 1.0

	return movement_speed / reference_speed


func play_action(
	action: Action,
	blend_time: float = -1.0,
	movement_speed: float = -1.0
) -> void:
	var animation_name := get_animation(action)

	if animation_name == &"":
		push_warning("Animation action is not configured: " + str(action))
		return

	var playback_speed := get_action_speed(action)

	if movement_speed >= 0.0:
		playback_speed = get_playback_speed(action, movement_speed)

	play_named(animation_name, blend_time, playback_speed)


func play_named(
	animation_name: StringName,
	blend_time: float = -1.0,
	playback_speed: float = 1.0
) -> void:
	if animation_player == null:
		push_warning("AnimationPlayer is not assigned.")
		return

	if not animation_player.has_animation(animation_name):
		push_warning("Animation not found: " + str(animation_name))
		return

	var duration := default_blend_time if blend_time < 0.0 else blend_time
	duration = maxf(duration, 0.0)

	if animation_player.current_animation == animation_name and animation_player.is_playing():
		animation_player.speed_scale = playback_speed
		return

	animation_player.speed_scale = playback_speed
	animation_player.play(animation_name, duration)


func stop() -> void:
	if animation_player != null:
		animation_player.stop()


func pause() -> void:
	if animation_player != null:
		animation_player.pause()

func get_action_speed(action: Action) -> float:
	var set_data: Dictionary = DATA.get(animation_set, {})
	var action_data: Dictionary = set_data.get(action, {})
	return float(action_data.get("playback_speed", 1.0))


func has_action(action: Action) -> bool:
	if animation_player == null:
		return false

	var animation_name := get_animation(action)
	return animation_name != &"" and animation_player.has_animation(animation_name)

func configure_gender(gender: Set) -> void:
	animation_set = gender



func refresh_animation_player() -> void:
	var found_player := _find_animation_player(get_parent())

	if found_player == null:
		if Engine.is_editor_hint():
			return

		push_warning(
			"CharacterAnimationController: AnimationPlayer not found on %s" % get_parent().name
		)
		return

	animation_player = found_player
