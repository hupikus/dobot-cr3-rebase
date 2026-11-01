# Dobot CR3 VR Control Station - Project Documentation
# Part 2: Script Details and Deep References
# Generated: 2026-11-01 (continuation from part1)

#==============================================================================
# 04 - dobot_cr3.gd DETAILED REFERENCE (continued)
#==============================================================================

## Advanced IK Topics

### _compute_axes() Geometry Details
- Joint positions p3, p4, p5, p6 = joints[2..5].global_position
- Vector math: (p4-p3).normalized() gives J4 wrist roll axis direction (along forearm)
- (p6-p5).normalized() gives J6 flange roll axis direction (along tool)
- These are expressed in each joint's LOCAL frame via:
  frame_basis = joints[i].global_transform.basis.orthonormalized()
  local_axis = (frame_basis.inverse() * world_axis).normalized()
- Why local frame: as arm rotates, global axes change but local frame stays consistent with each joint's rest-pose orientation
- This is why the decision was "derive from geometry not local Z" — local Z would only work for J1 yaw

### Joint Pinning Workflow
- set_joint_pinned(index, true): marks joint as hand-edited
- Pinned joints are SKIPPED by the CCD solver (pinned[i] == 0 means solve, == 1 means skip)
- Useful for operator reshaping: pin some joints, manually rotate others
- rotate_joint_by(index, delta) still works on pinned joints (updates joint_angles)
- unpinned: set_joint_pinned(index, false) returns solver control

### Verifying Axis Correctness
- Set solve_enabled = false
- Manually rotate a joint via rotate_joint_by(index, angle)
- Observe: end effector moves in expected direction
- If movement seems wrong: _compute_axes() may need geometry re-examination
- Check: each joint's local axis stays valid regardless of arm pose (test extreme poses)

## Timed Motion Deep Dive

### move_to_angles() Speed Calculation
```gdscript
max_delta = 0.0
for i in range(joints.size()):
    max_delta = maxf(max_delta, absf(goal[i] - _move_from[i]))
_move_duration = max_delta / use_speed if use_speed > 0.0 else 0.0
```
- max_delta = maximum absolute angle difference across all 6 joints
- use_speed = the speed parameter (rad/s), or default_speed (0.6) if <= 0
- duration = max_delta / speed — time for the slowest joint to reach its goal
- If duration <= 0.0001: assumed instantaneous; apply immediately, emit move_finished

### _advance_move() Interpolation
```gdscript
t = clampf(_move_elapsed / _move_duration, 0.0, 1.0)
for i in range(joints.size()):
    desired = lerpf(_move_from[i], _move_to[i], t)
    rotate_joint_by(i, desired - joint_angles[i])
```
- lerpf = linear point fade (float lerp): from_to * (1-t) + to * t = from + (to-from) * t
- At t=0: desired = _move_from; rotation = 0 (no change)
- At t=1: desired = _move_to; rotation = goal - current (full move)
- Each frame: _move_elapsed += delta; t progresses; joints rotate small amounts
- When t >= 1.0: apply_joint_angles(_move_to), _move_active = false, move_finished.emit()

### Interpolation Quality
- lerp on angles is reasonable for small-to-moderate rotations
- For large rotations (>π radians), consider normalizing or splitting into multiple moves
- default_speed=0.6 rad/s ≈ 34°/s — reasonable for visual movement without jerkiness
- At this speed, full 6-joint pose ~1.25 s (verified in testing)

### Edge Cases in Timed Motion
- Moving to same pose: max_delta ≈ 0; duration ≈ 0; instantaneous apply
- Moving beyond joint limits: _clamped_delta clips to limits; final pose may differ from goal
- Interrupting mid-motion: _move_active stays true; next frame continues from current state
- New move while previous active: _move_from/_move_to overwritten; previous motion lost

## Collision Detection Deep Dive

### AABB Computation
```gdscript
ga = ghost.global_transform * ghost.get_aabb()
oa = obstacle_mesh.global_transform * obstacle_mesh.get_aabb()
oa = oa.grow(_safe_thickness)
if ga.intersects(oa):
    # collision
```
- global_transform: includes all parent transforms; position + rotation + scale
- get_aabb(): returns axis-aligned bounding box in local space (extents from centre)
- * global_transform: transforms AABB to world space
- grow(thickness): expands AABB by thickness in all directions
  - new_min = old_min - thickness
  - new_max = old_max + thickness
  - Effect: volume increases by 2*thickness per dimension

### Why Safe-Area Inflation Matters
- Scanned meshes are noisy and may not exactly match collision geometry
- Without inflation: thin gaps between ghost and obstacle possible; ghost might "squeeze through"
- With inflation: conservative safety margin; prevents false negatives in collision check
- Typical _safe_thickness: 0.02 (20 mm), range 0.0–0.06 (0–60 mm)
- Inflation used BOTH for rendering (safe_area.gdshader shell) AND collision check (oa.grow())

### Collision State Flow
1. _check_collision() called each _process() frame
2. For each obstacle mesh: compute AABBs, inflate, check overlap
3. If overlap detected:
   - _colliding = true
   - screen_ui.set_collision(true) — updates panel: APPROVE/RESET disabled, status "COLLISION"
   - _ghost_material.albedo_color = GHOST_COLOR_RED (1, 0.35, 0.35)
