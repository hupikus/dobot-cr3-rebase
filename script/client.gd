extends Node

@export var enabled: bool = false
@export var autoconnect: bool = true

@export var ip = "192.168.5.1"
@export var dashboard_port: int = 29999
@export var motion_port: int = 30003

@export var reconnect: bool = false
@export var reconnect_interval: float = 5.0
var reconnect_timer := 0.0

var dashboard := StreamPeerTCP.new()
var motion := StreamPeerTCP.new()
var connected := false


func _ready() -> void:
	if enabled and autoconnect:
		connect_client()

func enable() -> void:
	if not enabled:
		enabled = true
	if not connected:
		connect_client()

func disable() -> void:
	if not connected: return
	dashboard.disconnect_from_host()
	dashboard = StreamPeerTCP.new()
	motion.disconnect_from_host()
	motion = StreamPeerTCP.new()
	connected = false

func connect_client() -> void:
	dashboard.poll()
	dashboard.connect_to_host(ip, dashboard_port)
	
	motion.poll()
	motion.connect_to_host(ip, motion_port)
	
	reconnect_timer = 0.0
	
func _process(delta) -> void:
	if not enabled: return
	
	var dashboard_status = dashboard.get_status() == StreamPeerTCP.STATUS_CONNECTED
	var motion_status = motion.get_status() == StreamPeerTCP.STATUS_CONNECTED
	
	if dashboard_status != connected:
		connected = dashboard_status
		if connected:
			init_robot()
	
	if not connected:
		if reconnect:
			reconnect_timer += delta
			if reconnect_timer >= reconnect_interval:
				connect_client()
		return
	
	dump(dashboard)
	dump(motion)

func init_robot() -> void:
	send(dashboard, "EnableRobot()")
	send(dashboard, "SpeedFactor(50)")

func send(stream: StreamPeerTCP, command: String) -> void:
	if stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		dashboard.put_data((command + "\n").to_utf8_buffer())

func dump(stream: StreamPeerTCP) -> void:
	var n := stream.get_available_bytes()
	if n <= 0:
		return
	var result: Array = stream.get_partial_data(n)
	if result[0] != OK:
		return
	
	var buffer := (result[1] as PackedByteArray).get_string_from_utf8()
	print(buffer)
	# Send signal

func MovJ(pose: PackedFloat32Array) -> void:
	if pose.size() != 6:
		return
	send(motion, "MovJ(%.3f,%.3f,%.3f,%.3f,%.3f,%.3f)" % [
		pose[0], pose[1], pose[2], pose[3], pose[4], pose[5]])

func JointMovJ(pose: PackedFloat32Array) -> void:
	if pose.size() != 6:
		return
	send(motion, "JointMovJ(%.3f,%.3f,%.3f,%.3f,%.3f,%.3f)" % [
		pose[0], pose[1], pose[2], pose[3], pose[4], pose[5]])
