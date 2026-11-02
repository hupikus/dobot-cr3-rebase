extends Node

@onready var solid = $ArmSolid
@onready var ghost = $ArmGhost
@onready var target = $Target

func _ready() -> void:
	solid.target = target
	solid.active_solve = true
	ghost.active_solve = true


func _process(delta: float) -> void:
	pass
