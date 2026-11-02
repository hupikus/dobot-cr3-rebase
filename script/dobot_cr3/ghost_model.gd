extends Node

@export var base_color: Color = Color(0.35, 0.65, 1.0, 0.35)
@export var base_color_error: Color = Color(1.0, 0.2, 0.2, 0.5)

@export var handle_color: Color = Color(1.0, 0.85, 0.2)

@export var handle_scale: float = 1

@onready var ghost = $".."
@onready var meshes: Array[Node3D] = [
	$"CR3-BASE/CR3_J1/LINK2-CR3A",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4/CR3_J5",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4/CR3_J5/CR3-J6_CR3_2__CR30001_1_2",
]

var handles: Array[Node3D]

var base_material := StandardMaterial3D.new()
var handle_material := StandardMaterial3D.new()


var sphere := SphereMesh.new()

func _ready() -> void:
	base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base_material.albedo_color = base_color
	
	for joint in meshes:
		joint.material_override = base_material
	
	handle_material.albedo_color = handle_color
	handle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	create_handles()

func create_handles() -> void:
	
	for joint in meshes:
		var handle := MeshInstance3D.new()
		handle.mesh = sphere
		
		handle.scale = Vector3.ONE * 0.0004 * handle_scale
		handle.material_override = handle_material
		
		joint.add_child(handle)
		handles.append(handle)

func _process(delta: float) -> void:
	pass
