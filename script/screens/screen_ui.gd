class_name ControlUI
extends Control

@export var background_color: Color = Color(0.11, 0.11, 0.11, 1)
@export var element_margin := 22

var ui_parent: Node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	
	var bg := ColorRect.new()
	bg.color = background_color
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, element_margin)
	add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	ui_parent = vbox
	

func init_ui() -> void:
	pass

func new_label(text: String, font_size: int = 30, font_color: Color = Color.WHITE, aligment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.horizontal_alignment = aligment
	return label
