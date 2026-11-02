extends Node3D

const OBSTACLE_LAYER := 2

@export var base_color: Color = Color(0.35, 0.65, 1.0, 0.35)
@export var base_color_error: Color = Color(1.0, 0.2, 0.2, 0.5)

@export var handle_color: Color = Color(1.0, 0.85, 0.2)

@export var handle_scale: float = 1

@onready var ghost: DobotCR3 = $".."
@onready var solid: DobotCR3 = $"../../ArmSolid"

@onready var meshes: Array[Node3D] = [
	$"CR3-BASE/CR3_J1/LINK2-CR3A",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4/CR3_J5",
	$"CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4/CR3_J5/CR3-J6_CR3_2__CR30001_1_2",
]
@onready var obstacle = $"../../Obstacles"
@onready var obstacles = obstacle.get_children()
var colliding := false

var handles: Array[Node3D]

var base_material := StandardMaterial3D.new()
var handle_material := StandardMaterial3D.new()

var sphere := SphereMesh.new()

var shapes: Array
var _query := PhysicsShapeQueryParameters3D.new()
func _ready() -> void:
	base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base_material.albedo_color = base_color
	
	shapes.resize(meshes.size())
	shapes.fill([])
	var i := 0
	for joint in meshes:
		joint.material_override = base_material
		shapes[i] = _extract_convex_shapes(joint)
		i += 1
	
	
	handle_material.albedo_color = handle_color
	handle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	create_handles()
	
	_query.collision_mask = OBSTACLE_LAYER
	_query.collide_with_bodies = true
	_query.margin = obstacle.safe_thickness

func create_handles() -> void:
	for joint in meshes:
		var handle := MeshInstance3D.new()
		handle.mesh = sphere
		
		handle.scale = Vector3.ONE * 0.0004 * handle_scale
		handle.material_override = handle_material
		
		joint.add_child(handle)
		handles.append(handle)

func _process(delta: float) -> void:
	update_collisions()
	update_transparency()

func _extract_convex_shapes(mi: MeshInstance3D) -> Array[Shape3D]:
	var out: Array[Shape3D] = []
	if mi.mesh == null:
		return out

	var before := mi.get_child_count()
	mi.create_multiple_convex_collisions()

	# Collect the newly created nodes first, so freeing doesn't invalidate indices.
	var added: Array[Node] = []
	for idx in range(before, mi.get_child_count()):
		added.append(mi.get_child(idx))

	for child in added:
		if child is StaticBody3D:
			for c in child.get_children():
				if c is CollisionShape3D and c.shape is ConvexPolygonShape3D:
					out.append(c.shape)
			child.queue_free()   # free the body, not the shape nodes

	return out

func update_collisions() -> void:
	var space := get_world_3d().direct_space_state
	var any := false

	for i in meshes.size():
		var gm := meshes[i]
		if not is_instance_valid(gm):
			continue
		var joint_shapes: Array = shapes[i]
		for shape in joint_shapes:
			if shape == null:
				continue
			_query.shape = shape
			_query.transform = (gm as Node3D).global_transform
			if space.intersect_shape(_query, 1).size() > 0:
				any = true
				break
		if any:
			break

	if any != colliding:
		colliding = any
		base_material.albedo_color = base_color_error if any else base_color
	#screen_ui.set_collision(any)

const ANGLE_INTERPOLATE_TRANSPARENCY = 0.4
func update_transparency() -> void:
	var solid_pos := solid.get_angles()
	var ghost_pos := ghost.get_angles()
	
	var i := 0
	var total_diff := 0.0
	for joint in meshes:
		var diff = wrapf(ghost_pos[i] - solid_pos[i], -PI, PI)
		diff = abs(diff)
		total_diff += diff
		i += 1
		
		if total_diff > ANGLE_INTERPOLATE_TRANSPARENCY:
			joint.transparency = 0.0
		else:
			joint.transparency = 1.0 - (total_diff / ANGLE_INTERPOLATE_TRANSPARENCY)
