extends VBoxContainer

class_name NetworkViewer

@onready var connection : robot_connection = $"../Connection"

const proto = preload("res://protoc/gd_esp.gd")
const actuator = preload("res://robot/actuator.tscn")

var actuators :Dictionary[int, Actuator] = {}

func _ready() -> void:
	connection.register_callback(on_network_map, proto.gd_esp_packet.DataCase.NETWORK_MAP)
	connection.register_callback(on_uid, proto.gd_esp_packet.DataCase.MOTOR_IDENTIFICATION)

func _on_refresh_pressed() -> void:
	var map_packet = proto.gd_esp_packet.new();
	map_packet.new_network_map()
	connection.send_packet(map_packet)

func _on_child_want_uid(discriminator:int):
	var uid_packet = proto.gd_esp_packet.new()
	uid_packet.new_motor_identification()
	uid_packet.get_motor_identification().set_discriminator(discriminator)
	connection.send_packet(uid_packet)

func _on_child_want_bootloader(discriminator:int):
	var bl_packet = proto.gd_esp_packet.new()
	bl_packet.new_bootloader_jump()
	bl_packet.get_bootloader_jump().set_discriminator(discriminator)
	connection.send_packet(bl_packet)

func on_network_map(packet: proto.gd_esp_packet):
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
		(a as Actuator).discriminator = d;
		add_child(a)
		actuators[d] = a

func on_uid(packet: proto.gd_esp_packet):
	actuators[packet.get_motor_identification().get_discriminator()].uid = packet.get_motor_identification().get_name()
