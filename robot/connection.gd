extends VBoxContainer

var ipaddr : String = ""
var peer := PacketPeerUDP.new()

const proto = preload("res://protoc/gd_esp.gd")

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
	while peer.get_available_packet_count() > 0:
		decode_packet()

func decode_packet():
	var packet = proto.gd_esp_packet.new()
	packet.from_bytes(peer.get_packet())
	match packet._data_case:
		proto.gd_esp_packet.DataCase.PID:
			pass
		proto.gd_esp_packet.DataCase.POS:
			pass
		_:
			pass

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
	var bytes = move_msg.to_bytes()
	print("Sending position packet %s" % bytes.hex_encode())
	peer.put_packet(bytes)

func _on_connect_toggled(toggled_on: bool) -> void:
	pass

func _on_port_value_changed(value: float) -> void:
	peer.bind(get_dest_port())
	peer.set_dest_address(get_dest_address(), get_dest_port())

func _on_address_text_submitted(new_text: String) -> void:
	ipaddr = IP.resolve_hostname(new_text, IP.TYPE_ANY)
	print("Converted %s to IP address %s" % [new_text, ipaddr])
	peer.set_dest_address(get_dest_address(), get_dest_port())
