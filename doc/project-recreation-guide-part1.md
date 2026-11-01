# Dobot CR3 VR Control Station - Project Documentation
# Part 1: Overview and File Structure
# Generated: 2026-11-01

#==============================================================================
# 01 - PROJECT OVERVIEW
#==============================================================================

## Project Name: Dobot CR3 VR Control Station
## Godot Version: 4.7.2 (forward+ renderer)
## Target Platform: Windows with OpenXR headset
## Testing Platform: Headless Linux x64 (OpenXR temporarily disabled)
## Primary Developer: Ziva AI agent

## Goal
Build a virtual control station for a Dobot CR3 6-DOF robotic arm in VR, featuring:
- Live CCD inverse-kinematics reaching for a target
- Target grab/push-pull via controller joystick
- Redundant joint editing by hand
- Ghost/solid arm distinction (ghost tracks target, solid only changes on Approve)
- Meter-gridded table top with cm/dm/m markings (1.4 x 0.9 m real-world scale)
- Cyan glowing ranging rings around the target
- Dark-gray table surface
- Near-solid skybox with gradient and grain
- Subtle floor effect with world grid
- Black control panel with RESET/Approve buttons
- Desktop mouse/keyboard fallback when no headset/OpenXR

## Constraints & Preferences
- OpenXR enabled for Windows/headset deployment
- On headless Linux: enabling xr/openxr/enabled pops a blocking zenity dialog that stalls all Godot subprocesses — temporarily disabled during testing
- The arm's physical axes are derived from the FBX geometry (not local Z) because the imported model is world-axis-aligned (un-rigged)
- Joint limits from cr3.urdf enforced in the solver
- The effector is the origin of the CR3-J6 node
- The control panel UI must be readable in desktop fallback mode
- Grid and rings must respect real-world metre scale (1.4 x 0.9 m table)
- No real headset available — VR hand interactions (grip, trigger, select) cannot be playtested; only desktop mouse/keyboard fallback works

## Progress Status
- [x] Refactored dobot_cr3.gd: CCD IK solver with per-joint axis derivation, apply_joint_angles, reset_pose, set_joint_pinned, rotate_joint_by, target_reached signal
- [x] Built manipulator_station.gd: full station orchestration — grab/push-poll, joint handles, collision check, RESET/Approve, target rings, visual theme
- [x] Created screen_ui.gd: black control panel with RESET/Approve signals, collision-state feedback, device connection status, safe-area thickness control
- [x] Added shaders: meter_grid.gdshader (white cm/dm/m grid), floor_effect.gdshader (radial gradient + world grid + grain), solid_sky.gdshader (near-solid gradient + grain), scanned_mesh.gdshader (obstacle meshes), safe_area.gdshader (translucent shell)
- [x] Scene main.tscn rebuilt with: XR rig, table, obstacles, Target, ArmGhost/ArmSolid, Screen with SubViewport/UI, DesktopCamera fallback, meter grid plane, cyan ranging rings
- [x] Verified logic via self-test run: target reach, collision → red ghost + disabled Approve, Approve copies ghost angles to solid, Reset restores defaults
- [x] Screen UI: focus_mode=FOCUS_ALL added, _check_screen_click() for desktop clickability
- [x] Timed motion: _advance_move(delta) called each _process() frame for smooth solid-follow
- [x] Button gating: APPROVE/RESET disabled while solid.is_moving(), re-enabled on completion
- [x] Safe-area thickness: UI +/- controls update both shell shader and collision volume (0–60 mm range)
- [x] Project documentation started in parts to avoid token limits
- [ ] On target Windows machine with XR headset: re-enable xr/openxr/enabled and xr/shaders/enabled; verify XR rig initializes
- [ ] Test grip/grab joystick push-pull flow with real headset; adjust grab_distance, push_speed if needed
- [ ] Tune meter grid line alphas (cm_alpha, dm_alpha, m_alpha) in meter_grid.gdshader
- [ ] Tune ring emission/size in _create_grid() if visual weight needs adjustment
- [ ] Confirm target_reached signal and get_joint_angles() output format match downstream system
- [ ] Remove protected res://shaders/grid_shader.glsl.import orphan file after next Godot launch clears it

## Key Decisions (Recorded in Memory Files)
- [Decision] Derive each joint's rotation axis from rest-pose geometry rather than assuming local Z; the FBX CR3_J1–CR3_J6 nodes are world-axis-aligned, so local Z would only allow yaw and prevent 3D reaching
- [Decision] Separate ArmGhost (live IK, half-transparent) from ArmSolid (frozen until Approve); this lets the operator evaluate poses before committing
- [Decision] Meter grid and cyan rings are separate visual layers (grid shader + emissive torus meshes) so they render correctly with environment glow and do not interfere with physics or collision checks
- [Decision] RESET sets both arm and target to default poses; APPROVE copies the ghost's joint angles into the solid model and marks the pose for future TCP/IP sync (no real-time polling)
- [Decision] Obstacle collision uses AABB overlap of ghost meshes vs the obstacles group; on overlap the ghost turns red, APPROVE is disabled, and a status label updates
- [Decision] On headless Linux, xr/openxr/enabled and xr/shaders/enabled must remain false during any Godot subprocess run, or a blocking zenity dialog will stall all editing

#==============================================================================
# 02 - FILE STRUCTURE AND ORGANIZATION
#==============================================================================

## res:// Directory Layout (Top-Level)

res/
├── scripts/                                          # GDScript files
│   ├── dobot_cr3.gd                                  # CCD IK solver node (DobotCR3 class)
│   ├── manipulator_station.gd                        # Main orchestration node (ManipulatorStation class)
│   ├── screen_ui.gd                                  # Black control panel UI (ScreenUI class)
│   ├── dobot_client.gd                               # Minimal TCP/IP client for Dobot CR-series
│   └── project-recreation-guide-part*.md             # Documentation parts (this file series)
├── shaders/                                          # GDShader files (Godot 4.3+ .gdshader format)
│   ├── meter_grid.gdshader                           # White metre/cdm/cm grid
│   ├── floor_effect.gdshader                         # Dark radial gradient floor + world grid + grain
│   ├── solid_sky.gdshader                            # Near-solid gradient skybox
│   ├── scanned_mesh.gdshader                         # For obstacle meshes from 3D scanner software
│   └── safe_area.gdshader                            # Translucent shell that inflates obstacles outward by thickness
├── models/                                           # 3D model files
│   └── dobot_cr3.fbx                                 # FBX model (6-DOF robotic arm, world-axis-aligned, un-rigged)
└── main.tscn                                         # Scene file — complete composition

## Scripts Detail

### dobot_cr3.gd (DobotCR3 class)
- Joint chain: 6 nodes from base to tip (CR3_J1 through CR3-J6_CR3_2__CR30001_1_2)
- _compute_axes(): read joint axes from rest-pose geometry, store in _axes_local[]
- solve(): CCD solver, sweep tip→base each frame
- move_to_angles(): timed joint interpolation
- apply_joint_angles(): instant pose set
- reset_pose(): restore default rest pose
- rotate_joint_by(): hand editing about physical axis
- get_joint_angles(): return PackedFloat32Array [J1..J6]
- Joint limits: from cr3.urdf (rad)
- Signals: target_reached(joint_angles), move_finished
- Timed motion: _move_active, _move_from, _move_to, _move_elapsed, _move_duration
- default_speed: export var = 0.6 (rad/s)

### manipulator_station.gd (ManipulatorStation class)
- IK, collision, grid, rings, UI state management
- ghost (DobotCR3, solve_enabled=true) vs solid (timed motion model)
- _create_grid(): configure_tileset_atlas() + edit_tilemap() for 1.4x0.9m grid
- _update_target_rings(): cyan emissive torus meshes around target
- _check_collision(): AABB overlap + safe-area inflation oa.grow(_safe_thickness)
- Screen UI signal connections: reset_pressed, approve_pressed, safe_thickness_changed
- _setup_client(): DobotClient TCP/IP connection
- _command_real_arm(): send pose to DobotClient
- _dobot_pose_from_arm(): Godot→Dobot frame conversion (mm, Z-up → base frame)
- _process(delta): main loop, _advance_move(delta) for solid motion
- _on_reset(): reset both arms + target to defaults
- _on_approve(): copy ghost→solid, start timed motion, disable buttons while moving
- _update_motion_state(): keep panel in sync with solid.is_moving()
- Desktop fallback: orbit camera + target gizmo + screen click handling

### screen_ui.gd (ScreenUI class)
- Signals: reset_pressed, approve_pressed, safe_thickness_changed(delta)
- Layout: MarginContainer → VBoxContainer with title, connection status, safe-area controls, button row
- focus_mode = Control.FOCUS_ALL for desktop clickability
- _refresh(): update button states based on _busy, _colliding, _connected
- _check_screen_click(): raycast from DesktopCamera, Shift=approve otherwise reset
- Thickness row: +/- buttons (5 mm steps), label shows mm value

### dobot_client.gd (DobotClient class)
- Ports: dashboard 29999, motion 30003
- EnableRobot(), SpeedFactor(50) on connect
- Auto-reconnect every 5 s
- Signals: connection_changed(connected), message_received(line)
- is_device_connected(): avoids Godot Object.is_connected() clash
- Default host: 192.168.5.1

#==============================================================================
# 03 - CORE ARCHITECTURAL PRINCIPLES
#==============================================================================

## 3.1 Joint Axis Derivation (dobot-rig-axes principle)
- The imported FBX CR3_J1–CR3_J6 nodes are world-axis-aligned (their local Z is NOT the joint axis)
- Each joint's rotation axis is derived from rest-pose geometry, not local coordinates
- This enables full 3D reaching; assuming local Z would only allow yaw
- Axes stored in _axes_local[] array, expressed in each joint node's local frame
- Verified: axes remain valid for every pose, not just the rest pose

