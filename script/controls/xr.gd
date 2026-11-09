extends Node

var enabled = false

@onready var ghost: DobotCR3 = $"../../ArmGhost"
@onready var solid: DobotCR3 = $"../../ArmSolid"

@export var active := true
@export var grab_distance: float = 0.16
@export var handle_grab_distance: float = 0.08
## Meters/second per full joystick deflection.
@export var push_speed: float = 0.5

@onready var desktop_controls: Node3D = $"../MouseControls"

@onready var screen: Node3D = $"../../Screens/Screen"

@onready var target: Node3D = $"../../Target"
@onready var xr_origin: XROrigin3D = $"../../XROrigin3D"
@onready var hands: Array[XRController3D] = [
	$"../../XROrigin3D/LeftHand",
	$"../../XROrigin3D/RightHand",
]

# XR action names (default Windows OpenXR action map).
const ACTION_GRIP = "grip"
const ACTION_TRIGGER = "trigger"
const ACTION_SELECT = "select"
const ACTION_STICK = "primary"

var default_target: Vector3 = Vector3.ZERO

var grabbing_hand: XRController3D = null
var grab_offset: Vector3 = Vector3.ZERO
var editing_hand: XRController3D = null

# Which joint is being grabbed right now (VR only)
var edited_joint: int = -1

var edit_prev_dir: Vector3 = Vector3.ZERO
var trigger_prev: Array[bool] = [false, false]


var handles: Array[MeshInstance3D] = []

func _ready() -> void:
	if not active: return
	activate()

func activate() -> void:
	var xr := XRServer.find_interface("OpenXR")
	var xr_active: bool = xr != null and xr.is_initialized()
	if xr_active:
		get_viewport().use_xr = true
		enabled = true
	else:
		print("Failed to get XR started, using mouse controls.")
		desktop_controls.enable()
		return
	
	create_lasers()

## Create VR controller pointers
func create_lasers() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.4, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for hand in hands:
		var laser := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.004
		cyl.bottom_radius = 0.004
		cyl.height = 1.0
		laser.mesh = cyl
		laser.rotation_degrees = Vector3(-90, 0, 0)
		laser.position = Vector3(0, 0, -0.5)
		laser.material_override = mat
		hand.add_child(laser)

func _process(delta: float) -> void:
	if enabled:
		update_vr_input(delta)

## Process VR controllers input
func update_vr_input(delta: float) -> void:
	for i in hands.size():
		var hand: XRController3D = hands[i]
		var gripping: bool = hand.is_button_pressed(ACTION_GRIP)
		var stick: Vector2 = hand.get_vector2(ACTION_STICK)

		# Grabbing the target
		if gripping and grabbing_hand == null and editing_hand == null:
			if hand.global_position.distance_to(target.global_position) < grab_distance:
				grabbing_hand = hand
				grab_offset = target.global_position - hand.global_position
		if not gripping and grabbing_hand == hand:
			grabbing_hand = null

		# Editing a joint by its handle
		if gripping and editing_hand == null and grabbing_hand == null:
			var joint_index: int = nearest_handle(hand)
			if joint_index >= 0:
				editing_hand = hand
				edited_joint = joint_index
				ghost.set_joint_pinned(joint_index, true)
				edit_prev_dir = handle_dir(hand, joint_index)
		if not gripping and editing_hand == hand:
			ghost.set_joint_pinned(edited_joint, false)
			editing_hand = null
			edited_joint = -1

		# Hold the target: follow the hand, joystick pushes/pulls.
		if grabbing_hand == hand:
			var push_dir: Vector3 = -hand.global_transform.basis.z
			grab_offset += push_dir * stick.y * push_speed * delta
			target.global_position = hand.global_position + grab_offset

		# Reshape a joint by hand.
		if editing_hand == hand:
			var cur = handle_dir(hand, edited_joint)
			if cur.length() > 1e-4 and edit_prev_dir.length() > 1e-4:
				var axis: Vector3 = ghost.joint_global_axis(edited_joint)
				var angle: float = atan2(edit_prev_dir.cross(cur).dot(axis), edit_prev_dir.dot(cur))
				ghost.rotate_joint_by(edited_joint, clampf(angle, -0.4, 0.4))
			edit_prev_dir = cur

		# Click the screen with the trigger / select button.
		var pressed: bool = hand.is_button_pressed(ACTION_TRIGGER) or hand.is_button_pressed(ACTION_SELECT)
		if pressed and not trigger_prev[i]:
			var uv = screen_uv(hand)
			if uv.x >= 0.0:
				click_screen(uv)
		trigger_prev[i] = pressed

## Get nearest handle to the controller
func nearest_handle(hand: XRController3D) -> int:
	var best := -1
	var best_dist := handle_grab_distance
	for i in handles.size():
		var d := hand.global_position.distance_to(handles[i].global_position)
		if d < best_dist:
			best_dist = d
			best = i
	return best


func handle_dir(hand: XRController3D, joint_index: int) -> Vector3:
	var origin: Vector3 = ghost.joint_global_origin(joint_index)
	var axis: Vector3 = ghost.joint_global_axis(joint_index)
	var v: Vector3 = hand.global_position - origin
	return v - axis * v.dot(axis)

func screen_uv(hand: XRController3D) -> Vector2:
	var screen_basis = screen.global_transform.basis
	var local_from = screen.to_local(hand.global_position)
	var local_dir = screen_basis.inverse() * (-hand.global_transform.basis.z)
	if absf(local_dir.z) < 1e-5:
		return Vector2(-1, -1)
	var t = -local_from.z / local_dir.z
	if t < 0.0:
		return Vector2(-1, -1)
	var hit = local_from + local_dir * t
	var u = hit.x / screen.size.x + 0.5
	var v = 0.5 - hit.y / screen.size.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2(-1, -1)
	return Vector2(u, v)


func click_screen(uv: Vector2) -> void:
	var vp_size := Vector2(screen.size)
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
