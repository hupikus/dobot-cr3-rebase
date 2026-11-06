class_name UIDashboard
extends UIScreen

@onready var obstacles = $"../../Obstacles"

func init_ui() -> void:
	#ui.update_thickness_display(obstacles.safe_thickness)
	ui.init_ui()
