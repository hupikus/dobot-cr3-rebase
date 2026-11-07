class_name DobotCR3
extends Node

const EPSILON = 0.0001

@export var target_distance: float = 0.0015
## Step angle per one iteration
@export var step_angle: float = 0.001
## Max iterations per one frame
@export var max_iterations: int = 40

## Whether to move in real-time
var target: Node3D = null
@export var active_solve: bool = true
@export var default_speed: float = 0.6

var busy := false
var colliding := false

@onready var client: DobotClient = $"../Client"
@onready var ghost: DobotCR3 = $"../ArmGhost"
@onready var solid: DobotCR3 = $"../ArmSolid"

@onready var screen: UIScreen = $"../Screens/Screen"

const JOINTS_LEN = 6
@onready var joints: Array[Node3D] = [
	$"CR3A_ASM/CR3-BASE/CR3_J1",
	$"CR3A_ASM/CR3-BASE/CR3_J1/LINK2-CR3A",
	$"CR3A_ASM/CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3",
	$"CR3A_ASM/CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4",
	$"CR3A_ASM/CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4/CR3_J5",
	$"CR3A_ASM/CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4/CR3_J5/CR3-J6_CR3_2__CR30001_1_2",
]
@onready var tip = joints[5]
enum {AXIS_X, AXIS_Y, AXIS_Z}
var axis_vector = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]

var joint_axes = [AXIS_Z, AXIS_X, AXIS_X, AXIS_X, AXIS_Z, AXIS_X]
var joint_weights = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

const JOINT_LIMITS: Array[Vector2] = [
	Vector2(-PI*2, PI*2),   # J1
	Vector2(-PI*2, PI*2),   # J2
	Vector2(-2.705, 2.705), # J3
	Vector2(-PI*2, PI*2),   # J4
	Vector2(-PI*2, PI*2),   # J5
	Vector2(-PI*2, PI*2),   # J6
]

var joint_angles := PackedFloat32Array()
var default_angles := PackedFloat32Array()
var reached := false
var moved := false

## The list of joints edited by hand; resets after approval
var pinned := PackedByteArray()

## Is manipulator transitioning from one position to another
var is_transitioning := false
var moving_from := PackedFloat32Array()
var moving_to := PackedFloat32Array()
var move_elapsed := 0.0
var move_duration := 0.0

func _ready() -> void:
	joint_angles.resize(JOINTS_LEN)
	joint_angles.fill(0.0)
	default_angles = joint_angles.duplicate()
	default_angles[0] = PI / 2
	pinned.resize(JOINTS_LEN)
	pinned.fill(0)

func rotate_joint(joint: int, turn_degree: float) -> void:
	if joint < 0: return
	if joint >= 6: return
	
	var vec = axis_vector[joint_axes[joint]]
	joints[joint].rotate_object_local(vec, turn_degree)

func _process(_delta) -> void:
	if active_solve:
		do_ik()

func quadratic_distance_to_target() -> float:
	var ret: float = 0.0
	ret += (tip.global_position.x - target.global_position.x)**2
	ret += (tip.global_position.y - target.global_position.y)**2
	ret += (tip.global_position.z - target.global_position.z)**2
	return ret

func do_ik() -> void:
	if target == null: return
	for i in max_iterations:
		for joint in range(5, -1, -1):
			var distance_old := quadratic_distance_to_target()
			if distance_old < target_distance:
				reached = true
				screen.refresh()
				return
			reached = false
			screen.refresh()
			
			# Check distances when rotated right and when rotated left
			rotate_joint(joint, step_angle)
			var distance_right := quadratic_distance_to_target()
			rotate_joint(joint, -2 * step_angle)
			var distance_left := quadratic_distance_to_target()
			rotate_joint(joint, step_angle)
			
			if distance_old <= distance_left && distance_old <= distance_right:
				continue
			
			moved = true
			rotate_joint(joint, step_angle if distance_right < distance_left else -step_angle)

func move_to_state(angles: PackedFloat32Array, speed: float = -1.0) -> void:
	var goal := PackedFloat32Array()
	goal.resize(joints.size())
	for i in joints.size():
		var a: float = angles[i] if i < angles.size() else joint_angles[i]
		goal[i] = clampf(a, JOINT_LIMITS[i].x, JOINT_LIMITS[i].y)

	var use_speed: float = speed if speed > 0.0 else default_speed
	moving_from = joint_angles.duplicate()
	moving_to = goal
	move_elapsed = 0.0
	var max_delta := 0.0
	for i in joints.size():
		max_delta = maxf(max_delta, absf(goal[i] - moving_from[i]))
	move_duration = max_delta / use_speed if use_speed > 0.0 else 0.0

	if move_duration <= EPSILON:
		apply_joint_angles(goal)
		#move_finished.emit()
		return
	is_transitioning = true

func get_angles() -> PackedFloat32Array:
	for i in JOINTS_LEN:
		joint_angles[i] = joints[i].rotation[joint_axes[i]]
	return joint_angles

func get_angles_degree() -> PackedFloat32Array:
	var angles = get_angles().duplicate()
	for i in angles.size():
		angles[i] = wrapf(rad_to_deg(angles[i]), -180.0, 180.0)
	return angles

func apply_joint_angles(angles: PackedFloat32Array) -> void:
	is_transitioning = false
	for i in joints.size():
		if i >= angles.size():
			break
		rotate_joint(i, angles[i] - joint_angles[i])
	reached = false


func sync() -> void:
	if ghost.colliding: return
	for joint in joints.size():
		joints[joint].rotation = ghost.joints[joint].rotation
	client.MovJ(get_angles_degree())

func reset() -> void:
	for joint in joints.size():
		joints[joint].rotation[joint_axes[joint]] = default_angles[joint]
	if self == solid:
		client.MovJ(get_angles_degree())
