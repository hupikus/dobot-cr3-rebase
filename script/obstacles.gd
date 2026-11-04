extends Area3D

@export var safe_thickness = 0.02

const OBSTACLE_LAYER := 2

var obstacle_material := ShaderMaterial.new()
var shell_mat := ShaderMaterial.new()

var obstacle_shader = preload("res://shaders/obstacle_mesh.gdshader")
var shell_shader = preload("res://shaders/safety_area.gdshader")

@onready var table = $"../Table/Mesh"

#var geometry: Array = []
#var collision: CollisionGeometry = CollisionGeometry.new() 
var collision: Array = []

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
	
	for child in get_children() + [$"../Table/Mesh"]:
		var shape := CollisionShape3D.new()
		if child.mesh == null:
			continue
		
		shape.shape = child.mesh.create_trimesh_shape()
		shape.transform = child.transform
		add_child(shape)
		
		#geometry.append(CollisionGeometry.get_triangles(child)) 
	
	collision_layer = 1
	collision_mask = 2
	monitoring = true
	monitorable = true
