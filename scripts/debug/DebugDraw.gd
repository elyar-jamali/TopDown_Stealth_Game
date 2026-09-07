extends Node3D

var immediate_mesh := ImmediateMesh.new()
var mesh_instance := MeshInstance3D.new()
var material := StandardMaterial3D.new()

func _ready():
	add_child(mesh_instance)
	mesh_instance.mesh = immediate_mesh

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true


func clear():
	immediate_mesh.clear_surfaces()


func line(from: Vector3, to: Vector3, color: Color):
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

	immediate_mesh.surface_set_color(color)
	immediate_mesh.surface_add_vertex(from)

	immediate_mesh.surface_set_color(color)
	immediate_mesh.surface_add_vertex(to)

	immediate_mesh.surface_end()


func cross(pos: Vector3, size := 0.3, color := Color.RED):
	line(pos + Vector3.LEFT * size, pos + Vector3.RIGHT * size, color)
	line(pos + Vector3.FORWARD * size, pos + Vector3.BACK * size, color)
	line(pos + Vector3.DOWN * size, pos + Vector3.UP * size, color)
