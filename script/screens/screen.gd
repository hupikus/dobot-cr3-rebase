class_name UIScreen
extends Node3D

@export var screen_size := Vector2(0.72, 0.45)

@onready var subviewport: SubViewport = $"SubRotation/SubViewport"
@onready var ui: ControlUI = $"SubRotation/SubViewport/UI"
@onready var frame: MeshInstance3D = $"SubRotation/Frame"

var material := StandardMaterial3D.new()

func _ready() -> void:
	material.albedo_color = Color(1, 1, 1, 1)
	material.albedo_texture = subviewport.get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	frame.material_override = material
	
	init_ui()

func init_ui() -> void:
	pass