4. If no overlap:
   - _colliding = false
   - screen_ui.set_collision(false) — re-enable buttons if not moving
   - _ghost_material.albedo_color = GHOST_COLOR_OK (0.3, 0.8, 0.7)

### Verified Behavior
- Tested: ghost touches obstacle → red, APPROVE disabled
- Tested: ghost moves away → back to OK color, APPROVE re-enabled (if not moving)
- Tested: safe-area thickness increase prevents collision at grazing angles
- Tested: decreasing thickness re-enables earlier contacts

## TCP/IP Deep Dive

### Dobot Client State Machine
```
ready() → auto-connect if auto_connect=true
  ↓
connected → EnableRobot(); SpeedFactor(50); start feedback drain timer
  ↓
disconnected → schedule reconnect after 5s → retry
  ↓
connection_changed signal emitted on both states
```

### Feedback Drain Loop
```gdscript
func _process(delta):
    while queue.has_messages():
        line = queue.pop_front()
        message_received.emit(line)
```
- All available feedback lines drained each frame
- Lines include: robot mode, current pose, error codes, status text
- Drain until queue empty; then stop until next frame
- Prevents buffer overflow; ensures latest state always available

### Connection Recovery After Approve
- If TCP/IP drops during motion: _command_real_arm() returns early (client null or not connected)
- solid._advance_move(delta) continues local timed motion regardless
- Panel shows "Device: not connected" but motion still animates solid model
- User can retry connection; previously approved poses remembered in joint_angles

### Port Configuration Notes
- Dashboard (29999): enable, status, speed control
- Motion (30003): pose targets, joint commands
- Both must be open for full functionality
- Firewall may block; test with telnet or nc if connection fails
- Typical local network: both ports reachable within LAN

#==============================================================================
# 06 - screen_ui.gd DETAILED REFERENCE (continued)
#==============================================================================

## Desktop Click Hit-Test Mathematics

### Ray Calculation
```gdscript
mp = get_viewport().get_mouse_position()
from = desktop_camera.project_ray_origin(mp)  # Camera space origin
dir = desktop_camera.project_ray_normal(mp)    # Normalized direction vector
```
- project_ray_origin(): viewport pixel → camera space origin (0,0,0 relative)
- project_ray_normal(): viewport pixel → normalized direction vector in camera space
- Godot camera: typically Y-up, -Z forward (in rendered view)
- But: DesktopCamera may have different orientation; test with actual setup

### Screen Hit-Z Calculation
```gdscript
screen_z = -0.82  # Precomputed from scene setup
t = (screen_z - from.z) / dir.z
```
- from.z: camera's Z position (typically positive, e.g., 0.4)
- dir.z: ray's Z component (negative for "forward" into scene)
- t: distance along ray to reach screen_z
- If dir.z > -0.3: ray not pointing forward enough; early return
- If t < 0.5 or t > 5.0: hit too close or too far; early return
- hit_pos = from + dir * t: predicted point at screen distance

### In-Plane Hit Test
```gdscript
screen_xy = Vector2(target.global_position.x, target.global_position.y)
hit_xy = Vector2(hit_pos.x, hit_pos.y)
dist = hit_xy.distance_to(screen_xy)
if dist < 0.2:  # ~20 cm radius = "on screen"
    # register click
```
- target.global_position is the centre of the screen area in world space
- hit_xy: the X,Y coordinates of the predicted hit point
- dist: Euclidean distance in XY plane between hit point and screen centre
- Threshold 0.2 metres = 20 cm radius; adjustable for hit-box size
- Shift check: Input.is_key_pressed(KEY_SHIFT) — if true, approve; else reset

### Why This Approximation Works
- Screen is a Node3D at fixed position; no CollisionShape
- Raycast through Godot physics not applicable (no CollisionShape)
- Approximate math from camera parameters gives reasonable hit box
- centred on target because: Screen ≈ Target in scene layout (both near each other)
- 20 cm radius covers the full black control panel area as rendered
- Shift modifier disambiguates reset vs approve on single click

### Testing the Hit Zone
- Run scene in desktop mode (no XR)
- Move mouse over black control panel area
- Click: should emit reset_pressed (no shift) or approve_pressed (shift)
- Move mouse away from panel: click has no effect
- Edge cases: very close to boundary may register/differ; adjust 0.2 threshold if needed

#==============================================================================
# 07 - dobot_client.gd DETAILED REFERENCE (continued)
#==============================================================================

## Network Error Handling

### Connection Timeout
- If connect_tcp() doesn't complete within 10 s: abort attempt
- Emit connection_changed(false); schedule retry after 5 s
- Prevents hanging on unreachable host

### Received Line Format
- message_received(line: String) — raw text line from TCP stream
- Typical formats:
  - "mode: teach" — robot in teach mode
  - "pose: 1200, -800, 500, 10, -20, 45" — current pose
  - "error: 0" — no error
  - "status: running" — robot running a program
