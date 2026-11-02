extends Node

@export var screen_size := Vector2(0.72, 0.45)

@onready var subviewport: SubViewport = $SubViewport
@onready var ui: Control = $SubViewport/UI
@onready var frame: MeshInstance3D = $Frame

var material := StandardMaterial3D.new()

func _ready() -> void:
	material.albedo_color = Color(1, 1, 1, 1)
	material.albedo_texture = subviewport.get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	if frame.material_override == null:
		frame.material_override = material
	
	#ui.reset_pressed.connect(_on_reset)
	#ui.approve_pressed.connect(_on_approve)
	#ui.safe_thickness_changed.connect(_on_safe_thickness_changed)
	#ui.set_safe_thickness(_safe_thickness)
