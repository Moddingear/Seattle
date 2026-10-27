extends VBoxContainer

class_name NetworkViewer

const proto = preload("res://protoc/gd_esp.gd")
@export var connection : robot_connection_client

const actuator = preload("res://robot/actuator.tscn")
var actuators :Dictionary[int, Actuator] = {}

func _ready() -> void:
	connection.register_callback(on_network_map, proto.esp_gd_packet.DataCase.NETWORK_MAP)

func _on_refresh_pressed() -> void:
	var map_packet = proto.gd_esp_packet.new();
	map_packet.new_network_map_request()
	connection.send_packet(map_packet)

func on_network_map(packet: proto.esp_gd_packet):
	var nmap := packet.get_network_map().get_discriminators()
	var received_discriminators = []
	for byte in nmap:
		received_discriminators.push_back(byte)
	var current_discriminators = actuators.keys()
	var new_discriminators = received_discriminators.filter(func(d): return d not in current_discriminators)
	var dropped_discriminators = current_discriminators.filter(func(d): return d not in received_discriminators)
	for d in dropped_discriminators:
		var ac = actuators[d]
		remove_child(ac)
		actuators.erase(d)
	for d in new_discriminators:
		var a = actuator.instantiate()
		(a as Actuator).connection = connection
		(a as Actuator).discriminator = d;
		add_child(a)
		actuators[d] = a

func on_uid(packet: proto.esp_gd_packet):
	actuators[packet.get_motor_identification().get_discriminator()].uid = packet.get_motor_identification().get_name()