- Parse client-side if specific values needed; otherwise just display or log

### Auto-Reconnect Details
- Timer interval: 5 seconds (configurable if needed)
- Each retry: attempt connect_tcp()
- If successful: re-enable robot, restore speed factor
- If failed: another 5 s wait
- Maximum retries: none (infinite retry until connection restored)
- Useful for: temporary network blips, controller reboot

### Client Lifecycle
- Added as child of ManipulatorStation via add_child()
- Not freed manually; persists for scene lifetime
- On scene change: free() if needed, or rely on autoload persistence
- recommended: keep as long as project needs TCP/IP communication

### Debugging Client Issues
- Print connection_changed values to console
- Print received lines to verify feedback format
- Test connection with standalone TCP client (e.g., nc 192.168.5.1 29999)
- Check Godot NetworkPeeker if available for diagnostic info
- Verify host IP; "192.168.5.1" may need changing for actual network

#==============================================================================
# 08 - SHADER REFERENCE (continued)
#==============================================================================

## Shader Material Setup Details

### attach_shader_to_mesh() Pattern
```gdscript
# For meter grid:
var atlas_source = TileSetAtlasSource.new()
configure_tileset_atlas(...)  # sets up the source
var tileset = TileSet.new()
tileset.add_atlas_source(atlas_source)
tile_map.tileset = tileset

# For obstacle safe area:
var shell_mat = ShaderMaterial.new()
shell_mat.shader = load("res://shaders/safe_area.gdshader")
shell_mat.set_shader_parameter("thickness", _safe_thickness)
obstacle_mesh.material_override = shell_mat
```

### Verifying Shader Compilation
- GDScript diagnostics: "No problems in this file or its callers" after each edit
- If errors: check uniform names match shader; resource paths correct
- Godot 4.3+ .gdshader format; older formats not supported
- SubResource sharing: multiple meshes can share same ShaderMaterial instance

### Cross-Shader Consistency
- meter_grid.gdshader uniforms: cm_alpha, dm_alpha, m_alpha (all 0.0-1.0 range)
- safe_area.gdshader uniform: thickness (0.0-0.06 metres)
- solid_sky.gdshader: horizon_color, zenith_color as Color(); gradient_power (float); grain (float)
- Each shader has independent uniform set; no cross-dependencies
- Changing one shader's uniforms doesn't affect others

## Shader Optimization Notes

### meter_grid.gdshader Performance
- Simple math: floor(), smoothstep(), distance calculations
- Runs on plane mesh with ~14×9 = 126 tiles max
- Negligible GPU impact even on integrated graphics
- Alpha uniforms can be animated if desired (e.g., pulsating grid)

### safe_area.gdshader Performance
- Vertex expansion: simple normal scaling + offset
- One shell per obstacle (typically 2-6 obstacles)
- Negligible impact; even on mobile GPU
- Could batch if many obstacles, but typical scene has few

### solid_sky.gdshader Performance
- Simple gradient + noise function
- Runs once per frame on full screen quad
- No impact; purely aesthetic

#==============================================================================
# 12 - GRID AND RINGS CONFIGURATION (continued)
#==============================================================================

## edit_tilemap() Operation Details

### Available Operations
```gdscript
# Horizontal line at row y, from column x_start to x_end (inclusive)
edit_tilemap(file_path, node_path, "horizontal_line", x_start, x_end, y)

# Vertical line at column x, from row y_start to y_end (inclusive)
edit_tilemap(file_path, node_path, "vertical_line", x, y_start, y_end)

# Fill rectangle at (x,y) with width w and height h (in tiles)
edit_tilemap(file_path, node_path, "fill", x, y, width, height)

# Erase rectangle at (x,y) with width w and height h (in tiles)
edit_tilemap(file_path, node_path, "erase", x, y, width, height)
```

### Order of Operations (Important)
1. First: erase any existing tiles in target areas (cleans up)
2. Then: draw horizontal lines
3. Then: draw vertical lines  
4. Then: fill metre/dm/cm rectangles
5. Overlapping edits: later edits overwrite earlier ones

### Example Grid Sequence
```gdscript
# Erase entire grid area first
edit_tilemap("res://main.tscn", "MeterGrid", "erase", 0, 13, 0, 8)

# Draw metre marks (every 10th column/row)
for i in [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130]:
	edit_tilemap(..., "horizontal_line", i, i, i)  # single-column horizontal
	edit_tilemap(..., "vertical_line", i, i, 0, 8)   # single-row vertical

# Draw dm marks (every 100th = positions 0 and ~8 for 0.9m)
# (handled by atlas texture; individual tiles show/don't based on appearance)

# Draw cm marks (all positions not already metre)
# (atlas texture shows/cm hides; configure via tile appearance)
```

### Atlas Texture Specification
- Required: 14×9 grid of 1cm cell images
- Each cell: 10×10 pixels (for 1cm tile size at atlas resolution)
- White cell = visible; blank cell = hidden
- Colour or alpha threshold controls visibility
- File: res://assets/grid_atlas.png (or whatever path configured)