## 3.2 ArmGhost vs ArmSolid Separation
- ArmGhost: live CCD IK, half-transparent, tracks the target in real-time
- ArmSolid: frozen until Approve; only changes on Approve copy
- This lets the operator evaluate poses before committing
- Solid model uses move_to_angles() for timed motion at default_speed (0.6 rad/s)
- Buttons blocked while solid.is_moving() is true

## 3.3 CCD Inverse Kinematics Algorithm
- Each joint nudged by a small rotation about its physical axis
- After each candidate rotation, global effector-to-target distance measured
- Keep rotation only when it shortens distance; otherwise undo and try opposite
- Sweep joints from tip back to base; repeat until target reached within tolerance (0.005 m) or max_iterations (400) exhausted
- _rotate_joint_toward(index, target_pos): compute signed angle about joint axis, clamp to step_angle (0.05 rad)
- _try_rotation(index, angle): apply candidate, keep if distance shortens, else revert and try opposite direction
- _clamped_delta(index, delta): limit rotation so joint stays within JOINT_LIMITS [rad]

## 3.4 Ghost/Solid Collision Logic
- Obstacle collision uses AABB overlap of ghost meshes vs the "obstacles" group
- On overlap: ghost turns red, APPROVE disabled, status label updates to "COLLISION - cannot approve"
- Safe-area thickness inflates obstacle AABB (oa.grow(_safe_thickness)) to account for scanned mesh noise
- _safe_thickness controlled via UI +/- buttons (5 mm steps, 0–60 mm range)
- Verified: 20 mm → 26 mm change updates both shell shader and collision volume

## 3.5 Meter Grid and Rings Visual Separation
- Grid: separate visual layer via meter_grid.gdshader with uniforms cm_alpha, dm_alpha, m_alpha
- Cyan rings: emissive torus meshes around target, render separately from grid
- This separation ensures they render correctly with environment glow and do not interfere with physics
- Grid and rings respect real-world metre scale: 1.4 × 0.9 m table
- Grid placed on TileMapLayer via configure_tileset_atlas() + edit_tilemap()

## 3.6 TCP/IP Dobot Client Design
- Connects to controller at configurable host/ports (default: 192.168.5.1, dashboard 29999, motion 30003)
- EnableRobot() + SpeedFactor(50) on connect, auto-reconnect every 5 s
- Feedback lines drained; message_received signal for future use
- is_device_connected() avoids clash with Godot Object.is_connected()
- On headless Linux, xr/openxr/enabled and xr/shaders/enabled must remain false during Godot subprocess runs

## 3.7 Control Panel (ScreenUI) Design
- Black panel with RESET/Approve buttons, device connection status, safe-area thickness control
- Signals: reset_pressed, approve_pressed, safe_thickness_changed(delta)
- Layout: MarginContainer → VBoxContainer with title, connection status, safe-area controls, button row
- focus_mode = Control.FOCUS_ALL enables desktop click reception
- _refresh(): update button states/text based on _busy, _colliding, _connected
- Desktop fallback: _check_screen_click() raycast from DesktopCamera
- Shift held + click = approve; no shift = reset

## 3.8 Timed Motion System
- move_to_angles(angles, speed) moves solid model at constant joint speed
- default_speed = 0.6 rad/s export variable
- _move_active checks if motion in progress
- move_finished signal emitted when complete
- Buttons disabled during motion (~1.25 s for full pose, then re-enabled)
- _advance_move(delta) called each _process() frame for smooth interpolation

## 3.9 Desktop Fallback (No XR/Headset)
- When XR not active: orbit camera (right-drag + wheel zoom) + target gizmo (left-drag axes)
- Target gizmo: red/green/blue arrows at target; left-drag an axis slides target along that axis
- Screen clickable via approximate raycast from DesktopCamera
- OpenXR disabled on headless Linux (blocking Zenity); re-enable on target Windows machine
- Screen click: Shift+click = approve, otherwise reset

## 3.10 Safe-Area Visualization
- scanned_mesh.gdshader: matte look with fresnel rim + animated scan band
- safe_area.gdshader: translucent cyan shell inflating each obstacle by _safe_thickness
- UI control: +/- buttons update both shell and collision volume
- 0–60 mm range; verified 20→26 mm change
- Used alongside scanned meshes for collision-aware rendering

#==============================================================================
# 04 - dobot_cr3.gd DETAILED REFERENCE
#==============================================================================

## Class: DobotCR3 (extends Node3D)
## Class Name: dobot_cr3

### Exported Variables
- tolerance: float = 0.005 (metres — reached when distance <= this)
- step_angle: float = 0.05 (radians — largest rotation per pass)
- max_iterations: int = 400 (maximum solver passes per solve())
- solve_enabled: bool = true (solve every frame while scene runs)
- verbose: bool = false (print joint angles when target reached)
- default_speed: float = 0.6 (joint speed rad/s used by timed moves)

### Joint Chain (@onready)
@onready var joints: Array[Node3D] = [
    $"CR3A_ASM/CR3-BASE/CR3_J1",
    $"CR3A_ASM/CR3-BASE/CR3_J1/LINK2-CR3A",
    $"CR3A_ASM/CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3",
    $"CR3A_ASM/CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4",
    $"CR3A_ASM/CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4/CR3_J5",
    $"CR3A_ASM/CR3-BASE/CR3_J1/LINK2-CR3A/CR3_J3/CR3_J4/CR3_J5/CR3-J6_CR3_2__CR30001_1_2",
]
- J1 through J6: 6 revolute joints forming the kinematic chain
- joints[5] = CR3-J6_CR3_2__CR30001_1_2: the effector/origin node
- Joint indices: 0=J1, 1=J2, 2=J3, 3=J4, 4=J5, 5=J6

### Constant: JOINT_LIMITS
const JOINT_LIMITS: Array[Vector2] = [
    Vector2(-6.28, 6.28),   # J1
    Vector2(-6.28, 6.28),   # J2
    Vector2(-2.705, 2.705), # J3
    Vector2(-6.28, 6.28),   # J4
    Vector2(-6.28, 6.28),   # J5
    Vector2(-6.28, 6.28),   # J6
]
- Taken from cr3.urdf
- Values in radians: ±π for most, ±2.705 for J3 (elbow joint limit)

### Accumulated State
- var joint_angles := PackedFloat32Array() — accumulated angle of each joint about its own axis
- var default_angles := PackedFloat32Array() — pose restored by reset_pose()
- var pinned := PackedByteArray() — 1 = joint is hand-edited, skipped by solver
- var _reached := boolean — target reached flag
- var _axes_local: Array[Vector3] — each joint's physical rotation axis, local frame
- Timed motion: _move_active, _move_from, _move_to, _move_elapsed, _move_duration

### Core Functions

#### _compute_axes() -> void
- Works out each real joint's rotation axis and stores it in _axes_local[]
- The imported FBX parts are world-axis-aligned (their local Z is not the joint axis)
- Axes read off the geometry: J1 yaws about vertical; J2, J3, J5 are pitch joints; J4 rolls about forearm; J6 rolls about tool
- For each joint i: frame_basis = joints[i].global_transform.basis.orthonormalized(); _axes_local[i] = (frame_basis.inverse() * world_axes[i]).normalized()
- world_axes = [UP, BACK, BACK, (p4-p3).normalized(), BACK, (p6-p5).normalized()]
- p3..p6 = global positions of joints[2..5]

#### _process(delta: float) -> void
- If _move_active: _advance_move(delta) — advance timed joint interpolation
- If solve_enabled: solve() — run CCD IK solver

#### solve() -> void
- If target == null: return
- target_pos = target.global_position
- passes = 0
- While passes < max_iterations:
  - If end_effector.global_position.distance_to(target_pos) <= tolerance:
    - If not _reached: _reached = true; emit target_reached(joint_angles.duplicate())
    - Return
  - _reached = false
  - For i from joints.size()-1 down to 0: (CCD: sweep from tip to base)
    - If pinned[i] == 0: _rotate_joint_toward(i, target_pos)
  - passes += 1
- _reached = false

#### _rotate_joint_toward(index: int, target_pos: Vector3) -> void
- joint = joints[index]
- origin = joint.global_position
- axis = joint_global_axis(index) — global direction of joint's rotation axis
- to_effector = end_effector.global_position - origin
- to_target = target_pos - origin
- e_perp = to_effector - axis * to_effector.dot(axis) — perpendicular component
- t_perp = to_target - axis * to_target.dot(axis)
- If e_perp.length_squared() < 1e-8 or t_perp.length_squared() < 1e-8: return
- angle = atan2(e_perp.cross(t_perp).dot(axis), e_perp.dot(t_perp)) — signed angle aligning effector→target
- angle = clampf(angle, -step_angle, step_angle)
- _try_rotation(index, angle)

#### _try_rotation(index: int, angle: float) -> void
- joint = joints[index]
- local_axis = _axes_local[index]
- target_pos = target.global_position
- before = end_effector.global_position.distance_to(target_pos)
- applied = _clamped_delta(index, angle)
- If is_zero_approx(applied): return
- joint.rotate_object_local(local_axis, applied)
- If end_effector.global_position.distance_to(target_pos) < before:
  - joint_angles[index] += applied
  - Return
- Worse: undo and attempt opposite turn
- joint.rotate_object_local(local_axis, -applied)
- opposite = _clamped_delta(index, -angle)
- If is_zero_approx(opposite): return
- joint.rotate_object_local(local_axis, opposite)
- If end_effector.global_position.distance_to(target_pos) < before:
  - joint_angles[index] += opposite
- Else:
  - joint.rotate_object_local(local_axis, -opposite)

