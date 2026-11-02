extends Node

@export var safe_thickness = 0.02

var obstacle_material := ShaderMaterial.new()
var shell_mat := ShaderMaterial.new()

var obstacle_shader = preload("res://shaders/obstacle_mesh.gdshader")
var shell_shader = preload("res://shaders/safety_area.gdshader")

func _ready() -> void:
	obstacle_material.shader = obstacle_shader
	shell_mat.shader = shell_shader
	shell_mat.set_shader_parameter("thickness", safe_thickness)
	
	for child in get_children():
		child.material_override = obstacle_material
		
		var shell := MeshInstance3D.new()
		shell.name = "SafeArea"
		shell.mesh = child.mesh
		
		shell.material_override = shell_mat
		child.add_child(shell)