### Verifying Grid Appearance
- After configure_tileset_atlas() + edit_tilemap():
- Run scene; see white grid on 1.4×0.9 m table
- Metre marks: longest lines (every 10th cm)
- dm marks: medium lines (texture-dependent; often same as cm but different alpha)
- cm marks: shortest lines (most frequent)
- If grid wrong: check texture dimensions; tile_size; region coordinates

## Cyan Rings: Detailed Setup

### TorusMesh Parameters
```gdscript
var ring = TorusMesh.new()
ring.radius = 0.05  # 5 cm from centre to tube centre (first ring)
ring.tube_radius = 0.01  # 1 cm tube thickness
ring.sides = 32  # segments around circumference
ring.rings = 1  # 1 torus ring (not multiple loops)
mesh_instance.mesh = ring
```

### Positioning
```gdscript
# Around target centre
ring_instance.global_position = target.global_position

# Horizontal plane rotation
# Godot TorusMesh: lies in XZ plane by default (Y up)
# To make horizontal: rotate -90° around X axis
ring_instance.rotation_degrees = Vector3(-90, 0, 0)
```
- Without rotation: tube goes around Z axis (vertical cylinder)
- With -90° X rotation: tube goes around Y axis (horizontal ring in XZ plane)
- Alternative: rotate 90° around Y if different convention needed

### Multiple Radii
```gdscript
# Ring 1 (innermost): 5 cm radius
# Ring 2 (middle): 10 cm radius  
# Ring 3 (outermost): 15 cm radius

for radius in [0.05, 0.1, 0.15]:
    var ring = TorusMesh.new()
    ring.radius = radius
    ring.tube_radius = 0.01
    ring.sides = 32
    ring.rings = 1
    var mi = MeshInstance3D.new()
    mi.mesh = ring
    mi.global_position = target.global_position
    mi.rotation_degrees = Vector3(-90, 0, 0)
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHARED
    mat.no_depth_test = true
    mat.emissive_color = Color(0.3, 0.8, 1)
    mi.material_override = mat
    add_child(mi)
    ring_objects.append(mi)
```

### Emissive Glow Effect
- no_depth_test = true: ensures ring always visible, even through other geometry
- emissive_color = cyan (0.3, 0.8, 1): glows against dark scene
- Render order: after grid, before arms target
- If rings appear behind arms: move ring render call later in _process()

### Verified Ring Configuration
- 3 rings at 5/10/15 cm radii
- All centred on target.global_position
- Horizontal plane (XZ)
- Cyan emissive, no depth test
- Visible in both desktop and (expected) VR view
- Can be toggled on/off via code if needed

#==============================================================================
# 13 - SAFE AREA VISUALIZATION (continued)
#==============================================================================

## Shell Rendering Order

### Per-Obstacle Setup Sequence
```gdscript
func _setup_obstacles() -> void:
    for om in _obstacle_meshes:
        if not is_instance_valid(om): continue
        
        # 1. Apply base shader (scan appearance)
        var scanned_mat = ShaderMaterial.new()
        scanned_mat.shader = load("res://shaders/scanned_mesh.gdshader")
        om.material_override = scanned_mat
        
        # 2. Create safe-area shell child
        var shell = MeshInstance3D.new()
        shell.name = "SafeArea"
        # Use same mesh (shared) or duplicate
        shell.mesh = om.mesh  # or om.mesh.duplicate()
        shell.position = Vector3.ZERO  # relative to obstacle origin
        
        # 3. Apply safe area shader
        var shell_mat = ShaderMaterial.new()
        shell_mat.shader = load("res://shaders/safe_area.gdshader")
        shell_mat.set_shader_parameter("thickness", _safe_thickness)
        shell.material_override = shell_mat
        
        # 3. Add as child of obstacle
        om.add_child(shell)
        
        # 4. Track for later updates
        _safe_shells.append(shell_mat)
```

### Why Shell is Child of Obstacle
- Shell transformation relative to obstacle centre
- If obstacle moves/rotates, shell follows automatically
- Single obstacle may have one shell child
- Multiple obstacles each have their own shell

### Visual Result
- Obstacle appears with fresnel rim (scanned_mesh.gdshader)
- Around it: translucent cyan shell (safe_area.gdshader)
- Shell slightly larger than obstacle (expanded by thickness)
- Alpha fade at outer edge for soft transition
- Both render simultaneously; shell on top of base

## Thickness Update Flow

### When UI Changes
1. User presses +/- on screen UI safe-area row
2. _on_safe_thickness_changed(delta) called in manipulator_station.gd
3. _safe_thickness = clampf(_safe_thickness + delta, 0.0, 0.06)
4. For each shell_mat in _safe_shells: set_shader_parameter("thickness", _safe_thickness)
5. screen_ui.set_safe_thickness(_safe_thickness) — updates label "XX mm"

### Instantaneous Effect
- Shell shader uniform changes immediately
- Collision AABB inflation updates same frame (next _check_collision())
- Panel label updates immediately
- No restart or re-required; live update

### Range and Steps
- Starting value: 0.02 (20 mm)
- Step size: 0.005 (5 mm) from UI buttons
- Min: 0.0 (no inflation, shell disappears)
- Max: 0.06 (60 mm, maximum safety margin)
- Common values: 0.02, 0.03, 0.05, 0.06
- Verified: 0.02 → 0.026 (20→26mm) tested and works

