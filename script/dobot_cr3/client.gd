class_name DobotClient
extends Node

@export var enabled: bool = false
@export var autoconnect: bool = true

const ip = "192.168.5.1"
const dashboard_port: int = 29999
const motion_port: int = 30003
const feedback_port: int = 30004

@export var reconnect: bool = false
@export var reconnect_interval: float = 5.0
var reconnect_timer := 0.0

@onready var log = $"../Screens/Log"
@onready var ui = $"../Screens/Screen"

var dashboard := StreamPeerTCP.new()
var motion := StreamPeerTCP.new()
var feedback := StreamPeerTCP.new()

var open := false
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
	motion.disconnect_from_host()
	feedback.disconnect_from_host()
	connected = false
	open = false
	ui.refresh()

func connect_client() -> void:
	dashboard = StreamPeerTCP.new()
	dashboard.poll()
	dashboard.connect_to_host(ip, dashboard_port)
	
	motion = StreamPeerTCP.new()
	motion.poll()
	motion.connect_to_host(ip, motion_port)
	
	feedback = StreamPeerTCP.new()
	feedback.poll()
	feedback.connect_to_host(ip, feedback_port)
	
	reconnect_timer = 0.0
	
	open = true
	
func _process(delta) -> void:
	if not enabled: return
	if not open: return
	dashboard.poll()
	motion.poll()
	feedback.poll()
	var dashboard_status = dashboard.get_status() == StreamPeerTCP.STATUS_CONNECTED
	var motion_status = motion.get_status() == StreamPeerTCP.STATUS_CONNECTED
	
	if dashboard_status != connected:
		connected = dashboard_status
		ui.refresh()
		if connected:
			init_robot()
	
	if not connected:
		if reconnect:
			reconnect_timer += delta
			if reconnect_timer >= reconnect_interval:
				connect_client()
		return
	
	dump(dashboard)
	#dump(motion)
	#dump(feedback)

func init_robot() -> void:
	send(dashboard, "EnableRobot()")
	send(dashboard, "SpeedFactor(20)")
	JointMovJ([0, 0, 0, 0, 0, 0])

func send(stream: StreamPeerTCP, command: String) -> void:
	if stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		dashboard.put_data((command + "\n").to_utf8_buffer())

func dump(stream: StreamPeerTCP) -> void:
	if not open:
		print("STREAMS ARE NOT OPEN")
		return
	var n := stream.get_available_bytes()
	if n <= 0:
		return
	var result: Array = stream.get_partial_data(n)
	if result[0] != OK:
		return
	
	var buffer := (result[1] as PackedByteArray).get_string_from_utf8()
	log.push_message(buffer)
	print(buffer)

func MovJ(pose: PackedFloat32Array) -> void:
	if pose.size() != 6:
		return
	send(motion, "MovJ(%.3f,%.3f,%.3f,%.3f,%.3f,%.3f)" % [
		pose[0], pose[1], pose[2], -pose[3], pose[4], pose[5]])

func JointMovJ(pose: PackedFloat32Array) -> void:
	if pose.size() != 6:
		return
	send(motion, "JointMovJ(%.3f,%.3f,%.3f,%.3f,%.3f,%.3f)" % [
		pose[0], pose[1], pose[2], -pose[3], pose[4], pose[5]])
