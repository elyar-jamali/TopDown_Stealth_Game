
@tool
extends EditorPlugin

const VISUAL_SCENES := [
	"res://scenes/characters/male_visual.tscn",
	"res://scenes/characters/female_visual.tscn"
]

const APPEARANCE_SCENES := [
	"res://data/characters/appearances/male_suit/male_suit_appearance.tscn",
	"res://data/characters/appearances/male_worker/male_worker_appearance.tscn",
	"res://data/characters/appearances/female_casual/female_casual_appearance.tscn",
	"res://data/characters/appearances/female_elegant/female_elegant_appearance.tscn"
]

var previews: Dictionary = {}


func _enter_tree() -> void:
	scene_changed.connect(_on_scene_changed)
	scene_saved.connect(_on_scene_saved)
	EditorInterface.get_inspector().property_edited.connect(_on_property_edited)

	call_deferred("_refresh_scene")


func _exit_tree() -> void:
	_clear_all_previews()

	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)

	if scene_saved.is_connected(_on_scene_saved):
		scene_saved.disconnect(_on_scene_saved)

	var inspector := EditorInterface.get_inspector()
	if inspector.property_edited.is_connected(_on_property_edited):
		inspector.property_edited.disconnect(_on_property_edited)


func _apply_changes() -> void:
	# Remove temporary visuals and restore original visibility before saving.
	_clear_all_previews()


func _on_scene_changed(_root: Node) -> void:
	_clear_all_previews()
	call_deferred("_refresh_scene")


func _on_scene_saved(_path: String) -> void:
	call_deferred("_refresh_scene")


func _on_property_edited(property: StringName) -> void:
	if property != &"character_appearance":
		return

	call_deferred("_refresh_scene")


func _is_npc(node: Node) -> bool:
	if not node is Node3D:
		return false

	if not node.has_node("Visual"):
		return false

	for property in node.get_property_list():
		if property["name"] == "character_appearance":
			return true

	return false


func _collect_npcs(node: Node, result: Array[Node3D]) -> void:
	if _is_npc(node):
		result.append(node as Node3D)

	for child in node.get_children():
		_collect_npcs(child, result)


func _refresh_scene() -> void:
	_clear_all_previews()

	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return

	var npcs: Array[Node3D] = []
	_collect_npcs(root, npcs)

	for npc in npcs:
		_create_preview(npc)


func _create_preview(npc: Node3D) -> void:
	var original := npc.get_node_or_null("Visual") as Node3D
	if original == null:
		return

	var appearance := int(npc.get("character_appearance"))

	if appearance < 0 or appearance >= APPEARANCE_SCENES.size():
		return

	var gender := 0 if appearance < 2 else 1

	var visual_scene := load(VISUAL_SCENES[gender]) as PackedScene
	var appearance_scene := load(
		APPEARANCE_SCENES[appearance]
	) as PackedScene

	if visual_scene == null or appearance_scene == null:
		push_warning("NPC Preview: Could not load character resources.")
		return

	var visual := visual_scene.instantiate() as Node3D

	if visual == null:
		push_warning("NPC Preview: Invalid Visual root.")
		return

	var skeleton := visual.find_child(
		"Skeleton3D", true, false
	) as Skeleton3D

	if skeleton == null:
		visual.free()
		push_warning("NPC Preview: Skeleton3D not found.")
		return

	var old_appearance := skeleton.get_node_or_null("Appearance")

	if old_appearance != null:
		skeleton.remove_child(old_appearance)
		old_appearance.free()

	var new_appearance := appearance_scene.instantiate()
	new_appearance.name = "Appearance"
	skeleton.add_child(new_appearance)

	var original_visible := original.visible

	visual.name = "_EditorVisualPreview"
	npc.add_child(visual)
	visual.transform = original.transform

	# The preview has no owner and is not saved.
	# Hide the entire original visual, including its skeleton gizmos.
	original.visible = false

	previews[npc.get_instance_id()] = {
		"original": original,
		"original_visible": original_visible,
		"preview": visual
	}


func _clear_preview(id: int) -> void:
	if not previews.has(id):
		return

	var data: Dictionary = previews[id]
	var original: Node3D = data["original"]
	var preview: Node3D = data["preview"]

	if is_instance_valid(original):
		original.visible = data["original_visible"]

	if is_instance_valid(preview):
		preview.free()

	previews.erase(id)


func _clear_all_previews() -> void:
	for id in previews.keys():
		_clear_preview(id)