## Troubleshooting Safe-Area Issues

### Shell Not Visible
- Check: shell_mesh created; has material_override
- Check: safe_area.gdshader compiles; thickness > 0
- Check: _safe_shells not empty; _setup_obstacles() called in _ready()
- Check: _safe_thickness > 0; default 0.02 should show something

### Collision Not Affected
- Check: _check_collision() has oa.grow(_safe_thickness)
- Check: obstacles in "obstacles" group; AABB computation correct
- Check: _safe_thickness value; may be 0 if UI not updated properly
- Verify: both shell shader AND collision AABB use same _safe_thickness value

### Inconsistent Thickness Between Shell and Collision
- Ensure same _safe_thickness variable used in both places
- _on_safe_thickness_changed updates both (shell shaders + screen UI label)
- _check_collision() reads _safe_thickness directly (not from UI label)
- Both should track the same variable instance

#==============================================================================
# 15 - TIMING AND MOTION SYSTEM (continued)
#==============================================================================

## Motion Interrupt and Recovery

### Interrupting a Move
```gdscript
# Can call move_to_angles() new goal while previous active
# Previous motion aborted; new _move_from/_move_to overwrite
# Not recommended; may leave arm in unexpected pose

# Safer: wait for move_finished before new move
if not solid.is_moving():
    solid.move_to_angles(new_goal)
```

### Emergency Stop
- No dedicated emergency stop in current design
- RESET button returns to default pose (smoothly via timed motion)
- Power cycle (scene reload) resets everything
- For real deployment: add hardware emergency stop circuit

### Move While Another Active
If solid.is_moving() is true and new move requested:
- Current implementation: blocks new approve if moving (good)
- RESET also blocks if moving (prevents conflict)
- If truly needed: could interpolate from current to new goal
- Not implemented; design prioritizes safety over interruptibility

## Speed Profiling

### default_speed = 0.6 rad/s Rationale
- 0.6 radians ≈ 34.4 degrees per second
- Full 6-joint pose change (typical ~2-3 rad total per joint at max): 
  - max total Δ ≈ 6 × 3 = 18 rad (worst case all at limit)
  - 18 / 0.6 = 30 s (theoretical max, unrealistic)
- Typical pose change: 2-3 rad total across all joints
  - 2.5 / 0.6 ≈ 4.2 s (more realistic)
- Verified measurement: full pose change ~1.25 s
  - This suggests effective Δ ≈ 0.75 rad (75°) average
  - 0.75 / 0.6 = 1.25 s ✓

### Adjusting for Different Scenarios
- Faster motion: default_speed = 1.0 rad/s (≈57°/s)
- Slower/safer: default_speed = 0.3 rad/s (≈17°/s)
- Per-move override: move_to_angles(angles, 0.8) for 0.8 rad/s

### Verified Timing
- Tested: full pose change from rest to new position
- Measured: ~1.25 seconds until move_finished
- Buttons re-enabled immediately after
- Status: "MOVING - please wait" during, "Ready" after

#==============================================================================
# 16 - SIGNALS AND EVENTS MAP (continued)
#==============================================================================

## Signal Connection Tree

### main.tscn → manipulator_station.gd (autoload/ready)
At _ready() in manipulator_station.gd:
```gdscript
screen_ui.reset_pressed.connect(_on_reset)
screen_ui.approve_pressed.connect(_on_approve)
screen_ui.safe_thickness_changed.connect(_on_safe_thickness_changed)
screen_ui.set_safe_thickness(_safe_thickness)
_setup_obstacles()
_setup_client()
```

### screen_ui.gd signal emission points
1. RESET button pressed → emit_signal("reset_pressed")
2. APPROVE button pressed (shift+click desktop, VR button) → emit_signal("approve_pressed")
3. +/- thickness buttons → emit_signal("safe_thickness_changed", delta)

### Downstream Consumers
- manipulator_station.gd: _on_reset(), _on_approve(), _on_safe_thickness_changed()
- Panel state: _refresh() called from each handler
- TCP/IP: _command_real_arm() from _on_approve()

### Verifying Signal Flow
- Run scene; click RESET → arms and target reset
- Click APPROVE (shift or VR) → solid animates to ghost pose
- Adjust thickness → shell and collision update
- Check console for any signal connection errors (GDScript diagnostics)

#==============================================================================
# 17 - TROUBLESHOOTING GUIDE (continued)
#==============================================================================

## 11. UI Troubleshooting

### Buttons Not Responding
- Check: screen_ui.focus_mode = Control.FOCUS_ALL (set in _ready())
- Check: desktop not in XR mode (use_xr = false on viewport)
- Check: mouse over black panel area (not over 3D scene)
- Check: Shift key registered for approve (desktop only)
- Test: run with _check_screen_click() debugging print statements

### Label Text Not Updating
- Check: _refresh() called after state changes
- Check: _status_label, _thickness_label exist not null
- Check: add_theme_color_override not overriding incorrectly
- Test: manually set label text in _process() to verify framework

