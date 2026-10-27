extends Resource
class_name robot_connection_client

@export var hostname :String = "":
	set(new_hostname):
		hostname = new_hostname
		_init()
@export var port :int = -1:
	set(new_port):
		port = new_port
		_init()
@export var host : robot_connection_host:
	set(new_host):
		host = new_host
		_init()
const ptype = preload("res://robot/connection_host.gd")
var peer :ptype.Peer = null

const proto = preload("res://protoc/gd_esp.gd")
var callbacks : Dictionary[proto.gd_esp_packet.DataCase, Array]= {}

func on_disconnect():
	print("Connecting signals...")
	peer = host.connect_to_host(hostname, port)
	peer.disconnected.connect(on_disconnect)
	peer.packet_received.connect(on_packet)

func on_packet(packet_bytes: PackedByteArray):
	var packet = proto.esp_gd_packet.new()
	packet.from_bytes(packet_bytes)
	var callbacks = callbacks.get(packet.get_data_case())
	if callbacks != null:
		for callback in callbacks:
			callback.call_deferred(packet)
	else:
		print("Missing callback for data case %d" % packet.get_data_case())

func _init() -> void:
	if host != null && port != -1 && hostname != "":
		on_disconnect()

func register_callback(callback : Callable, type: proto.esp_gd_packet.DataCase):
	(callbacks.get_or_add(type, []) as Array[Callable]).push_back(callback)

func send_packet(packet: proto.gd_esp_packet):
	var packet_bytes = packet.to_bytes()
	host.send_packet(packet_bytes, peer)
