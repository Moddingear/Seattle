extends VBoxContainer

class_name robot_connection

var ipaddr : String = ""
@export var use_enet = true
var peer := PacketPeerUDP.new()
var econn : = ENetConnection.new()
var epeer : ENetPacketPeer = null

const proto = preload("res://protoc/gd_esp.gd")

signal OnReceivedPacket(packet:proto.gd_esp_packet)

var callbacks : Dictionary[proto.gd_esp_packet.DataCase, Callable]= {}

func get_dest_address() -> String:
	return ipaddr

func get_dest_port() -> int:
	return %port.value

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_on_address_text_submitted(%address.text)
	_on_port_value_changed(%port.value)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_visible_in_tree():
		send_move_frame()
	if use_enet:
		var data = econn.service()
		var eventType :ENetConnection.EventType = data[0]
		var netpeer :ENetPacketPeer = data[1]
		if eventType == ENetConnection.EventType.EVENT_RECEIVE:
			while netpeer.get_available_packet_count() > 0:
				decode_epacket(netpeer)
		if eventType == ENetConnection.EventType.EVENT_DISCONNECT:
			if netpeer == epeer:
				print("Connection lost, attempting reconnection...")
				epeer = null
				reconnect()
	else:
		while peer.get_available_packet_count() > 0:
			decode_packet()

func _exit_tree() -> void:
	if use_enet:
		print("Destroying ENet Connection")
		econn.destroy()

func decode_packet():
	var packet = proto.gd_esp_packet.new()
	var packet_bytes = peer.get_packet()
	print("Got a packet with %d bytes" % packet_bytes.size())
	packet.from_bytes(packet_bytes)
	var callback = callbacks.get(packet.get_data_case())
	if callback != null:
		callback.call(packet)
	else:
		print("Missing callback for data case %d" % packet.get_data_case())

func decode_epacket(netpeer : ENetPacketPeer):
	var packet = proto.gd_esp_packet.new()
	var packet_bytes = netpeer.get_packet()
	print("Got a packet with %d bytes" % packet_bytes.size())
	packet.from_bytes(packet_bytes)
	var callback = callbacks.get(packet.get_data_case())
	if callback != null:
		callback.call(packet)
	else:
		print("Missing callback for data case %d" % packet.get_data_case())
		
func send_packet(packet: proto.gd_esp_packet):
	var packet_bytes = packet.to_bytes()
	if use_enet:
		epeer.put_packet(packet_bytes)
	else:
		peer.put_packet(packet_bytes)

func register_callback(callback, type: proto.gd_esp_packet.DataCase):
	callbacks[type] = callback

func send_move_frame():
	var move_x = Input.get_axis("left", "right")
	var move_z = Input.get_axis("forward", "back")
	var rot = Input.get_axis("look_x-", "look_x+")
	if move_x == 0 && move_z == 0 && rot == 0:
		return
	var move_msg = proto.gd_esp_packet.new()
	move_msg.new_pos()
	move_msg.get_pos().set_X(move_x)
	move_msg.get_pos().set_Y(move_z)
	move_msg.get_pos().set_R(rot)
	send_packet(move_msg)

func _on_connect_toggled(toggled_on: bool) -> void:
	pass

func reconnect():
	if use_enet:
		if econn.get_local_port() != get_dest_port():
			econn.create_host_bound("0.0.0.0", get_dest_port(), 4, 1)
		if epeer == null || epeer.get_remote_address() != get_dest_address() || epeer.get_remote_port() != get_dest_port():
			if epeer != null:
				epeer.peer_disconnect()
			#print("Connecting to %s:%d" % [get_dest_address(), get_dest_port()])
			epeer = econn.connect_to_host(get_dest_address(), get_dest_port(), 1)
	else:
		peer.bind(get_dest_port())
		peer.set_dest_address(get_dest_address(), get_dest_port())

func _on_port_value_changed(value: float) -> void:
	reconnect()

func _on_address_text_submitted(new_text: String) -> void:
	ipaddr = IP.resolve_hostname(new_text, IP.TYPE_ANY)
	print("Converted %s to IP address %s" % [new_text, ipaddr])
	reconnect()