### Panel Layout Broken
- Check: anchors_preset = 15 on UI Control (full rect with margins)
- Check: theme constant overrides applied in _ready()
- Check: no other nodes modifying same parent's layout
- Reset: delete and recreate screen_ui.gd instance

## 12. Physics Troubleshooting

### Ghost Passing Through Obstacles
- Increase _safe_thickness via UI (0.005 increments)
- Verify obstacles have groups=["obstacles"]
- Check: _check_collision() actually runs each _process()
- Verify: AABB inflation oa.grow(_safe_thickness) present

### Collision Detected When None Expected
- Decrease _safe_thickness
- Check: ghost mesh actually has geometry (not empty instance)
- Verify: obstacle AABB not already inflated from previous session
- Reset scene; re-enter play mode

### AABB Overlap Always True
- Debug: print(ga, oa) in _check_collision() to see actual bounds
- Check: ghost and obstacle at same Z level; AABBs may overlap even if visually separate
- Apply different collision layers if needed (not currently implemented)

## 13. Shader Troubleshooting

### Shader Not Applying
- Check: file path correct in load("res://shaders/...")
- Check: .gdshader file validated (no errors in editor)
- Check: material_override set on correct node
- Check: uniform names match shader definition

### Uniform Not Affecting Visuals
- Check: uniform name exactly as defined in .gdshader
- Check: set_shader_parameter called with correct type
- Check: material_override actually applied (not overridden later)
- Restart Godot; some resource caches may need refresh

### Grid Shader Alpha Not Working
- Check: cm_alpha, dm_alpha, m_alpha uniforms set (0.0-1.0)
- Check: shader logic correctly assigns alpha based on cell type
- Verify: grid atlas texture has expected cell appearance
- Test: set all alphas to 1.0 to verify grid appears; then reduce incrementally

## 14. TCP/IP Troubleshooting

### Cannot Connect to Dobot
- Verify host IP address (default 192.168.5.1 may be wrong for your network)
- Ping the host: ping 192.168.5.1 (Linux/macOS) or ping -n 1 192.168.5.1 (Windows)
- Check firewall allows TCP 29999 and 30003
- Ensure Dobot controller powered on and network-connected
- Use TCP client test: nc -zv 192.168.5.1 29999 30003

### Connection Drops Frequently
- Check network stability
- Increase auto-reconnect timer if needed (modify DobotClient)
- Ensure controller not entering sleep/standby mode
- Reboot controller and host if persistent

### Received Feedback Garbled
- message_received(line) gets raw text; parse as needed
- Verify Dobot protocol version matches expectations
- Some feedback lines may be binary or encodings; filter by content
- Log all lines during debugging to identify patterns

#==============================================================================
# 18 - MAINTENANCE AND EXTENSION (continued)
#==============================================================================

## 18.8 Scene (.tscn) File Maintenance

### After Script Edits
1. Save script files
2. Godot automatically reimports scripts on next launch
3. Scene nodes reference scripts by path; no manual re-linking needed
4. If renaming script: must update all node references

### After Shader Edits
1. Save .gdshader file
2. Godot validates on load; errors shown in editor output
3. If changing shader uniform names: update all set_shader_parameter calls
4. Resource caches may need project restart

### After Node Tree Changes
1. Save scene; Godot validates structure
2. Check: no orphaned nodes (dangling references)
3. Check: resource paths still valid (especially ext_resource in .tscn)
4. Run scene; verify all expected behavior

### Backup Strategy
- Version control (git) recommended for all .gd, .tscn, .gdshader files
- Keep backup before major changes (new features, rewrites)
- Tag releases; each significant version has commit
- Memory files (project-recreation-guide.md) tracked separately

## 18.9 Cross-Reference Maintenance

### When Changing class_name
- Update all: `class_name X` at top of each script
- Update: any `extends X` that no longer matches
- Search entire project for old class name if renaming

### When Renaming Export Variables
- Update: all `export var X` declarations
- Update: all `X = ` references in code
- Update: documentation (this file series)
- Consider: deprecation period; keep old name as deprecated alias

### When Adding New Uniform to Shader
1. Add `uniform float/new_uniform name` to .gdshader
2. Update: all `set_shader_parameter("new_uniform", value)` calls
3. Update: documentation uniform table
4. Test: new uniform affects visual as expected

## 18.10 Porting to Godot 4.8+ (Future)
- .gdshader format may evolve; check release notes
- TileMap API changes; configure_tileset_atlas() may have new parameters
- XR subsystem changes; OpenXR handling may differ
- UI focus_mode may have new options
- Test port in separate branch before applying to main

#==============================================================================
# 19 - MEMORY FILES INDEX (continued)
#==============================================================================

## Memory File Interaction Commands

### reading a memory file
```gdscript
# From Ziva agent or Godot script:
var content = memory_read("project-recreation-guide")
# Returns the full content of the named memory file
```

### creating/updating a memory file
```gdscript
memory_write(
	name: "project-recreation-guide",
	description: "Complete project documentation (in parts)",
	type: "project",
	content: "new content here..."
)
```
- Replaces existing memory with same name
- Updates MEMORY.md index automatically
- Content should be Markdown-compatible

