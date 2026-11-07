class_name UIDashboard
extends UIScreen

@onready var obstacles = $"../../Obstacles"
@onready var box: Area3D = $SubRotation/Frame/Area3D

func refresh() -> void:
	ui.refresh()

func init_ui() -> void:
	#ui.update_thickness_display(obstacles.safe_thickness)
	ui.init_ui()
	
	box.mouse_entered.connect(_mouse_entered_area)
	box.mouse_exited.connect(_mouse_exited_area)
	box.input_event.connect(_on_input_event)

var is_mouse_inside := false
func _mouse_entered_area() -> void:
	is_mouse_inside = true
	# Notify the viewport that the mouse is now hovering it.
	subviewport.notification(NOTIFICATION_VP_MOUSE_ENTER)


func _mouse_exited_area() -> void:
	# Notify the viewport that the mouse is no longer hovering it.
	subviewport.notification(NOTIFICATION_VP_MOUSE_EXIT)
	is_mouse_inside = false

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		ui.ui_approve()
		return
	if Input.is_action_just_pressed("ui_reset"):
		ui.ui_reset()
		return

var last_event_pos2D := Vector2()
var last_event_time := -1.0
func _on_input_event(_camera: Camera3D, input_event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	# Get mesh size to detect edges and make conversions. This code only supports PlaneMesh and QuadMesh.
	var quad_mesh_size: Vector2 = frame.mesh.size

	# Event position in Area3D in world coordinate space.
	var event_pos3D := event_position

	# Current time in seconds since engine start.
	var now := Time.get_ticks_msec() / 1000.0

	# Convert position to a coordinate space relative to the Area3D node.
	# NOTE: `affine_inverse()` accounts for the Area3D node's scale, rotation, and position in the scene!
	event_pos3D = frame.global_transform.affine_inverse() * event_pos3D

	# TODO: Adapt to bilboard mode or avoid completely.

	var event_pos2D := Vector2()

	if is_mouse_inside:
		# Convert the relative event position from 3D to 2D.
		event_pos2D = Vector2(event_pos3D.x, -event_pos3D.y)

		# Right now the event position's range is the following: (-quad_size/2) -> (quad_size/2)
		# We need to convert it into the following range: -0.5 -> 0.5
		event_pos2D.x = event_pos2D.x / quad_mesh_size.x
		event_pos2D.y = event_pos2D.y / quad_mesh_size.y
		# Then we need to convert it into the following range: 0 -> 1
		event_pos2D.x += 0.5
		event_pos2D.y += 0.5

		# Finally, we convert the position to the following range: 0 -> viewport.size
		event_pos2D.x *= subviewport.size.x
		event_pos2D.y *= subviewport.size.y
		# We need to do these conversions so the event's position is in the viewport's coordinate system.

	elif last_event_pos2D != null:
		# Fall back to the last known event position.
		event_pos2D = last_event_pos2D

	# Set the event's position and global position.
	input_event.position = event_pos2D
	if input_event is InputEventMouse:
		input_event.global_position = event_pos2D

	# Calculate the relative event distance.
	if input_event is InputEventMouseMotion or input_event is InputEventScreenDrag:
		# If there is not a stored previous position, then we'll assume there is no relative motion.
		if last_event_pos2D == null:
			input_event.relative = Vector2(0, 0)
		# If there is a stored previous position, then we'll calculate the relative position by subtracting
		# the previous position from the new position. This will give us the distance the event traveled from prev_pos.
		else:
			input_event.relative = event_pos2D - last_event_pos2D
			input_event.velocity = input_event.relative / (now - last_event_time)

	# Update last_event_pos2D with the position we just calculated.
	last_event_pos2D = event_pos2D

	# Update last_event_time to current time.
	last_event_time = now

	# Finally, send the processed input event to the viewport.
	subviewport.push_input(input_event)