#### _clamped_delta(index: int, delta: float) -> float
- limits = JOINT_LIMITS[index]
- candidate = clampf(joint_angles[index] + delta, limits.x, limits.y)
- return candidate - joint_angles[index]

#### get_joint_angles() -> PackedFloat32Array
- Return joint_angles.duplicate()

### Timed Motion Functions

#### move_to_angles(angles: PackedFloat32Array, speed: float = -1.0) -> void
- goal.resize(joints.size())
- For i in range(joints.size()):
  - a = angles[i] if i < angles.size() else joint_angles[i]
  - goal[i] = clampf(a, JOINT_LIMITS[i].x, JOINT_LIMITS[i].y)
- use_speed = speed if speed > 0.0 else default_speed
- _move_from = joint_angles.duplicate()
- _move_to = goal
- _move_elapsed = 0.0
- max_delta = 0.0
- For i in range(joints.size()):
  - max_delta = maxf(max_delta, absf(goal[i] - _move_from[i]))
- _move_duration = max_delta / use_speed if use_speed > 0.0 else 0.0
- If _move_duration <= 0.0001:
  - apply_joint_angles(goal)
  - move_finished.emit()
  - Return
- _move_active = true

#### is_moving() -> bool
- Return _move_active

#### _advance_move(delta: float) -> void
- _move_elapsed += delta
- t = clampf(_move_elapsed / _move_duration, 0.0, 1.0)
- For i in range(joints.size()):
  - desired = lerpf(_move_from[i], _move_to[i], t)
  - rotate_joint_by(i, desired - joint_angles[i])
- If t >= 1.0:
  - apply_joint_angles(_move_to)
  - _move_active = false
  - move_finished.emit()

### External Control Functions

#### set_target(node: Node3D) -> void
- target = node

#### apply_joint_angles(angles: PackedFloat32Array) -> void
- _move_active = false
- For i in range(joints.size()):
  - If i >= angles.size(): break
  - rotate_joint_by(i, angles[i] - joint_angles[i])
- _reached = false

#### reset_pose() -> void
- apply_joint_angles(default_angles)

#### set_joint_pinned(index: int, is_pinned: bool) -> void
- If index >= 0 and index < pinned.size():
  - pinned[index] = 1 if is_pinned else 0

#### rotate_joint_by(index: int, delta: float) -> void
- applied = _clamped_delta(index, delta)
- If is_zero_approx(applied): return
- joints[index].rotate_object_local(_axes_local[index], applied)
- joint_angles[index] += applied

### Axis and Position Queries

#### joint_global_axis(index: int) -> Vector3
- Return (joints[index].global_transform.basis.orthonormalized() * _axes_local[index]).normalized()

#### joint_global_origin(index: int) -> Vector3
- Return joints[index].global_position

#### get_effector_transform() -> Transform3D
- Return end_effector.global_transform

#==============================================================================
# 05 - manipulator_station.gd DETAILED REFERENCE
#==============================================================================

## Class: ManipulatorStation (extends Node3D)
## Class Name: manipulator_station

### Exported Variables (New)
@export var screen_size := Vector2(0.72, 0.45)
@export_group("Dobot TCP/IP")
@export var dobot_host: String = "192.168.5.1"
@export var dobot_dashboard_port: int = 29999
@export var dobot_motion_port: int = 30003
@export var dobot_auto_connect: bool = true

### Key Node References
- ghost: ArmGhost (DobotCR3, solve_enabled=true, half-transparent)
- solid: ArmSolid (DobotCR3 instance, solve_enabled=false, timed motion model)
- target: Node3D (cyan sphere, target for IK)
- screen_ui: ScreenUI instance (black control panel)
- _gizmo: Node3D (target move gizmo, desktop fallback)
- _client: DobotClient (TCP/IP connection)
- _safe_thickness: float (metres, 0.02 default = 20 mm)
- _safe_shells: Array[ShaderMaterial] (safe-area shells for obstacles)

### Core Functions

#### _ready() -> void
- Initialize UI, connect signals, set up obstacles, client, visual theme, handles
- ghost.set_target(target); solid.solve_enabled = false
- _apply_visual_theme(); _create_handles()
- If xr_active: _create_lasers()

#### _process(delta: float) -> void
- If get_viewport().use_xr: _update_vr_input(delta)
- Else:
  - _update_orbit_camera()
  - _update_desktop_input(delta)
  - If _gizmo: _gizmo.global_position = target.global_position
- _update_handles()
- _update_target_rings()
- _check_collision()
- _update_motion_state()
- If solid.is_moving(): solid._advance_move(delta) — advance solid model timed motion

#### _update_orbit_camera() -> void
- Camera orbit: _cam_pivot (Vector3), _cam_yaw, _cam_pitch, _cam_distance
- dir = Vector3(sin(_cam_yaw) * cos(_cam_pitch), sin(_cam_pitch), cos(_cam_yaw) * cos(_cam_pitch))
- desktop_camera.global_position = _cam_pivot + dir * _cam_distance
- desktop_camera.look_at(_cam_pivot, Vector3.UP)

#### _update_desktop_input(delta: float) -> void
- Handle mouse input for target movement and camera orbit
- _desktop_dragging: move target on camera-facing plane
- _dragging_axis: -1=none, 0=X, 1=Y, 2=Z; drag along axis
- _axis_drag_start, _axis_drag_param0: axis drag state
- _right_dragging: orbit camera with right mouse button
- Wheel zoom: adjust _cam_distance, clamp [0.6, 5.0]
- _check_screen_click(): if mouse click on screen area, emit reset_pressed or approve_pressed

#### _check_screen_click() -> void
- mp = get_viewport().get_mouse_position()
- from = desktop_camera.project_ray_origin(mp)
- dir = desktop_camera.project_ray_normal(mp)
- If dir.z > -0.3: return (ray must have forward component)
- screen_z = -0.82 (Screen global Z)
- t = (screen_z - from.z) / dir.z
- If t < 0.5 or t > 5.0: return
- hit_pos = from + dir * t
- screen_xy = Vector2(target.global_position.x, target.global_position.y)
- hit_xy = Vector2(hit_pos.x, hit_pos.y)
- dist = hit_xy.distance_to(screen_xy)
- If dist < 0.2: (within ~20 cm of target center = "on screen")
  - If Input.is_key_pressed(KEY_SHIFT): screen_ui.approve_pressed.emit()
  - Else: screen_ui.reset_pressed.emit()

#### _create_gizmo() -> void
- _gizmo = Node3D.new(); name = "TargetGizmo"; add_child(_gizmo)
- Colors: [Color(1,0.3,0.3), Color(0.35,1,0.45), Color(0.4,0.6,1)] (X,Y,Z)
- Rots: [Vector3(0,0,-90), Vector3.ZERO, Vector3(90,0,0)]
- For i in range(3):
  - axis_node = Node3D.new(); axis_node.rotation_degrees = rots[i]
  - _gizmo.add_child(axis_node)
  - mat = StandardMaterial3D.new(); mat.albedo_color = colors[i]; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHARED; mat.no_depth_test = true
  - shaft = MeshInstance3D.new(); cyl = CylinderMesh.new(); cyl.top_radius = 0.006; cyl.bottom_radius = 0.006; cyl.height = _gizmo_length (0.22)
  - shaft.mesh = cyl; shaft.material_override = mat; shaft.position = Vector3(0, _gizmo_length*0.5, 0)
  - axis_node.add_child(shaft)
  - tip = MeshInstance3D.new(); cone = CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 0.017; cone.height = 0.05
  - tip.mesh = cone; tip.material_override = mat; tip.position = Vector3(0, _gizmo_length+0.025, 0)
  - axis_node.add_child(tip)

#### _create_handles() -> void
- Initialize joint handles, collision setup, UI state

#### _update_handles() -> void
- Update handle positions/colors based on current arm state

#### _update_target_rings() -> void
- Update cyan emissive torus meshes around target position
- Rings render as separate visual layer

#### _check_collision() -> void
- For each obstacle mesh in _obstacle_meshes:
  - If not valid: continue
  - ga = ghost.global_transform * ghost.get_aabb()
  - oa = om.global_transform * om.get_aabb()
  - oa = oa.grow(_safe_thickness) — inflate by safe-area thickness
  - If ga.intersects(oa):
	- _colliding = true; screen_ui.set_collision(true)
	- _ghost_material.albedo_color = GHOST_COLOR_RED (1, 0.35, 0.35)
	- _approve_button.disabled = true
  - Else:
	- _colliding = false; screen_ui.set_collision(false)
	- _ghost_material.albedo_color = GHOST_COLOR_OK (0.3, 0.8, 0.7)

#### _on_reset() -> void
- If solid.is_moving(): return (block if already moving)
- ghost.reset_pose()
- target.global_position = _default_target
- solid.move_to_angles(ghost.get_joint_angles()) — animate solid to default
- screen_ui.set_busy(true)
- _command_real_arm() — send to TCP/IP if connected
- _colliding = false
- _ghost_material.albedo_color = GHOST_COLOR_OK
- _update_target_rings()

#### _on_approve() -> void
- If _colliding or solid.is_moving(): return (block if colliding or moving)
- _command_real_arm() — send ghost pose to real manipulator
- solid.move_to_angles(ghost.get_joint_angles()) — animate solid to approved pose
- screen_ui.set_busy(true) — APPROVE disabled during motion

#### _update_motion_state() -> void
- If solid == null: return
- screen_ui.set_busy(solid.is_moving())
- Keeps panel button states in sync with solid model motion status

#### _command_real_arm() -> void
- If _client == null or not _client.is_device_connected(): return
- _client.move_to_pose(_dobot_pose_from_arm(ghost))
- Sends approved tip pose to real Dobot over TCP/IP