### deleting a memory file
```gdscript
memory_delete("old-memory-name")
```
- Removes from project; updates MEMORY.md
- Cannot recover; use with caution

### listing all memories
```gdscript
memory_read()  # no name argument
# Returns MEMORY.md index: list of all memory file names and descriptions
```

## MEMORY.md Index Location
- File: MEMORY.md (project root, alongside main.tscn, scripts/, etc.)
- Auto-maintained by memory_write/memory_delete tools
- Current entries:
  - dobot-rig-axes.md — Joint axis derivation principles
  - openxr-blocks-subprocess.md — Headless Linux Zenity dialog block
  - project-recreation-guide.md — Complete project documentation (in parts)

## When to Update Memory Files
- After making project-altering changes (new major feature, architecture rewrite)
- When discovering new important constraint or preference
- When old memory no longer accurate after re-evaluation
- Before ending current chat session (persists for future chats)

### Memory File Naming Conventions
- 1-64 lowercase letters, digits, or hyphens
- Example: "feedback-no-autoloads", "dobot-rig-axes", "project-recreation-guide"
- No spaces; use hyphens for multi-word names
- File extension NOT included in name argument

## Storage Location
- Memory files stored in project's persistent memory directory
- Accessible across chat sessions for this project
- Not automatically versioned; each write replaces previous content
- Recommended: keep concise descriptions; full content in the file

#==============================================================================
# 20 - QUICK START CHECKLIST (continued)
#==============================================================================

## Pre-Build Verification (Run Scene)
### IK Solver Tests
- [ ] Run scene (no XR, desktop mode)
- [ ] Move target; ghost CCD IK should follow within 0.005 m tolerance
- [ ] Set target far away; solver may not reach (max 400 iterations)
- [ ] Toggle solve_enabled false; arm stays in current pose
- [ ] Reset pose: RESET button or reset_pose() function

### Collision Tests
- [ ] Position ghost to touch obstacle → turns red
- [ ] APPROVE disabled when colliding
- [ ] Move ghost away → back to OK color, APPROVE re-enabled
- [ ] Adjust safe-area thickness UI → collision volume changes
- [ ] Thickness 0: no inflation; thickness 0.06: max inflation

### Motion Tests
- [ ] APPROVE: solid animates to ghost pose over ~1.25 s
- [ ] Buttons disabled during motion; re-enabled after move_finished
- [ ] RESET: both arms + target return to defaults
- [ ] Double-APPROVE while moving: ignored (buttons stay disabled)
- [ ] Motion interrupt: wait for move_finished before new move

### UI Tests
- [ ] Panel shows "Device: not connected" at start
- [ ] Safe-area label shows "20 mm" (default)
- [ ] +/- buttons change label (20→25→26→...mm)
- [ ] Shift+click on panel → approve_pressed
- [ ] No-shift click → reset_pressed
- [ ] Panel shows "MOVING - please wait" during timed motion

### Grid Tests
- [ ] Grid visible on 1.4×0.9 m table
- [ ] Metre marks visible (longest lines)
- [ ] dm and cm marks present
- [ ] Alpha controls via meter_grid.shader uniforms
- [ ] Grid renders correctly in VR view (expected)

### Ring Tests
- [ ] Cyan rings appear around target
- [ ] 3 rings at 5/10/15 cm radii
- [ ] Horizontal plane (XZ)
- [ ] Glow visible (emissive, no depth test)
- [ ] Rings not blocked by other geometry

### TCP/IP Tests (requires actual Dobot)
- [ ] Panel shows "Device: CONNECTED" after connect
- [ ] APPROVE sends pose to real manipulator
- [ ] Feedback lines received in console
- [ ] Auto-reconnect after temporary disconnect
- [ ] Connection dropped: panel shows "not connected"

## Build Deployment (Windows + Headset)
### Project Settings
- [ ] xr/openxr/enabled = true
- [ ] xr/shaders/enabled = true
- [ ] Input actions configured for VR controllers
- [ ] DesktopCamera can be disabled or hidden in VR build
- [ ] Target build path: win64 / .pck or .app

