extends Resource
class_name robot_connection_host

@export var port : int = -1:
	set(new_value):
		port = new_value
		_init()
var econn := ENetConnection.new()
var listen_thread :Thread = null

signal bound

class Peer:
	var hostname:String = ""
	var port:int = 0
	var ip_resolve_queue_index = -1
	var connection:ENetPacketPeer = null
	signal starting_connection
	signal connected
	signal disconnected
	signal packet_received(packet:PackedByteArray)

var peers : Array[Peer] = []
var peersmap : Dictionary[ENetPacketPeer, Peer] = {}

func find_peer_by_ip(ip) -> int:
	var index = peers.find_custom(func(peer:Peer):
		if peer.connection != null:
			return peer.connection.get_remote_address() == ip
		else:
			return false
	)
	return index

func find_peer_by_connection(connection:ENetPacketPeer) -> int:
	var index = peers.find_custom(func(peer:Peer):
		if peer.connection != null:
			return peer.connection == connection
		else:
			return false
	)
	return index

func process_packets() -> void:
	var data := econn.service(100)
	var eventType :ENetConnection.EventType = data[0]
	var netpeer :ENetPacketPeer = data[1]
	match eventType:
		ENetConnection.EventType.EVENT_CONNECT:
			print("Connection to %s:%d established" % [netpeer.get_remote_address(), netpeer.get_remote_port()])
			var peer : Peer = peersmap.get(netpeer)
			peer.connected.emit()
		ENetConnection.EventType.EVENT_RECEIVE:
			while netpeer.get_available_packet_count() > 0:
				decode_epacket(netpeer)
		ENetConnection.EventType.EVENT_DISCONNECT:
			var peer_idx = find_peer_by_connection(netpeer)
			var peer : Peer = peers[peer_idx]
			peersmap.erase(netpeer)
			peers.remove_at(peer_idx)
			printerr("Connection to %s:%d lost" % [netpeer.get_remote_address(), netpeer.get_remote_port()])
			peer.disconnected.emit()

func thread_function() -> void:
	while !is_queued_for_deletion():
		for peer in peers:
			if peer.ip_resolve_queue_index != -1:
				match IP.get_resolve_item_status(peer.ip_resolve_queue_index):
					IP.ResolverStatus.RESOLVER_STATUS_DONE:
						var ip = IP.get_resolve_item_address(peer.ip_resolve_queue_index)
						print("Host %s resolved to %s:%d" % [peer.hostname, ip, peer.port])
						IP.erase_resolve_item(peer.ip_resolve_queue_index)
						peer.ip_resolve_queue_index = -1
						peer.connection = connect_to_ip(ip, peer.port)
					IP.ResolverStatus.RESOLVER_STATUS_ERROR:
						peers.erase(peer)
						IP.erase_resolve_item(peer.ip_resolve_queue_index)
						printerr("IP resolution failed for %s:%d!" % [peer.hostname, peer.port])
		process_packets()

func _init() -> void:
	if port != -1:
		bind_host()
		if listen_thread == null:
			listen_thread = Thread.new()
			listen_thread.start(thread_function)

func _notification(what: int) -> void:
	if what == RefCounted.NOTIFICATION_PREDELETE:
		print("Destroying ENet Connection")
		listen_thread.wait_to_finish()
		econn.destroy()

func decode_epacket(netpeer : ENetPacketPeer):
	var packet_bytes := netpeer.get_packet()
	print_verbose("Got a packet with %d bytes from %s:%d" % [packet_bytes.size(), netpeer.get_remote_address(), netpeer.get_remote_port()])
	peersmap[netpeer].packet_received.emit(packet_bytes)
		
func send_packet(packet_bytes: PackedByteArray, peer: Peer):
	peer.connection.put_packet(packet_bytes)

func connect_to_host(hostname, port) -> Peer:
	var index := peers.find_custom(func(other_peer:Peer):
		return other_peer.hostname == hostname && other_peer.port == port
	)
	if index != -1:
		print("Peer %s already connected, returning..." % hostname)
		return peers[index]
	var peer := Peer.new()
	peer.hostname = hostname
	peer.port = port
	print("Adding %s to resolve queue..." % hostname)
	peer.ip_resolve_queue_index = IP.resolve_hostname_queue_item(hostname, IP.TYPE_ANY)
	peers.push_back(peer)
	return peer

func connect_to_ip(ip, port) -> ENetPacketPeer:
	var epeers := econn.get_peers()
	var epeer_idx := epeers.find_custom(func(epeer:ENetPacketPeer):
		return epeer.get_remote_address() == ip
	)
	if epeer_idx != -1:
		var epeer := epeers[epeer_idx]
		if epeer.get_remote_port() != port:
			print("Changing port for %s from %d to %d" % [ip, epeer.get_remote_port(), port])
			epeer.peer_disconnect()
			return econn.connect_to_host(ip, port, 1)
		print("Getting already created peer %s:%d" % [ip, port])
		return epeer
	else:
		print("Connecting to peer %s:%d" % [ip, port])
		var epeer := econn.connect_to_host(ip, port, 1)
		var peer : Peer = peers[find_peer_by_ip(ip)]
		peer.starting_connection.emit()
		peersmap[epeer] = peer
		return epeer

func bind_host():
	if econn.get_local_port() != port:
		econn.create_host_bound("0.0.0.0", port, 4, 1)
		bound.emit()
