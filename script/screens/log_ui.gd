extends ControlUI

const MAX_LOG_LINES = 7

var lines: Array[Label] = []
var lines_taken = 0

func init_ui() -> void:
	ui_parent.add_child(new_label("Log", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
	for i in MAX_LOG_LINES:
		var label := new_label("...", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		ui_parent.add_child(label)
		lines.append(label)

func push_message(msg: String) -> void:
	print("I BEGEG")
	for i in MAX_LOG_LINES:
		if lines_taken < MAX_LOG_LINES:
			lines[lines_taken].text = msg
			lines_taken += 1
			return
		else:
			if i + 1 < MAX_LOG_LINES:
				lines[i].text = lines[i + 1].text
			else:
				lines[i].text = msg