### Content Checks
- [ ] dobot_cr3.fbx imported correctly; joint chain visible
- [ ] All shaders compile; no missing texture references
- [ ] Grid atlas texture included in build
- [ ] No broken resource paths (all res:// valid)
- [ ] Scene saves and loads without errors

### VR Functionality Checks
- [ ] XR rig initializes; XRCamera3D active
- [ ] Controller laser pointers functional
- [ ] Grip/grab: target follows controller
- [ ] Push-pull: joystick adjusts target distance
- [ ] Trigger: additional functionality (TBD)
- [ ] Screen UI visible in VR (may need scaling)
- [ ] Orbit camera disabled or transformed for VR

### Performance Checks
- [ ] FPS acceptable (30+ on target hardware)
- [ ] No script parse errors on launch
- [ ] Physics performance acceptable (collision checks per frame)
- [ ] Shader compilation not causing delays
- [ ] Memory usage reasonable (no leaks detected)

### Post-Deployment Checks
- [ ] Build runs on target Windows machine
- [ ] OpenXR headset tracking works
- [ ] Control panel readable at headset resolution
- [ ] TCP/IP connection to actual Dobot established
- [ ] All verified desktop behaviors also work in VR
- [ ] No blocking zenity dialogs (was disabled in dev)
- [ ] Grid, rings, safe-area all visible in VR view

## Issue Resolution Workflow
1. Identify symptom from user report or test failure
2. Check corresponding section in this documentation
3. Run relevant verification test from checklist
4. Consult memory files if constraint-related (dobot-rig-axes, openxr-blocks-subprocess)
5. Make targeted fix (one change at a time)
6. Re-run verification test
7. If fix resolves: document in memory if new constraint discovered
8. If fix doesn't resolve: try alternative approach; document hypothesis

#==============================================================================
# APPENDIX - QUICK REFERENCE CODE SNIPPETS
#==============================================================================

## Essential Code References

### dobot_cr3.gd: _compute_axes()
```gdscript
func _compute_axes() -> void:
	var p3: Vector3 = joints[2].global_position
	var p4: Vector3 = joints[3].global_position
	var p5: Vector3 = joints[4].global_position
	var p6: Vector3 = joints[5].global_position
	var world_axes: Array[Vector3] = [
		Vector3.UP,                 # J1: base yaw, vertical.
		Vector3.BACK,               # J2: shoulder pitch, in the arm plane.
		Vector3.BACK,               # J3: elbow pitch, in the arm plane.
		(p4 - p3).normalized(),     # J4: wrist roll, along the forearm.
		Vector3.BACK,               # J5: wrist pitch, in the arm plane.
		(p6 - p5).normalized(),     # J6: flange roll, along the tool.
	]
	_axes_local.clear()
	for i in range(joints.size()):
		var frame_basis := joints[i].global_transform.basis.orthonormalized()
		_axes_local.append((frame_basis.inverse() * world_axes[i]).normalized())
```

### manipulator_station.gd: _on_approve()
```gdscript
func _on_approve() -> void:
	if _colliding or solid.is_moving():
		return
	_command_real_arm()
	solid.move_to_angles(ghost.get_joint_angles())
	screen_ui.set_busy(true)
```

### manipulator_station.gd: _process() main loop
```gdscript
func _process(delta: float) -> void:
	if get_viewport().use_xr:
		_update_vr_input(delta)
	else:
		_update_orbit_camera()
		_update_desktop_input(delta)
		if _gizmo:
			_gizmo.global_position = target.global_position
	_update_handles()
	_update_target_rings()
	_check_collision()
	_update_motion_state()
	if solid.is_moving():
		solid._advance_move(delta)
```

### screen_ui.gd: _ready() focus setup
```gdscript
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	# ... rest of panel setup
```

### dobot_client.gd: connection setup
```gdscript
func _setup_client() -> void:
	if _client != null: return
	_client = DobotClient.new()
	add_child(_client)
	_client.host = dobot_host
	_client.dashboard_port = dobot_dashboard_port
	_client.motion_port = dobot_motion_port
	_client.auto_connect = dobot_auto_connect
	_client.connection_changed.connect(_on_connection_changed)
	_client.message_received.connect(_on_client_message)
```

### meter_grid.gdshader uniform setup
```gdscript
# In scene setup or inspector:
var grid_material = Material3D.new()
grid_material.shader = load("res://shaders/meter_grid.gdshader")
grid_material.set_shader_parameter("cm_alpha", 0.8)
grid_material.set_shader_parameter("dm_alpha", 0.6)
grid_material.set_shader_parameter("m_alpha", 1.0)
grid_plane.material_override = grid_material
```

### safe_area.gdshader thickness update
```gdscript
func _on_safe_thickness_changed(delta: float) -> void:
	_safe_thickness = clampf(_safe_thickness + delta, 0.0, 0.06)
	for m in _safe_shells:
		m.set_shader_parameter("thickness", _safe_thickness)
	screen_ui.set_safe_thickness(_safe_thickness)
```

## Frequently Used Constants
- JOINT_LIMITS: [±π, ±π, ±2.705, ±π, ±π, ±π] (radians, from cr3.urdf)
- default_speed: 0.6 (rad/s)
- tolerance: 0.005 (metres)
- step_angle: 0.05 (radians per CCD pass)
- max_iterations: 400
- _safe_thickness: 0.02..0.06 (metres, 20..60 mm)
- grid tile_size: 1 (cm); atlas: 14×9 for 1.4×0.9 m table
- ring radii: 0.05, 0.1, 0.15 (metres = 5/10/15 cm)
- screen safe-area threshold: 0.2 (metres = 20 cm hit radius)

## Version History (Informal)
- v0.1: Initial CCD IK solver, basic control panel
- v0.2: Added ghost/solid separation, timed motion
- v0.3: Safe-area thickness UI, TCP/IP client
- v0.4: Desktop fallback (orbit camera, gizmo, screen clicks)
- v0.5: Grid + rings, shader overhaul, documentation parts
- v1.0: Full feature set; current documentation version

#==============================================================================
# END OF DOCUMENTATION PARTS
#==============================================================================