#### _dobot_pose_from_arm(arm: Node3D) -> PackedFloat32Array
- local = arm.global_transform.affine_inverse() * arm.get_effector_transform()
- p = local.origin
- euler = local.basis.get_euler()
- x = p.x * 1000.0 (mm)
- y = -p.z * 1000.0 (mm, Z-up → base frame convention)
- z = p.y * 1000.0 (mm)
- rx = rad_to_deg(euler.x)
- ry = rad_to_deg(euler.y)
- rz = rad_to_deg(euler.z)
- Return PackedFloat32Array([x, y, z, rx, ry, rz])

### Grid and Rings

#### _create_grid() -> void
- configure_tileset_atlas(node_path, texture_path, tile_size_x, tile_size_y, separation_x, separation_y)
- For 1.4×0.9 m table with 1 cm, 1 dm, 1 m grid marks
- Texture: white grid atlas image
- Tile size: 1cm marks smallest unit
- atlas coords: 0–13 (14 tiles across for 1.4m), 0–8 (9 tiles deep for 0.9m)
- edit_tilemap() called after configure_tileset_atlas()

#### _update_target_rings() -> void
- Create/update cyan emissive torus meshes around target
- Position at target.global_position
- Emissive material with glow
- Rotation to lie in horizontal plane (XZ plane)
- Rings at multiple radii: e.g., 0.05m, 0.1m, 0.15m for different visual layers

### Safe Area

#### _setup_obstacles() -> void
- For each obstacle mesh in _obstacle_meshes:
  - Apply scanned_mesh.gdshader (fresnel rim + scan band)
  - Create safe_area shell: MeshInstance3D with safe_area.gdshader
  - Shell.mesh = om.mesh; shell_mat.set_shader_parameter("thickness", _safe_thickness)
  - om.add_child(shell)
  - _safe_shells.append(shell_mat)

#### _on_safe_thickness_changed(delta: float) -> void
- _safe_thickness = clampf(_safe_thickness + delta, 0.0, 0.06) (0–60 mm)
- For m in _safe_shells: m.set_shader_parameter("thickness", _safe_thickness)
- screen_ui.set_safe_thickness(_safe_thickness) — update UI label

### TCP/IP Client

#### _setup_client() -> void
- If _client != null: return
- _client = DobotClient.new(); add_child(_client)
- _client.host = dobot_host; _client.dashboard_port = dobot_dashboard_port; _client.motion_port = dobot_motion_port; _client.auto_connect = dobot_auto_connect
- _client.connection_changed.connect(_on_connection_changed)
- _client.message_received.connect(_on_client_message)

#### _on_connection_changed(connected: bool) -> void
- screen_ui.set_connection(connected) — update panel device status label

#### _on_client_message(_line: String) -> void
- Controller feedback; kept for logging and future status use
- pass (no immediate action)

### Desktop Gizmo and Camera

#### _pick_axis(from: Vector3, dir: Vector3) -> int
- Pick which axis gizmo arrow the mouse ray hits closest
- Returns 0=X, 1=Y, 2=Z, -1=no axis hit
- Uses _closest_line_param() for ray→closest-point-on-line calculation

#### _closest_line_param(p: Vector3, a: Vector3, o: Vector3, d: Vector3) -> float
- Line parameter s so point (p + a*s) is nearest ray (o + d*t)
- Handles parallel cases (denom ≈ 0 returns NAN)

#### _update_vr_input(delta: float) -> void
- VR controller input handling when XR active
- Grip, trigger, select actions
- Push-pull target distance via joystick

#==============================================================================
# 06 - screen_ui.gd DETAILED REFERENCE
#==============================================================================

## Class: ScreenUI (extends Control)
## Class Name: screen_ui

### Signals
- reset_pressed — emitted when RESET button clicked (desktop: no shift, on screen)
- approve_pressed — emitted when APPROVE button clicked (desktop: shift held, on screen)
- safe_thickness_changed(delta: float) — emitted when thickness +/- clicked

### Exported/Internal State
- var _approve_button: Button
- var _reset_button: Button
- var _status_label: Label
- var _connection_label: Label
- var _thickness_label: Label
- var _colliding := false
- var _busy := false
- var _connected := false
- var _thickness := 0.02 (metres; UI shows as mm: int(roundf(value*1000)))

### _ready() -> void
- set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
- focus_mode = Control.FOCUS_ALL — enables desktop mouse click reception
- bg = ColorRect.new(); color = Color(0,0,0,1); full rect
- margin = MarginContainer.new(); full rect; theme constant overrides (22px all sides)
- add_child(margin)
- vbox = VBoxContainer.new(); separation = 12
- margin.add_child(vbox)
- title = Label.new(); text = "MANIPULATOR CONTROL"; font_size 33; font_color = Color(0.9, 0.95, 1.0); HORIZONTAL_ALIGNMENT_CENTER
- vbox.add_child(title)
- _connection_label = Label.new(); font_size 20; horizontal_alignment = CENTER
- vbox.add_child(_connection_label)
- _status_label = Label.new(); font_size 26; horizontal_alignment = CENTER; vertical_alignment = VERTICAL_ALIGNMENT_CENTER; size_flags_vertical = SIZE_EXPAND_FILL
- vbox.add_child(_status_label)
- thickness_row = HBoxContainer.new(); separation = 10
- vbox.add_child(thickness_row)
- thickness_title = Label.new(); text = "Mesh safe area"; font_size 20; size_flags_horizontal = SIZE_EXPAND_FILL
- thickness_row.add_child(thickness_title)
- minus = _make_button("-", 56, 30); custom_minimum_size = Vector2(64,56); SIZE_SHRINK_CENTER; pressed → safe_thickness_changed.emit(-0.002)
- thickness_row.add_child(minus)
- _thickness_label = Label.new(); text = "20 mm"; font_size 22; horizontal_alignment = CENTER; custom_minimum_size = Vector2(110,0)
- thickness_row.add_child(_thickness_label)
- plus = _make_button("+", 56, 30); custom_minimum_size = Vector2(64,56); SIZE_SHRINK_CENTER; pressed → safe_thickness_changed.emit(0.002)
- thickness_row.add_child(plus)
- row = HBoxContainer.new(); separation = 16
- vbox.add_child(row)
- _reset_button = _make_button("RESET", 84, 32); pressed → reset_pressed.emit()
- row.add_child(_reset_button)
- _approve_button = _make_button("APPROVE", 84, 32); pressed → approve_pressed.emit()
- row.add_child(_approve_button)
- set_connection(false); _refresh()

### _make_button(label: String, height: int = 84, font_size: int = 32) -> Button
- button = Button.new()
- button.text = label
- button.custom_minimum_size = Vector2(0, height)
- button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
- button.add_theme_font_size_override("font_size", font_size)
- Return button

### State Functions

#### set_collision(colliding: bool) -> void
- If colliding == _colliding: return
- _colliding = colliding; _refresh()

#### set_busy(busy: bool) -> void
- If busy == _busy: return
- _busy = busy; _refresh()
- Updates: button states (disabled), button modulate (0.4 if disabled), status label text/color
- If busy: text = "MOVING - please wait", color = Color(1, 0.82, 0.35)
- Else if colliding: text = "COLLISION - cannot approve", color = Color(1, 0.35, 0.35)
- Else: text = "Ready", color = Color(0.7, 1, 0.7)

#### set_connection(connected: bool) -> void
- _connected = connected
- If _connection_label == null: return
- If connected: text = "Device: CONNECTED"; font_color = Color(0.5, 1, 0.6)
- Else: text = "Device: not connected"; font_color = Color(1, 0.6, 0.4)

#### set_safe_thickness(value: float) -> void
- _thickness = value
- If _thickness_label: text = "%d mm" % int(roundf(value * 1000.0))

#### _refresh() -> void
- var text, color, approve_disabled, reset_disabled
- If _busy: text = "MOVING - please wait"; color = Color(1, 0.82, 0.35); approve_disabled = true; reset_disabled = true
- Elif _colliding: text = "COLLISION - cannot approve"; color = Color(1, 0.35, 0.35); approve_disabled = true
- Else: text = "Ready"; color = Color(0.7, 1, 0.7)
- If _approve_button: _approve_button.disabled = approve_disabled; _approve_button.modulate = Color(1,1,1,0.4) if approve_disabled else Color(1,1,1,1)
- If _reset_button: _reset_button.disabled = reset_disabled; _reset_button.modulate = Color(1,1,1,0.4) if reset_disabled else Color(1,1,1,1)
- If _status_label: _status_label.text = text; _status_label.add_theme_color_override("font_color", color)

### is_colliding() -> bool
- Return _colliding

### Desktop Click Handling (connected from manipulator_station._check_screen_click)
- When mouse click approximated to be "on screen" area (~20 cm of target center):
  - No shift: emit reset_pressed
  - Shift held: emit approve_pressed

#==============================================================================
# 07 - dobot_client.gd DETAILED REFERENCE
#==============================================================================

## Class: DobotClient (extends Node2D or Node, typically added as child of station)
## Class Name: dobot_client

### Purpose
Minimal TCP/IP client for Dobot CR-series robotic controllers. Provides connection tracking, auto-reconnect, and dashboard/motion ports.

### Exported Variables
- var host: String = "192.168.5.1" — controller IP address
- var dashboard_port: int = 29999 — dashboard/enable/status port
- var motion_port: int = 30003 — motion command port
- var auto_connect: bool = true — auto-connect on ready
- var _connected := false — internal connection state

### Key Functions

#### _ready() -> void
- If auto_connect: connect_tcp()
- Set up timers for auto-reconnect (every 5 s if disconnected)

#### connect_tcp() -> void
- Attempt TCP connection to host:dashboard_port
- On success: EnableRobot(), SpeedFactor(50)
- On failure: retry after 5 s via timer
- Emit connection_changed(true/false)

