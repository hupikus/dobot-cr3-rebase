extends Node

var enabled = false

@onready var ghost: DobotCR3 = $"../../ArmGhost"
@onready var solid: DobotCR3 = $"../../ArmSolid"

@onready var target: Node3D = $"../../Target"
@onready var screen: Node3D = $"../../Screens/Screen"
@onready var desktop_camera: Camera3D = $"../../DesktopCamera"

@export var screen_size := Vector2(0.72, 0.45)

@export var grab_distance: float = 0.16
@export var handle_grab_distance: float = 0.08

@export var zoom_step := 0.12
@export var zoom_min := 0.12
@export var zoom_max := 4.0
@export var focus_distance = 0.8

## Pan speed per pixel, multiplied by camera distance.
@export var pan_sensitivity: float = 0.0016

var gizmo_length = 0.22

@onready var xr = $"../XR"
@onready var ghost_model = $"../../ArmGhost/CR3A_ASM"
@onready var _handles = ghost_model.handles

var _desktop_dragging = false

var _desktop_plane = Plane()
var gizmo: Node3D = null

var _dragging_axis := -1
var _axis_drag_start := Vector3.ZERO
var _axis_drag_param0 := 0.0
var _right_dragging := false
var _middle_dragging := false

var _cam_pivot := Vector3(0.1, 0.95, -0.62)
var _cam_yaw := 0.0
var _cam_pitch := 0.32
var _cam_distance := 1.9

func _ready() -> void:
	if enabled || not xr.active: enable()

func enable() -> void:
	enabled = true
	desktop_camera.current = true
	create_gizmo()
	update_camera()

func _process(delta) -> void:
	if enabled:
		update_camera()
		update_desktop_input(delta)
		if gizmo:
			gizmo.global_position = target.global_position

