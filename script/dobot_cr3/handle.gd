class_name DobotCR3
extends Node

## Step angle per one iteration
@export var step_angle: float = 0.05
## Max iterations per one frame
@export var max_iterations: int = 20

## Whether to move in real-time
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
