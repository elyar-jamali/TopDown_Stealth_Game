extends Node

enum Action {
	NORMAL,
	KNOCKOUT,
	GARROTE
}

signal action_changed(action: Action)

var selected_action: Action = Action.NORMAL
const MELEE_RANGE: float = 1.1
var pending_action: Action = Action.NORMAL

# Stage 1: centralize the existing interaction and moving-target follow logic.
# Action selection, cursors, knockout and kill will be added in later stages.
const TargetFollowerScript = preload("res://scripts/AI/TargetFollower.gd")

var pending_interaction: Node = null
var interaction_actor : CharacterBody3D = null
var target_follower = TargetFollowerScript.new()


func raycast(
	camera: Camera3D,
	mouse_pos: Vector2,
	ray_length: float,
	exclude: Array[RID] = []
) -> Dictionary:
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_direction * ray_length
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = exclude
	return camera.get_world_3d().direct_space_state.intersect_ray(query)


func interact(target: Node) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("interact"):
		target.interact()


func is_following() -> bool:
	return target_follower.is_active()


func begin_pending(actor: CharacterBody3D, target: Node) -> void:
	cancel_pending()

	if not is_instance_valid(target):
		return

	if not target.has_method("get_interaction_position"):
		return

	var action_to_perform: Action = Action.NORMAL

	if selected_action != Action.NORMAL:
		if target.has_method("knockout") and target.has_method("kill"):
			if not target.targetable:
				return

			if not target.is_alive():
				return

			match selected_action:
				Action.KNOCKOUT:
					if not target.can_knockout:
						return

				Action.GARROTE:
					if not target.can_kill:
						return

			action_to_perform = selected_action

	interaction_actor = actor
	pending_interaction = target
	pending_action = action_to_perform

	actor._set_movement_target(
		target.get_interaction_position()
	)

	if target is CharacterBody3D:
		target_follower.begin(target as Node3D)


func cancel_pending(stop_actor: bool = false) -> void:
	var actor: CharacterBody3D = interaction_actor

	pending_interaction = null
	interaction_actor = null
	pending_action = Action.NORMAL

	target_follower.cancel()

	if stop_actor and is_instance_valid(actor):
		actor._stop_movement()


func update_pending(delta: float) -> bool:
	if pending_interaction == null:
		return false

	if not is_instance_valid(interaction_actor):
		cancel_pending()
		return true

	if not is_instance_valid(pending_interaction):
		cancel_pending(true)
		return true

	if not pending_interaction.has_method("get_interaction_position"):
		cancel_pending(true)
		return true

	var actor: CharacterBody3D = interaction_actor

	var required_range: float = pending_interaction.interaction_range

	if pending_action != Action.NORMAL:
		required_range = MELEE_RANGE

	if target_follower.is_active():
		if pending_interaction.has_method("is_alive"):
			if not pending_interaction.is_alive():
				cancel_pending(true)
				return true

		var follow_result: int = target_follower.update(
			delta,
			actor.global_position,
			required_range,
			actor.agent.is_navigation_finished(),
			actor.is_using_detour or actor.is_using_short_escape,
			actor.interaction_chase_max_distance
		)

		if follow_result == TargetFollowerScript.UpdateResult.LOST:
			cancel_pending(true)
			return true

		if follow_result == TargetFollowerScript.UpdateResult.MOVED:
			actor._set_movement_target(
				target_follower.last_position,
				true
			)

	# برای تعامل معمولی، رفتار قبلی Navigation حفظ می‌شود.
	# برای حمله نزدیک، منتظر رسیدن به مرکز NPC نمی‌مانیم.
	if pending_action == Action.NORMAL:
		if pending_interaction.has_method("wait_for_navigation_finish"):
			if pending_interaction.wait_for_navigation_finish():
				if not actor.agent.is_navigation_finished():
					return false

	var interaction_position: Vector3 = (
		pending_interaction.get_interaction_position()
	)

	var distance: float

	if pending_action == Action.NORMAL:
		distance = actor.global_position.distance_to(
			interaction_position
		)
	else:
		distance = Vector2(
			actor.global_position.x,
			actor.global_position.z
		).distance_to(
			Vector2(
				interaction_position.x,
				interaction_position.z
			)
		)

	if distance >= required_range:
		return false

	var target: Node = pending_interaction
	var action: Action = pending_action

	cancel_pending()
	actor._stop_movement()

	if action == Action.KNOCKOUT:
		if actor.has_method("play_knockout_punch"):
			actor.play_knockout_punch(target)
	
	elif action == Action.GARROTE:
		if target.has_method("align_for_garrote"):
			target.align_for_garrote(actor)

		if actor.has_method("play_garrote"):
			actor.play_garrote(target)

		if target.has_method("play_garroted"):
			target.play_garroted()

	_execute_pending_action(target, action, actor)

	return true

func select_action(action: Action) -> void:
	if selected_action == action:
		return

	selected_action = action
	_update_action_cursor()
	action_changed.emit(selected_action)


func clear_selected_action() -> void:
	select_action(Action.NORMAL)


func _update_action_cursor() -> void:
	match selected_action:
		Action.NORMAL:
			CursorManager.clear_action_state()

		Action.KNOCKOUT:
			CursorManager.set_action_state(
				CursorManager.CursorState.KNOCKOUT
			)

		Action.GARROTE:
			CursorManager.set_action_state(
				CursorManager.CursorState.GARROTE
			)


func has_active_command(actor: CharacterBody3D) -> bool:
	if pending_interaction != null:
		return true

	if actor.is_using_detour or actor.is_using_short_escape:
		return true

	var current_pos: Vector3 = actor.global_position
	var target_pos: Vector3 = actor.final_target

	var distance: float = Vector2(
		current_pos.x,
		current_pos.z
	).distance_to(
		Vector2(target_pos.x, target_pos.z)
	)

	return distance > actor.agent.target_desired_distance

func _execute_pending_action(
	target: Node,
	action: Action,
	actor: CharacterBody3D
) -> void:
	if not is_instance_valid(target):
		return

	match action:
		Action.NORMAL:
			interact(target)

		Action.KNOCKOUT:
			if target.has_method("knockout_from"):
				target.knockout_from(actor)
			elif target.has_method("knockout"):
				target.knockout()

		Action.GARROTE:
			if target.has_method("kill"):
				target.kill()