func update_desktop_input(_delta: float) -> void:
	var mp = get_viewport().get_mouse_position()
	var from = desktop_camera.project_ray_origin(mp)
	var dir = desktop_camera.project_ray_normal(mp)

	if _dragging_axis >= 0:
		var axis = axis_vector(_dragging_axis)
		var s = closest_line_param(_axis_drag_start, axis, from, dir)
		if not is_nan(s):
			target.global_position = _axis_drag_start + axis * (s - _axis_drag_param0)
	elif _desktop_dragging:
		var hit: Variant = _desktop_plane.intersects_ray(from, dir)
		if hit != null:
			target.global_position = hit as Vector3

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	#if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_click_on_screen((event as InputEventMouseButton).position):
	#	return
	if event is InputEventMouseButton:
		handle_mouse_button(event as InputEventMouseButton)
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			check_screen_click()
	elif event is InputEventMouseMotion and _right_dragging:
		var motion = event as InputEventMouseMotion
		_cam_yaw -= motion.relative.x * 0.006
		_cam_pitch = clampf(_cam_pitch + motion.relative.y * 0.006, -0.2, 1.35)
		update_camera()
	elif event is InputEventMouseMotion and _middle_dragging:
		pan_camera((event as InputEventMouseMotion).relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_cam_pivot = target.global_position
		_cam_distance = focus_distance
		update_camera()

func is_click_on_screen(mouse_pos: Vector2) -> bool:
	var from = desktop_camera.project_ray_origin(mouse_pos)
	var dir = desktop_camera.project_ray_normal(mouse_pos)
	if dir.z > -0.3:
		return false
	var t = (-0.82 - from.z) / dir.z
	if t < 0.5 or t > 5.0:
		return false
	var hit = from + dir * t
	var half = screen_size * 0.5
	var center = screen.global_position
	var d = Vector2(hit.x - center.x, hit.y - center.y)
	return absf(d.x) <= half.x and absf(d.y) <= half.y

func pan_camera(vec: Vector2) -> void:
	var basis := desktop_camera.global_transform.basis
	var scale := _cam_distance * pan_sensitivity
	_cam_pivot += basis.x * (-vec.x * scale)
	_cam_pivot += basis.y * ( vec.y * scale)
	update_camera()

func check_screen_click() -> void:
	var mp = get_viewport().get_mouse_position()
	var from = desktop_camera.project_ray_origin(mp)
	var dir = desktop_camera.project_ray_normal(mp)
	# Screen is at global Z ≈ -0.82, DesktopCamera at Z ≈ 0.4,
	# so a ray going into the scene (negative Z) will reach it ~1.2m away.
	if dir.z > -0.3:  # ray must have a forward component
		return
	# Predict hit point at Screen's Z distance
	var screen_z = -0.82
	var t = (screen_z - from.z) / dir.z
	if t < 0.5 or t > 5.0:
		return
	var hit_pos = from + dir * t
	# Check if hit point is near the target (which is near the Screen in the scene)
	var screen_xy = Vector2(target.global_position.x, target.global_position.y)
	var hit_xy = Vector2(hit_pos.x, hit_pos.y)
	var dist = hit_xy.distance_to(screen_xy)
	#if dist < 0.2:  # within ~20 cm of target center = "on screen"
		# Shift = approve, otherwise reset
		#screen_ui.approve_pressed.emit()

func handle_mouse_button(event: InputEventMouseButton) -> void:
	var from = desktop_camera.project_ray_origin(event.position)
	var dir = desktop_camera.project_ray_normal(event.position)
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				var axis = pick_axis(from, dir)
				if axis >= 0:
					_dragging_axis = axis
					_axis_drag_start = target.global_position
					_axis_drag_param0 = closest_line_param(
						_axis_drag_start, axis_vector(axis), from, dir)
				elif ray_hits_target(from, dir):
					_desktop_dragging = true
					_desktop_plane = Plane(-desktop_camera.global_transform.basis.z, target.global_position)
			else:
				_dragging_axis = -1
				_desktop_dragging = false
		MOUSE_BUTTON_RIGHT:
			_right_dragging = event.pressed
		MOUSE_BUTTON_MIDDLE:
			_middle_dragging = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				#_cam_distance = clampf(_cam_distance - zoom_step, zoom_min, zoom_max)
				zoom(-zoom_step)
				update_camera()
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				#_cam_distance = clampf(_cam_distance + zoom_step, zoom_min, zoom_max)
				zoom(zoom_step)
				update_camera()

func zoom(delta: float) -> void:
	var mp := get_viewport().get_mouse_position()
	var from := desktop_camera.project_ray_origin(mp)
	var dir := desktop_camera.project_ray_normal(mp)

	# Plane through the pivot, facing the camera — "everything at pivot depth".
	var plane := Plane(-desktop_camera.global_transform.basis.z, _cam_pivot)
	var hit: Variant = plane.intersects_ray(from, dir)

	var d_old := _cam_distance
	var d_new := clampf(d_old + delta, 0.6, 5.0)

	if hit == null:
		_cam_distance = d_new
		update_camera()
		return

	# Scale pivot toward the cursor hit by the same ratio the camera moves.
	# This keeps `hit` fixed on screen.
	var ratio := d_new / d_old
	_cam_pivot = (hit as Vector3) + (_cam_pivot - (hit as Vector3)) * ratio
	_cam_distance = d_new
	update_camera()

func ray_hits_target(from: Vector3, dir: Vector3) -> bool:
	var to := target.global_position - from
	var t := to.dot(dir)
	if t < 0.0:
		return false
	var closest := from + dir * t
	return closest.distance_to(target.global_position) < grab_distance


func nearest_handle(hand: XRController3D) -> int:
	var best = -1
	var best_dist = handle_grab_distance
	for i in _handles.size():
		var d = hand.global_position.distance_to(_handles[i].global_position)
		if d < best_dist:
			best_dist = d
			best = i
	return best


func click_screen(uv: Vector2) -> void:
	var vp_size = Vector2(screen.size)
	var pos := Vector2(uv.x * vp_size.x, uv.y * vp_size.y)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pos
		event.global_position = pos
		if pressed:
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
		screen.push_input(event, true)

var colors := [Color(1, 0.3, 0.3), Color(0.35, 1, 0.45), Color(0.4, 0.6, 1)]
var rots := [Vector3(0, 0, -90), Vector3.ZERO, Vector3(90, 0, 0)]
func create_gizmo() -> void:
	gizmo = Node3D.new()
	gizmo.name = "TargetGizmo"
	add_child(gizmo)
	
	for i in 3:
		var axis_node := Node3D.new()
		axis_node.rotation_degrees = rots[i]
		gizmo.add_child(axis_node)
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		
		var shaft := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.006
		cyl.bottom_radius = 0.006
		cyl.height = gizmo_length
		shaft.mesh = cyl
		shaft.material_override = mat
		shaft.position = Vector3(0, gizmo_length * 0.5, 0)
		axis_node.add_child(shaft)
		
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.017
		cone.height = 0.05
		tip.mesh = cone
		tip.material_override = mat
		tip.position = Vector3(0, gizmo_length + 0.025, 0)
		axis_node.add_child(tip)


func update_camera() -> void:
	var cp := cos(_cam_pitch)
	var dir := Vector3(sin(_cam_yaw) * cp, sin(_cam_pitch), cos(_cam_yaw) * cp)
	desktop_camera.global_position = _cam_pivot + dir * _cam_distance
	if desktop_camera.global_position.distance_to(_cam_pivot) > 0.01:
		desktop_camera.look_at(_cam_pivot, Vector3.UP)


func axis_vector(index: int) -> Vector3:
	match index:
		0:
			return Vector3.RIGHT
		1:
			return Vector3.UP
		_:
			return Vector3.BACK

func closest_line_param(p: Vector3, a: Vector3, o: Vector3, d: Vector3) -> float:
	var b = a.dot(d)
	var e = d.dot(p - o)
	var dd = a.dot(p - o)
	var denom = 1.0 - b * b
	if absf(denom) < 1e-6:
		return NAN
	return (b * e - dd) / denom


func pick_axis(from: Vector3, dir: Vector3) -> int:
	var best = -1
	var best_dist = 0.055
	for i in 3:
		var axis = axis_vector(i)
		var s = closest_line_param(target.global_position, axis, from, dir)
		if is_nan(s) or s < -0.002 or s > gizmo_length + 0.06:
			continue
		var point = target.global_position + axis * s
		var t = (point - from).dot(dir)
		if t < 0.0:
			continue
		var closest = from + dir * t
		var dist = closest.distance_to(point)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best