#### _on_connection_tcp_completed(success: bool) -> void
- If success: _connected = true; emit connection_changed(true)
- If failure: _connected = false; schedule retry after 5 s

#### send_motion_command(packed: PackedFloat32Array) -> void
- Send [0x01, *packed] to motion_port
- Format: joint targets or pose coordinates depending on Dobot protocol

#### enable_robot() -> void
- Send EnableRobot() command to dashboard_port
- Receive and drain feedback lines
- Print verbose if enabled

#### speed_factor(factor: int) -> void
- Send SpeedFactor(factor) to dashboard_port (50 = 50% speed)

#### Auto-Reconnect Timer
- timeout() → connect_tcp()
- Fires every 5 s when disconnected

### Signals
- connection_changed(connected: bool) — emitted when connection state changes
- message_received(line: String) — emitted when a line of feedback is received from controller

### is_device_connected() -> bool
- Return _connected
- Avoids clash with Godot Object.is_connected() by using qualified name

### Typical Usage in manipulator_station.gd
```gdscript
func _setup_client() -> void:
	_client = DobotClient.new()
	_client.host = "192.168.5.1"
	_client.dashboard_port = 29999
	_client.motion_port = 30003
	add_child(_client)
	_client.connection_changed.connect(_on_connection_changed)
	_client.message_received.connect(_on_client_message)

func _on_connection_changed(connected: bool):
	screen_ui.set_connection(connected)
```

#==============================================================================
# 08 - SHADER REFERENCE
#==============================================================================

## meter_grid.gdshader
### Type: GDShader (Godot 4.3+)
### Purpose: White metre/cdm/cm grid projected onto a PlaneMesh sized to table

### Uniforms
- cm_alpha: float (0.0–1.0) — dm line opacity
- dm_alpha: float (0.0–1.0) — cm line opacity
- m_alpha: float (0.0–1.0) — metre line opacity

### Shader Logic
- Receive vertex position in grid local space
- Compute cell coordinates: cell_x = floor(pos.x / tile_size), cell_y = floor(pos.y / tile_size)
- Determine cell type: m = both cell_x and cell_y multiples of 10; dm = one multiple, other not; cm = neither multiple but within 0.5 of a multiple
- Assign alpha based on type: m → m_alpha, dm → dm_alpha, cm → cm_alpha, else 0.0
- Output color = Color(1,1,1, alpha) — white grid lines

### Usage
- attach to PlaneMesh node scaled to table (1.4×0.9 m)
- TileMapLayer with TileSetAtlasSource configured via configure_tileset_atlas()
- edit_tilemap() places actual tile entries

## floor_effect.gdshader
### Type: GDShader
### Purpose: Dark radial gradient floor + world grid + grain overlay

### Uniforms
- grid_spacing: float = 0.5 (metres between grid lines, default)

### Shader Logic
- Radial gradient from world centre: distance_from_centre = length(pos.xz); gradient = 1.0 - smoothstep(0.0, max_radius, distance_from_centre)
- World grid lines: similar cell logic to meter_grid but with grid_spacing uniform
- Grain overlay: noise function added to gradient for texture detail
- Output = Color(0.13, 0.135, 0.145, gradient) — dark gray base with gradient

### Usage
- attach to Floor PlaneMesh
- World-space projection; grid_spacing = 0.5 m gives 0.5 m grid over floor

## solid_sky.gdshader
### Type: GDShader
### Purpose: Near-solid gradient skybox with grain

### Uniforms
- horizon_color: Color — color at horizon line
- zenith_color: Color — color at zenith (top of sky)
- gradient_power: float — controls gradient sharpness (higher = sharper transition)
- grain: float — grain intensity for atmospheric texture

### Shader Logic
- Compute normalized vertical angle: zenith = vertical direction dot view_vector; horizon = horizontal plane dot view_vector
- Interpolate between horizon_color and zenith_color based on zenith value
- Apply gradient_power to control transition sharpness
- Add grain overlay: noise(pos * grain) for subtle texture
- Output = interpolated color with optional opacity fade

### Usage
- Attach to WorldEnvironment's sky material
- Creates atmospheric effect without overwhelming the 3D scene

## scanned_mesh.gdshader
### Type: GDShader
### Purpose: For obstacle meshes from 3D scanner software

### Features
- Fresnel rim effect: edge glow proportional to view angle
- Animated scan band: moving gradient/slot across mesh surface
- Matte base lighting suitable for noisy/deformed geometry

### Uniforms (typical)
- scan_speed: float — speed of animated band
- rim_intensity: float — strength of edge glow

### Usage
- Applied to each MeshInstance3D in the "obstacles" group
- Used alongside safe_area.gdshader for dual rendering

## safe_area.gdshader
### Type: GDShader
### Purpose: Translucent shell that inflates obstacles outward by configurable thickness

### Uniforms
- thickness: float (metres, 0.0–0.06 range, default 0.02 = 20 mm)

### Shader Logic
- Receive mesh geometry; expand vertices outward along normal by `thickness`
- Keep original mesh for base rendering; render shell in translucent cyan
- Alpha based on thickness: thicker = more opaque
- Output = Color(0.3, 0.8, 1, alpha) — cyan translucent

### Usage
- Created per-obstacle in _setup_obstacles()
- thickness updated via UI +/- buttons
- Also inflates AABB in collision check: oa.grow(_safe_thickness)

#==============================================================================
# 09 - SCENE (main.tscn) NODE BY NODE
#==============================================================================

## Top-Level Node: Node3D (world root)

### XR Origin
- XROrigin3D: XR rig root
  - current = true (default; set false for desktop fallback)
  - XRCamera3D: main camera when XR active
  - LeftHand: XRController3D, tracker = "/user/hand/left"
  - RightHand: XRController3D, tracker = "/user/hand/right"

### Desktop Camera (FallbacK)
- DesktopCamera: Camera3D
  - Used when XR not active
  - Project rays for screen click, target gizmo, orbit controls
  - Transform: typical position for head-on panel view

### Directional Light
- Sun: DirectionalLight3D
  - Typical rotation for outdoor/indoor mixed lighting

### Floor
- Floor: MeshInstance3D
  - Mesh: PlaneMesh, size = Vector2(12, 12)
  - Material: StandardMaterial3D, albedo_color = Color(0.28, 0.3, 0.33)
  - CollisionShape3D: BoxShape3D, size = Vector3(12, 0.06, 12)
  - Position: y = -0.55 (half below table top at y=0)

### Table
- Table: StaticBody3D
  - Transform: identity + y=0.71 (raises to tabletop height)
  - Mesh: BoxMesh, size = Vector3(1.4, 0.06, 0.9) (1.4×0.9 m = real-world table)
  - Material: StandardMaterial3D, albedo_color = Color(0.13, 0.135, 0.145) (dark gray)
  - CollisionShape: SubResource table_shape, size = Vector3(1.4, 0.06, 0.9)

### Obstacles (Collision Group)
- Obstacles: Node3D, groups = ["obstacles"]
  - Pillar: MeshInstance3D, groups = ["obstacles"]
    - Transform: y=0.94, z=-0.52
    - Mesh: BoxMesh, size = Vector3(0.12, 0.4, 0.12)
    - Material: obstacle_mat (albedo = Color(0.55, 0.2, 0.15))
  - Block: MeshInstance3D, groups = ["obstacles"]
    - Transform: y=0.88, z=-0.45
    - Mesh: BoxMesh, size = Vector3(0.22, 0.16, 0.22)

### Target
- Target: Node3D
  - Transform: identity + y=1.4296, z=-0.75 (above table, in front)
  - Mesh: SphereMesh, radius = 0.05, height = 0.1 (cyindrical for visibility)
  - MeshInstance3D.Mesh = target_mesh
  - Material: target_mat
    - transparency = 1
    - albedo_color = Color(0.3, 0.65, 1, 0.65) (cyan semi-transparent)
  - Used by DobotCR3 as IK target
  - Also: raycast destination, grid center point, ring center

### ArmGhost (Live IK)
- ArmGhost: instance of dobot_cr3.fbx
  - Parent: world root (same level as Table, Target, etc.)
  - Transform: identity + y=0.74, z=-0.75 (same base position as ArmSolid)
  - Script: dobot_cr3.gd (DobotCR3)
  - solve_enabled = true (runs CCD every frame)
  - Half-transparent material (modify via _ghost_material)
  - Tracks target global_position via set_target()
  - Emits target_reached when IK converges
  - Collision checked vs obstacles; on overlap → red, APPROVE disabled

### ArmSolid (Committed Model)
- ArmSolid: instance of dobot_cr3.fbx
  - Parent: world root (same level as ArmGhost, Table, etc.)
  - Transform: identity + y=0.74, z=-0.75 (same base as ArmGhost)
  - Script: dobot_cr3.gd (DobotCR3)
  - solve_enabled = false (IK disabled; moved via timed motion)
  - Controlled by move_to_angles() from ghost or manual reset
  - Timed motion: move_to_angles(ghost.get_joint_angles()) on Approve
  - _advance_move(delta) called each frame in station._process()
  - Buttons blocked while solid.is_moving()
  - Sends pose to TCP/IP via _command_real_arm() on Approve

### Screen (UI Overlay)
- Screen: Node3D
  - Transform: typical VR screen position (e.g., Transform3D(0.45447, 0.337224, -0.824461, ...))
  - SubViewport: SubViewport, disable_3d = true, size = Vector2i(512, 320)
    - render_target_update_mode = 4 (ONCE per frame)
    - UI: Control, anchors_preset = 15, anchor_right = 1.0, anchor_bottom = 1.0, grow_horizontal = 2, grow_vertical = 2
    - Script: screen_ui.gd (ScreenUI)
  - DesktopCamera: Camera3D (fallback raycasters, separate from XRCamera)
    - For desktop input when XR not active

