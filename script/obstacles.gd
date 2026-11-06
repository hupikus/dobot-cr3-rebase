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
		if child is not MeshInstance3D:
			continue
		
		child.material_override = obstacle_material
		
		var shell := MeshInstance3D.new()
		shell.name = "SafeArea"
			
		# Duplicating the mesh to inflate it
		var inflated_mesh: ArrayMesh
		if child.mesh is PrimitiveMesh:
			var arrays = child.mesh.get_mesh_arrays()
			inflated_mesh = ArrayMesh.new()
			inflated_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		elif child.mesh is ArrayMesh:
			inflated_mesh = child.mesh.duplicate()
		
		var st := SurfaceTool.new()
		st.create_from(inflated_mesh, 0)
		st.index()
		st.generate_normals()
		var welded: ArrayMesh = st.commit()
		
		var mdt := MeshDataTool.new()
		if mdt.create_from_surface(welded, 0) == OK:
			for i in mdt.get_vertex_count():
				var vertex := mdt.get_vertex(i)
				var normal := mdt.get_vertex_normal(i)
				mdt.set_vertex(i, vertex + normal * safe_thickness / child.scale)
		
		welded.clear_surfaces()
		mdt.commit_to_surface(welded)
		
		shell.mesh = welded
		
		shell.material_override = shell_mat
		child.add_child(shell)
		
		var shape := CollisionShape3D.new()
		if child.mesh == null:
			continue
		
		shape.shape = shell.mesh.create_trimesh_shape()
		shape.transform = child.transform
		add_child(shape)
		
		#geometry.append(CollisionGeometry.get_triangles(child)) 
	
	#add_child($"../Table/Collision")
	collision_layer = 1
	collision_mask = 2
	monitoring = true
	monitorable = true
