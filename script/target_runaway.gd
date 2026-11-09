extends Node3D

var startPos: Vector3
func _ready() -> void:
	global_position = $"../ArmGhost/CR3A_ASM/CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4/CR3_J5/CR3-J6_CR3_2__CR30001_1_2".global_position
	print(global_position)
	startPos = position
