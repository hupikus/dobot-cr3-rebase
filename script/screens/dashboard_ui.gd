extends ControlUI

@onready var solid: DobotCR3 = $"../../../../../ArmSolid"
@onready var ghost: DobotCR3 = $"../../../../../ArmGhost"
@onready var target = $"../../../../../Target"

var status_label: Label
var reset_button
var approve_button
func init_ui() -> void:
	ui_parent.add_child(new_label("DOBOT CR3", 30))
	
	status_label = new_label("Status:", 26)
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui_parent.add_child(status_label)
	
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	ui_parent.add_child(row)

	reset_button = new_button("RESET", 84, 32)
	reset_button.pressed.connect(ui_reset)
	row.add_child(reset_button)

	approve_button = new_button("APPROVE", 84, 32)
	approve_button.pressed.connect(ui_approve)
	row.add_child(approve_button)

func ui_reset() -> void:
	if reset_disabled: return
	print("UI_RESET")
	target.position = target.startPos
	solid.reset()
	ghost.reset()
	

func ui_approve() -> void:
	if approve_disabled: return
	print("UI_APPROVE")
	solid.sync()

var approve_disabled := false
var reset_disabled := false
func refresh() -> void:
	approve_disabled = false
	reset_disabled = false
	var text := "Ready"
	var color := Color(0.7, 1, 0.7)
	if solid.busy || not ghost.reached:
		text = "MOVING - please wait"
		color = Color(1, 0.82, 0.35)
		approve_disabled = true
		reset_disabled = true
	elif ghost.colliding:
		text = "COLLISION - cannot approve"
		color = Color(1, 0.35, 0.35)
		approve_disabled = true

	if approve_button:
		approve_button.disabled = approve_disabled
		approve_button.modulate = Color(1, 1, 1, 0.4) if approve_disabled else Color(1, 1, 1, 1)
	if reset_button:
		reset_button.disabled = reset_disabled
		reset_button.modulate = Color(1, 1, 1, 0.4) if reset_disabled else Color(1, 1, 1, 1)
	if status_label:
		status_label.text = text
		status_label.add_theme_color_override("font_color", color)
