extends Control
class_name robot_connection_manager

const proto = preload("res://protoc/gd_esp.gd")
@export var connection : robot_connection_client

var ipaddr_resolution_queue_id : int = -1
var ipaddr : String = ""

func get_dest_address() -> String:
	return ipaddr

func get_dest_port() -> int:
	return %port.value

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ipaddr_resolution_queue_id = IP.resolve_hostname_queue_item(%address.text, IP.TYPE_ANY)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if is_visible_in_tree():
		send_move_frame()

func send_move_frame():
	var move = Input.get_vector("left", "right", "forward", "back")
	var rot = Input.get_axis("look_x-", "look_x+")
	if move.length() == 0 && rot == 0:
		return
	var move_msg = proto.gd_esp_packet.new()
	move_msg.new_pos()
	move_msg.get_pos().set_X(move.x)
	move_msg.get_pos().set_Y(move.y)
	move_msg.get_pos().set_R(rot)
	print("Sending move frame %f %f %f" % [move.x, move.y, rot])
	connection.send_packet(move_msg)

func _on_port_value_changed(_value: float) -> void:
	pass

func _on_address_text_submitted(_new_text: String) -> void:
	pass
