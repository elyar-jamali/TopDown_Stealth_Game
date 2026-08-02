extends Node3D
#extends CharacterBody3D

enum NPCType {
	Civilian,
	Guard
}
@onready var mesh := $NPC/MeshInstance3D

@export var npc_name := NPCType.Civilian
@export var can_talk := true
@export var hostile := false
@export var Icon_default = load("res://data/Pic/civil1.jpg")

@export var interaction_range := 0.0
@onready var collision := $NPC/CollisionShape3D
#@onready var agent: NavigationAgent3D = $NPC/NavigationAgent3D

var original_material: Material
var highlight_material:= StandardMaterial3D.new()
		
func _ready():
	highlight_material.albedo_color = Color(1.0, 1.0, 0.102, 0.51)
	#highlight_material.emission_enabled = true
	#highlight_material.emission = Color(1.0, 1.0, 0.102, 0.51)
	original_material = mesh.get_active_material(0)
	if interaction_range <= 0:
		var shape = collision.shape
		if shape is CapsuleShape3D:
			interaction_range = shape.radius * 4
		elif shape is SphereShape3D:
			interaction_range = shape.radius * 4
		else:
			interaction_range = 2.5

#func _physics_process(delta):
#	agent.velocity = Vector3.ZERO
func get_hover_text():
	return "NPC"+var_to_str(npc_name)

func get_interaction_position():
	return global_position

func interact():
	if hostile:
		_handle_hostile()

	if can_talk:
		_handle_talk()
	
func _handle_talk():
	DialogueSystem.show_dialogue(Icon_default, "npc_guard_hello")

func _handle_hostile():
	DialogueSystem.show_dialogue(Icon_default, "npc_hostile_warning")

func set_outline(enable: bool):
	if enable:
		mesh.set_surface_override_material(0, highlight_material)
	else:
		mesh.set_surface_override_material(0, original_material)
