class_name DobotCR3
extends Node

## Step angle per one iteration
@export var step_angle: float = 0.05
## Max iterations per one frame
@export var max_iterations: int = 20

## Whether to move in real-time
var target: Node3D = null
@export var active_solve: bool = true
@export var default_speed: float = 0.6

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

var report_rotation = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


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
	var distance_old := quadratic_distance_to_target()
	
	var i := 0
	for joint in range(0, 5):
		
		# Check distances when rotated right and when rotated left
		rotate_joint(i, step_angle)
		var distance_right := quadratic_distance_to_target()
		rotate_joint(i, -2 * step_angle)
		var distance_left := quadratic_distance_to_target()
		rotate_joint(i, step_angle)
		
		if distance_old <= distance_left && distance_old <= distance_right:
			continue
		
		rotate_joint(i, step_angle if distance_right < distance_left else -step_angle)
