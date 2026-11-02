extends Node

@onready var solid = $ArmSolid
@onready var ghost = $ArmGhost
@onready var target = $Target

func _ready() -> void:
	solid.active_solve = false
	ghost.active_solve = true
	ghost.target = target


func _process(delta: float) -> void:
	pass