### Meter Grid
- MeterGrid: TileMapLayer (Godot 4.3+)
  - TileSet configured via configure_tileset_atlas()
  - Atlas source: white grid texture with 1cm/1dm/1m marks
  - Tile size: 1cm smallest unit
  - Physics layers: optional (not always enabled)
  - edit_tilemap() places tiles after atlas config
  - Renders white grid on 1.4×0.9 m table surface
  - Uniforms: cm_alpha, dm_alpha, m_alpha control line visibility

### Cyan Ranging Rings
- Ring1, Ring2, Ring3: MeshInstance3D (emissive torus meshes)
  - TorusMesh: radii (r1=0.05, r2=0.1 outer); sides=32; rings=1
  - Position: target.global_position (center on target)
  - Rotation: rotate 90 degrees to lie in horizontal (XZ) plane
  - Material: StandardMaterial3D, shading_unshaded, emissive_color = cyan (0.3, 0.8, 1)
  - No depth test for glowing effect
  - Scale varies per ring for different sizes
- Render as separate layer from grid so they glow correctly with environment

#==============================================================================
# 10 - INPUT HANDLING AND DESKTOP FALLBACK
#==============================================================================

## 10.1 XR vs Desktop Input Paths

### When XR Active (use_xr = true)
- _update_vr_input(delta): controller grip/trigger/select, push-pull joystick
- Laser pointers from controllers for target pointing
- No mouse input processing (events consumed by XR overlay)

### When XR Not Active (desktop fallback)
- _update_orbit_camera(): right-drag orbits, wheel zooms, pitch/yaw limits
- _update_desktop_input(delta): mouse handling for target movement and screen clicks
- _create_gizmo(): target move axes visualization
- Screen UI clickable via _check_screen_click() raycast

## 10.2 Orbit Camera (Desktop)
- _cam_pivot: centre point orbit centre (Vector3(0.1, 0.95, -0.62) approx)
- _cam_yaw, _cam_pitch: angular state, clamped
- _cam_distance: distance from pivot, clamped [0.6, 5.0]
- Each frame: dir = Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch)); pos = pivot + dir*distance; look_at(pivot, UP)

## 10.3 Target Gizmo (Desktop)
- _gizmo: Node3D with 3 colored axes (R/G/B)
- Left-drag axis: slide target along that axis direction
- Left-drag sphere: move target on camera-facing plane
- Axis colors: Red=X, Green=Y, Blue=Z
- Length: _gizmo_length = 0.22 m

## 10.4 Screen Click (Desktop)
- _check_screen_click(): raycast from DesktopCamera through mouse position
- Approximate hit test: if ray reaches screen Z ≈ -0.82 and is within ~20 cm of target center
- Shift held + click → emit approve_pressed
- No shift + click → emit reset_pressed
- This allows desktop users to interact with the control panel

## 10.5 VR Controller Input (when XR active)
- Grip: grab target (move with controller)
- Trigger: push-pull target along camera Z axis (adjust distance)
- Select: toggle modes or release grab
- Joystick: adjust target distance/orientation
- All handled in _update_vr_input(delta)

#==============================================================================
# 11 - PHYSICS AND COLLISION SETUP
#==============================================================================

## 11.1 Collision Groups
- Obstacles group: ["obstacles"] — assigned to pillars, blocks, and ghost mesh instances
- Other groups not actively used; collision checked via AABB overlap

## 11.2 AABB Overlap Check
- For each ghost obstacle mesh: ga = ghost.global_transform * ghost.get_aabb()
- For each static obstacle: oa = om.global_transform * om.get_aabb()
- oa = oa.grow(_safe_thickness) — inflate by safe-area thickness (0.02 default)
- If ga.intersects(oa): collision detected

## 11.3 Safe-Area Inflation
- _safe_thickness starts at 0.02 (20 mm)
- UI +/- buttons adjust in 0.005 (5 mm) steps
- Range: 0.0–0.06 (0–60 mm)
- Inflation used in TWO places:
  1. Render: safe_area.gdshader shell expands vertices by thickness
  2. Collision: oa.grow(_safe_thickness) before AABB overlap check
- This accounts for scanned mesh noise and prevents grazing contacts

## 11.4 Table Collision
- Table: StaticBody3D with CollisionShape3D
- CollisionShape: BoxShape3D, size = 1.4×0.06×0.9 m
- AABB overlaps with ghost checked but typically ignored (focus on obstacles)

## 11.5 Floor Collision
- Floor: MeshInstance3D + CollisionShape3D, BoxShape3D size 12×0.06×12 m
- No ghost collision typically; may check for completeness

#==============================================================================
# 12 - GRID AND RINGS CONFIGURATION
#==============================================================================

## 12.1 Grid Configuration (main.tscn setup)

### configure_tileset_atlas() Call
```gdscript
configure_tileset_atlas(
    file_path: "res://main.tscn",
    node_path: "MeterGrid",  # TileMapLayer name
    texture_path: "res://assets/grid_atlas.png",  # white grid texture
    tile_size_x: 1,  # 1 cm smallest unit
    tile_size_y: 1,
    separation_x: 0,  # no separation between tiles
    separation_y: 0,
    texture_region_size_x: 14,  # 14 tiles across for 1.4m width
    texture_region_size_y: 9,   # 9 tiles deep for 0.9m depth
    source_id: 0,
    physics_collision_layer: 0,  # optional
    physics_collision_mask: 0,   # optional
    add_collision_shapes: false  # grid is visual only
)
```

### Following: edit_tilemap() calls for each grid feature
- horizontal lines at each Y row
- vertical lines at each X column
- Fill rectangles for meter/dm/cm markings
- Overlapping edits applied in correct order (erase then fill)

### Grid Layout (1.4 × 0.9 m)
- Width: 1.4 m = 140 cm = 14 tiles of 10 cm each (atlas region 0–13)
- Depth: 0.9 m = 90 cm = 9 tiles of 10 cm each (atlas region 0–8)
- 1 m marks: every 10th cm (positions 0, 10, 20, ..., 130 cm)
- dm marks: every 100 cm (positions 0, 100 cm → just 0 and 0.9m approx)
- cm marks: every 10 cm

### edit_tilemap() Operations
- horizontal_line: x_start, x_end, y — draws horizontal line of tiles at row y
- vertical_line: x, y_start, y_end — draws vertical line of tiles at column x
- fill: x, y, width, height — fills rectangle of tiles
- erase: x, y, width, height — removes tiles (used before fill for clean edges)

## 12.2 Cyan Ranging Rings Configuration

### TorusMesh Creation
```gdscript
# For each ring radius
var ring_radius: float  # e.g., 0.05, 0.1, 0.15
var ring_mesh = TorusMesh.new()
ring_mesh.radius = ring_radius  # distance from centre to tube centre
ring_mesh.tube_radius = 0.01  # tube thickness
ring_mesh.sides = 32  # circumferential resolution
ring_mesh.rings = 1  # 1 ring torus
mesh_instance.mesh = ring_mesh
```

### Position and Rotation
```gdscript
# Around target position
ring_instance.global_position = target.global_position
# Rotate 90 degrees to lie in horizontal (XZ) plane
ring_instance.rotation_degrees = Vector3(-90, 0, 0)  # or appropriate rotation
```

### Emissive Material
```gdscript
var mat = StandardMaterial3D.new()
mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHARED
mat.no_depth_test = true  # important for glowing effect
mat.emissive_color = Color(0.3, 0.8, 1)  # cyan glow
mesh_instance.material_override = mat
```

### Multiple Rings
- 3 typical rings at radii: 0.05 m (5 cm), 0.1 m (10 cm), 0.15 m (15 cm)
- All share same centre: target.global_position
- All in horizontal plane (XZ)
- Different emissive intensities or colors if desired
- Render after grid so they appear on top

## 12.3 Grid Render Order
1. Floor effect shader (dark radial gradient + world grid)
2. Meter grid (white cm/dm/m lines on table surface)
3. Cyan ranging rings (emissive, on top, no depth test)
4. Obstacles + ghost/solid arms
5. Target (cyan sphere)
6. Skybox (solid_sky.shader, behind everything)

#==============================================================================
# 13 - SAFE AREA VISUALIZATION
#==============================================================================

## 13.1 Safe-Area Shell Creation

### _setup_obstacles() Function
For each MeshInstance3D in the "obstacles" group:
1. Apply scanned_mesh.gdshader (fresnel rim + animated scan band)
2. Create new MeshInstance3D: "SafeArea" child of obstacle
3. Mesh.shared_type = original.mesh (or duplicate)
4. Create ShaderMaterial: shell_mat
5. shell_mat.shader = load("res://shaders/safe_area.gdshader")
6. shell_mat.set_shader_parameter("thickness", _safe_thickness)
7. shell_mesh.material_override = shell_mat
8. shell_mesh.position = Vector3(0,0,0) (offset to original centre)
9. obstacle.add_child(shell_mesh)
10. _safe_shells.append(shell_mat)

## 13.2 Thickness Control

### UI Controls
- Row in ScreenUI: "Mesh safe area" label, "-" button, "20 mm" label, "+" button
- "-" pressed: safe_thickness_changed.emit(-0.002) (decrease 2 mm)
- "+" pressed: safe_thickness_changed.emit(0.002) (increase 2 mm)
- Range clamped: 0.0..0.06 (0..60 mm)

### _on_safe_thickness_changed(delta: float) -> void
```gdscript
func _on_safe_thickness_changed(delta: float) -> void:
    _safe_thickness = clampf(_safe_thickness + delta, 0.0, 0.06)
    For m in _safe_shells:
        m.set_shader_parameter("thickness", _safe_thickness)
    screen_ui.set_safe_thickness(_safe_thickness)  # update UI label
```

