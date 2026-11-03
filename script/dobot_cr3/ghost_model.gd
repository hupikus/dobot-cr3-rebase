extends Node3D

const OBSTACLE_LAYER := 2

@export var base_color: Color = Color(0.35, 0.65, 1.0, 0.35)
@export var base_color_error: Color = Color(1.0, 0.2, 0.2, 0.5)

@export var handle_color: Color = Color(1.0, 0.85, 0.2)

@export var handle_scale: float = 1

@onready var ghost: DobotCR3 = $".."
@onready var solid: DobotCR3 = $"../../ArmSolid"

@onready var joints: Array[Node3D] = [
	$"CR3-BASE/CR3_J1/LINK2-CR3A",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4/CR3_J5",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4/CR3_J5/CR3-J6_CR3_2__CR30001_1_2",
]
@onready var meshes: Array[MeshInstance3D] = [
	
]

@onready var obstacle = $"../../Obstacles"
@onready var obstacles = obstacle.get_children()
var colliding := false

var handles: Array[Node3D]

var base_material := StandardMaterial3D.new()
var handle_material := StandardMaterial3D.new()

var sphere := SphereMesh.new()

var geometry: Array = []

func _ready() -> void:
	base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base_material.albedo_color = base_color
	
	for joint in joints:
		joint.material_override = base_material
		geometry.append(CollisionGeometry.get_triangles(joint))
	
	handle_material.albedo_color = handle_color
	handle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	create_handles()
	
	var c := CollisionGeometry.new()
	c.generate_regions()


func create_handles() -> void:
	for joint in joints:
		var handle := MeshInstance3D.new()
		handle.mesh = sphere
		
		handle.scale = Vector3.ONE * 0.0004 * handle_scale
		handle.material_override = handle_material
		
		joint.add_child(handle)
		handles.append(handle)

func _physics_process(delta):
	if ghost.moved:
		ghost.moved = false
		return
		update_collisions()

func _process(delta: float) -> void:
	update_transparency()


func update_collisions() -> void:
	var space := get_world_3d().direct_space_state
	var any := false

	var joints_size = joints.size()
	for i in joints_size:
		if any:
			break
		var j := -1
		for check in geometry + obstacle.geometry:
			j += 1
			if j <= i:
				continue
			if i + 1 < joints_size and j == i + 1:
				continue
			if i < joints_size - 1 and j == joints_size - 1:
				continue
			
			
			if CollisionGeometry.meshes_intersect(geometry[i], check):
				any = true
				break

	if any != colliding:
		colliding = any
		base_material.albedo_color = base_color_error if colliding else base_color
	#screen_ui.set_collision(any)

const ANGLE_INTERPOLATE_TRANSPARENCY = 0.4
func update_transparency() -> void:
	var solid_pos := solid.get_angles()
	var ghost_pos := ghost.get_angles()
	
	var i := 0
	var total_diff := 0.0
	for joint in joints:
		var diff = wrapf(ghost_pos[i] - solid_pos[i], -PI, PI)
		diff = abs(diff)
		total_diff += diff
		i += 1
		
		if total_diff > ANGLE_INTERPOLATE_TRANSPARENCY:
			joint.transparency = 0.0
		else:
			joint.transparency = 1.0 - (total_diff / ANGLE_INTERPOLATE_TRANSPARENCY)
