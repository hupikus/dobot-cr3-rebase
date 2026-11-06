extends ControlUI

func init_ui() -> void:
	
	var title := Label.new()
	title.text = "DOBOT CR3"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_parent.add_child(title)