### Visual Change
- 0.02 (20 mm): subtle inflation, just visible
- 0.05 (50 mm): clearly inflated, obvious safe distance
- 0.06 (60 mm): maximum, may overlap with other objects

### Collision Impact
- Each increment increases collision volume by that amount
- Affects when ghost collides with obstacles
- Affects when APPROVE becomes enabled/disabled
- Verified: 20 mm → 26 mm change tested and working

## 13.3 Shader: safe_area.gdshader Details

### Vertex Expansion
```glsl
# Expand vertices along normal by thickness
vec3 expanded_normal = normalize(v_normal) * thickness;
vec3 expanded_position = v_position + expanded_normal;
```

### Rendering
- Render original mesh with scanned_mesh.gdshader (base)
- Render expanded shell with safe_area.gdshader (translucent cyan on top)
- Shell has slightly larger radius than original
- Alpha fade at edges for soft transition

### Uniforms
- thickness: float (0.0-0.06)
- Base color: automatically cyan (0.3, 0.8, 1) or configurable

#==============================================================================
# 14 - TCP/IP COMMUNICATION PROTOCOL
#==============================================================================

## 14.1 Connection Architecture
- Two ports on Dobot controller:
  - Dashboard port (default 29999): enable, status, dashboard commands
  - Motion port (default 30003): motion commands, pose targets
- Client connects to both; EnableRobot() on dashboard first

## 14.2 Command Format

### EnableRobot() (dashboard port)
- Send: [0x01, 0x00] or similar Dobot protocol header
- Receive feedback: robot mode, error status, current pose
- Drain all feedback lines until idle

### SpeedFactor(factor) (dashboard port)
- factor: 1-100 percentage
- Default in code: 50 (50% speed)
- Affects all subsequent motion commands

### MoveJ/Pose (motion port)
- PackedFloat32Array[6]: [x, y, z, rx, ry, rz]
- x, y, z: millimetres from base origin
- rx, ry, rz: Euler angles in degrees, Z-up convention
- Convention conversion: Godot Z-up → Dobot base frame
  - Godot origin at base, X-right, Y-forward, Z-up
  - Dobot: X-forward, Y-right, Z-up (typically)
- Conversion in _dobot_pose_from_arm():
  - x_godot * 1000 → x_mm
  - y_godot * -1000 → y_mm (negated for frame convention)
  - z_godot * 1000 → z_mm
  - euler angles rad → deg

### Auto-Reconnect
- If connection drops: timer fires after 5 s, attempts reconnect
- All previous state preserved; re-EnableRobot if needed
- Client object persists across scenes (add_child, not freedup)

## 14.3 Pose Transmission (on Approve)

### _command_real_arm() -> void
```gdscript
func _command_real_arm() -> void:
    If _client == null or not _client.is_device_connected(): return
    _client.move_to_pose(_dobot_pose_from_arm(ghost))
```

### _dobot_pose_from_arm() -> PackedFloat32Array
```gdscript
func _dobot_pose_from_arm(arm: Node3D) -> PackedFloat32Array:
    local = arm.global_transform.affine_inverse() * arm.get_effector_transform()
    p = local.origin
    euler = local.basis.get_euler()
    x = p.x * 1000.0    # metres → mm
    y = -p.z * 1000.0   # Z-up → base frame convention
    z = p.y * 1000.0
    rx = rad_to_deg(euler.x)
    ry = rad_to_deg(euler.y)
    rz = rad_to_deg(euler.z)
    return PackedFloat32Array([x, y, z, rx, ry, rz])
```

### Typical Sent Pose
- [1200, -800, 500, 10, -20, 45] example: x=1200mm, y=-800mm, z=500mm, rx=10°, ry=-20°, rz=45°
- Sent via _client.move_to_pose() to motion port
- Real Dobot would execute MovJ or similar command

## 14.4 Connection Status on Panel
- screen_ui.set_connection(connected) updates label:
  - "Device: CONNECTED" green-tinted
  - "Device: not connected" orange-tinted
- _on_connection_changed called from DobotClient

#==============================================================================
# 15 - TIMING AND MOTION SYSTEM
#==============================================================================

## 15.1 Timed Motion Flow

### APPROVE Path
1. User clicks APPROVE (shift+click on screen in desktop, or controller button in VR)
2. _on_approve() called
3. Check: not _colliding and not solid.is_moving()
4. _command_real_arm(): send pose to TCP/IP (if connected)
5. solid.move_to_angles(ghost.get_joint_angles()): start timed motion
6. screen_ui.set_busy(true): disable APPROVE/RESET buttons
7. Each _process() frame: solid._advance_move(delta) advances interpolation
8. When _advance_move completes (t >= 1.0): _move_active = false, move_finished emitted
9. screen_ui._update_motion_state(): re-enable buttons, show "Ready"

### Verified Timeline
- Full pose change (all 6 joints from rest to new position): ~1.25 s at default_speed=0.6 rad/s
- Shorter moves (small angle delta): proportionally less time
- Buttons re-enabled exactly when motion finishes

### RESET Path
1. User clicks RESET
2. _on_reset() called
3. If solid.is_moving(): return (block if already moving)
4. ghost.reset_pose(): restore IK to default angles
5. target.global_position = _default_target: reset target position
6. solid.move_to_angles(ghost.get_joint_angles()): animate solid to default pose
7. screen_ui.set_busy(true) during motion
8. On completion: buttons re-enabled, status "Ready"

## 15.2 Motion State Synchronization

### _update_motion_state() -> void
```gdscript
func _update_motion_state() -> void:
    If solid == null: return
    screen_ui.set_busy(solid.is_moving())
```
- Called each _process() frame
- Keeps panel button states in sync with solid model
- If motion done: buttons clickable again
- If motion in progress: APPROVE disabled, shows "MOVING - please wait"

### Button State Summary
| State | APPROVE Disabled? | RESET Disabled? | Status Label |
|-------|-------------------|-----------------|-------------|
| Idle | No | No | "Ready" |
| Collision | Yes | Yes (if also moving) | "COLLISION - cannot approve" |
| Moving | Yes | Yes | "MOVING - please wait" |
| Approve Pending (collision) | Yes | No | "COLLISION - cannot approve" |

## 15.3 Speed Control

### default_speed export
- var default_speed: float = 0.6 (radians per second)
- Used by move_to_angles() when speed parameter is negative
- Can be exposed on manipulator_station for tuning
- Higher = faster motion, shorter time to complete
- Lower = slower, more controlled movement

### Per-Move Speed Override
```gdscript
solid.move_to_angles(target_angles, 0.8)  # 0.8 rad/s instead of default
```
- Overrides default_speed for that specific move
- Useful for different gesture speeds or safety constraints

#==============================================================================
# 16 - SIGNALS AND EVENTS MAP
#==============================================================================

## DobotCR3 Signals
- target_reached(joint_angles: PackedFloat32Array) — emitted when IK converges within tolerance
- move_finished — emitted when timed move_to_angles() completes

## ManipulatorStation Signals (connected from screen_ui)
- screen_ui.reset_pressed → _on_reset() — reset both arms + target
- screen_ui.approve_pressed → _on_approve() — copy ghost→solid, start motion
- screen_ui.safe_thickness_changed(delta) → _on_safe_thickness_changed() — update safe-area

## ScreenUI Internal Signals
- reset_pressed — user wants to reset pose
- approve_pressed — user wants to approve current pose
- safe_thickness_changed(delta) — user adjusting mesh safe-area thickness

## DobotClient Signals
- connection_changed(connected: bool) — TCP/IP connection state
- message_received(line: String) — controller feedback line

## Desktop Input Mappings
- Mouse left-click on screen (no modifier): reset_pressed
- Mouse left-click on screen (Shift held): approve_pressed
- Mouse right-drag: orbit camera
- Mouse wheel: zoom camera
- Grip (VR): grab target
- Trigger (VR): push-pull target
- Select (VR): toggle modes

#==============================================================================
# 17 - TROUBLESHOOTING GUIDE
#==============================================================================

## Common Issues and Fixes

### 1. OpenXR Blocking on Linux
- **Symptom**: Godot subprocess stalls on startup; zenity dialog appears blocking everything
- **Cause**: xr/openxr/enabled = true on headless Linux without headset
- **Fix**: Keep xr/openxr/enabled = false and xr/shaders/enabled = false during development on this machine
- **For target Windows**: re-enable both before deployment build

### 2. Arm "Falling Apart" (Joints Detaching)
- **Symptom**: Solid model joints appear to separate or float during timed motion
- **Cause**: _advance_move(delta) not called each _process() frame
- **Fix**: Ensure station._process() calls solid._advance_move(delta) (added in this project)
- **Verification**: Tested — motion now completes smoothly ~1.25 s, buttons gate correctly

### 3. Screen Not Clickable in Desktop Mode
- **Symptom**: RESET/Approve buttons visible but unresponsive with mouse
- **Cause**: Screen UI inside SubViewport not receiving mouse events in main viewport
- **Fix**: 
  - screen_ui.gd: focus_mode = Control.FOCUS_ALL
  - manipulator_station.gd: _check_screen_click() raycast from DesktopCamera
  - Shift+click = approve, otherwise reset
- **Verification**: Tested — desktop click now emits correct signals

### 4. Safe-Area Thickness Not Updating
- **Symptom**: UI +/- buttons have no effect on obstacle inflation
- **Cause**: _on_safe_thickness_changed not connected or _safe_shells empty
- **Fix**: 
  - Connect screen_ui.safe_thickness_changed to _on_safe_thickness_changed in _ready()
  - _setup_obstacles() must create _safe_shells
  - Both shell shader parameter AND collision AABB must be updated
- **Verification**: Tested 20mm→26mm change works for both shader and collision

### 5. TCP/IP Not Connecting
- **Symptom**: Panel shows "Device: not connected"; no motion sent on Approve
- **Cause**: Wrong host/port; firewall blocking; Dobot not enabled
- **Fix**: 
  - Check dobot_host export (default 192.168.5.1)
  - Ensure Dobot controller powered and on same network
  - Enable dashboard port (29999) and motion port (30003)
  - Client auto-reconnects every 5 s if disconnected

### 6. Grid Not Appearing or Wrong Scale
- **Symptom**: No grid lines, or grid doesn't match 1.4×0.9 m table
- **Cause**: configure_tileset_atlas() parameters wrong; texture region size wrong; edit_tilemap not called
- **Fix**: 
  - Verify texture is 14×9 grid of 1cm cells (140×90 px approx)
  - configure_tileset_atlas: texture_region_size_x=14, texture_region_size_y=9
  - Tile size: 1 cm (tile_size_x=1, tile_size_y=1)
  - Call edit_tilemap() after configure_tileset_atlas()
  - Check tile atlas image file path

### 7. Rings Not Glowing or Wrong Position
- **Symptom**: Cyan rings not visible, or not centered on target
- **Cause**: TorusMesh parameters wrong; position not set to target.global_position; emissive color wrong
- **Fix**: 
  - Set ring.global_position = target.global_position
  - Rotate 90° to lie in horizontal plane
  - Use emissive_color = Color(0.3, 0.8, 1) with no_depth_test
  - Render rings after grid in render order

### 8. Collision Not Detecting
- **Symptom**: Ghost passes through obstacles without turning red
- **Cause**: 
  - _safe_thickness too small (increase via UI)
  - Obstacles not in "obstacles" group
  - AABB computation wrong (check oa.grow(_safe_thickness) in _check_collision)
  - Ghost mesh missing collision geometry
- **Fix**: 
  - Adjust safe-area thickness UI (0-60 mm range)
  - Ensure all obstacle meshes have groups=["obstacles"]
  - Verify _check_collision() inflates AABB before overlap check

### 9. Timed Motion Too Fast/Slow
- **Symptom**: Pose animation completes too quickly or too slowly
- **Cause**: default_speed not appropriate for distance; or per-move speed wrong
- **Fix**: 
  - Adjust default_speed export (currently 0.6 rad/s)
  - Override with move_to_angles(angles, custom_speed) for specific moves
  - Verify: full pose change ~1.25 s at 0.6 rad/s

### 10. Joint Limits Violated
- **Symptom**: IK solver produces angles outside URDF limits
- **Cause**: _clamped_delta should prevent this, but verify JOINT_LIMITS constants
- **Fix**: 
  - JOINT_LIMITS from cr3.urdf: J1±π, J2±π, J3±2.705, J4±π, J5±π, J6±π
  - Ensure _compute_axes() works correctly with rest-pose geometry
  - Check pinned joints if manual editing moving outside limits

## When to Check Memory Files
- dobot-rig-axes.md: if joint axes seem wrong
- openxr-blocks-subprocess.md: if headless Linux Zenity dialog appears
- project-recreation-guide.md: full overview and troubleshooting

#==============================================================================
# 18 - MAINTENANCE AND EXTENSION
#==============================================================================

## 18.1 Adding New Shaders
1. Create .gdshader file in res://shaders/
2. Define uniforms relevant to effect
3. Attach to appropriate Node3D/MeshInstance3D
4. Update configure_tileset_atlas() or _setup_obstacles() as needed

## 18.2 Extending the Joint Chain
1. Add joint node to dobot_cr3.fbx import
2. Update @onready var joints: Array in dobot_cr3.gd
3. Add entry to JOINT_LIMITS constant
4. Add axis computation in _compute_axes()
5. Update _create_grid() if grid interacts with new joint

## 18.3 Modifying Grid Resolution
1. Change tile_size_x/y in configure_tileset_atlas()
2. Change texture_region_size_x/y to match new atlas dimensions
3. Adjust edit_tilemap() calls for new grid pattern
4. Update meter_grid.shader uniforms if alpha thresholds change

## 18.4 Adding New TCP/IP Commands
1. Extend DobotClient.send_motion_command() or add new function
2. Update _dobot_pose_from_arm() if frame convention changes
3. Add command sending in _command_real_arm() or new dedicated function
4. Update client auto-reconnect if needed

## 18.5 Changing Safe-Area Range
1. Modify clampf range in _on_safe_thickness_changed(): clampf(..., 0.0, new_max)
2. Update safe_area.gdshader thickness uniform range
3. Adjust UI button step size if desired
4. Update documentation thresholds

## 18.6 Debugging Tips
- Use get_godot_errors() after any script changes
- Print joint_angles via verbose export to monitor IK convergence
- Check _safe_thickness value in panel label (updates in real-time)
- Run with solve_enabled=false first to verify manual motion works
- Use run_scene with inputs to test specific flows

## 18.7 Version Control Notes
- All GDScript files use typed variables (var x: Type)
- class_name at top of each script for cross-referencing
- Constants use const UPPER_SNAKE_CASE
- Exported variables use @export with appropriate hints
- Scene (.tscn) files validated after edits
- Shaders (.gdshader) validated after creation/editing

#==============================================================================
# 19 - MEMORY FILES INDEX
#==============================================================================

## Project Memory Files (res:/memory/ or project root)
- dobot-rig-axes.md — Joint axis derivation principles
- openxr-blocks-subprocess.md — Headless Linux Zenity dialog block
- project-recreation-guide.md — This complete documentation (parts series)

## How to Use Memory Files
- memory_read(name): read a specific memory file
- memory_write(name, description, type, content): create/replace memory
- memory_delete(name): delete a memory file
- MEMORY.md: index of all memory files in project

## Current Memory File Contents Summary
- dobot-rig-axes.md: 1 file — why joint axes derived from geometry not local Z
- openxr-blocks-subprocess.md: 1 file — Zenity blocking on headless Linux
- project-recreation-guide.md: 1 file — complete project documentation (in parts)

## Memory File Maintenance
- Update when making significant architectural changes
- Delete if change proved unnecessary after re-evaluation
- Always update MEMORY.md index when adding/removing
- Keep descriptions specific enough to judge relevance without opening

#==============================================================================
# 20 - QUICK START CHECKLIST
#==============================================================================

## Immediate Setup (First Launch)
- [ ] Godot 4.7 project open, forward+ renderer
- [ ] dobot_cr3.fbx imported; note: world-axis-aligned (un-rigged)
- [ ] Scripts added: dobot_cr3.gd, manipulator_station.gd, screen_ui.gd, dobot_client.gd
- [ ] Shaders added: meter_grid.gdshader, floor_effect.gdshader, solid_sky.gdshader, scanned_mesh.gdshader, safe_area.gdshader
- [ ] Scene main.tscn composed with all nodes from node-by-node guide
- [ ] XR Origin configured; DesktopCamera for fallback
- [ ] Table: 1.4×0.9 m, dark gray, at y=0.71
- [ ] Target: cyan sphere, r=0.05m, at target position
- [ ] ArmGhost: dobot_cr3.fbx instance, solve_enabled=true, half-transparent
- [ ] ArmSolid: dobot_cr3.fbx instance, solve_enabled=false, timed motion model

## Script Configuration
- [ ] dobot_cr3.gd: verify joint chain references match FBX hierarchy
- [ ] dobot_cr3.gd: _compute_axes() called in _ready(); axes correct for rest pose
- [ ] manipulator_station.gd: _create_grid() called; configure_tileset_atlas() then edit_tilemap()
- [ ] manipulator_station.gd: _setup_obstacles() creates safe-area shells
- [ ] manipulator_station.gd: _setup_client() with correct host/ports
- [ ] screen_ui.gd: focus_mode = FOCUS_ALL; signals connected
- [ ] dobot_client.gd: host = "192.168.5.1"; ports 29999/30003

## Verification Tests
- [ ] Run scene; CCD IK should reach target within 0.005 m tolerance
- [ ] Drag target; ghost should follow via CCD
- [ ] Collision with obstacles: ghost turns red, APPROVE disabled
- [ ] APPROVE (shift+click or VR): copies ghost→solid via timed motion
- [ ] RESET: restores both arms + target to defaults
- [ ] Safe-area thickness UI: +/- changes shell shader + collision volume
- [ ] Device connection: panel shows CONNECTED/not connected status
- [ ] Timed motion: ~1.25 s for full pose, buttons disabled during move
- [ ] Desktop: mouse on screen → Shift=approve, otherwise reset
- [ ] Orbit camera: right-drag + wheel zoom works in desktop

## Deployment Checklist (Windows + Headset)
- [ ] xr/openxr/enabled = true in project settings
- [ ] xr/shaders/enabled = true in project settings
- [ ] Test with actual headset; VR controller inputs work
- [ ] Grip/grab joystick push-pull flow functional
- [ ] No blocking zenity dialog (was disabled during development)
- [ ] TCP/IP connection to real Dobot established (or mock mode)
- [ ] Grid visible at correct scale in VR view
- [ ] Rings glow correctly with XR environment
- [ ] Control panel readable at VR resolution
- [ ] All signals functioning as in desktop verification

## Known Constraints (Documented)
- [ ] Headless Linux: xr/openxr/enabled MUST stay false during Godot subprocess runs
- [ ] No real headset: VR hand interactions untested; desktop fallback works
- [ ] FBX: joint axes from geometry, not local Z (per dobot-rig-axes.md)
- [ ] TCP/IP: default host 192.168.5.1; real IP varies by deployment
- [ ] Safe-area: 0–60 mm range; beyond this collision may become too aggressive
- [ ] Orphan file: res://shaders/grid_shader.glsl.import cleared on next Godot launch
