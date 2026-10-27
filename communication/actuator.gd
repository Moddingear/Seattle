extends Control

class_name Actuator

const proto = preload("res://protoc/gd_esp.gd")
var connection : robot_connection_client = null
const pid_scene = preload("res://communication/pid_setting.tscn")

var pids : Dictionary[proto.PIDData.Loop, PIDSetting] = {}

@export var discriminator : int = 0:
	set(new_value):
		%Discriminator.text = str(new_value)
		discriminator = new_value
@export var uid : String = "":
	set(new_value):
		%UIDButton.hide()
		%UIDText.show()
		%UIDText.text = new_value
		uid = new_value

func _ready() -> void:
	%PIDs.visible = %PIDEnable.button_pressed
	connection.register_callback(on_uid, proto.esp_gd_packet.DataCase.MOTOR_IDENTIFICATION)
	connection.register_callback(on_pid, proto.esp_gd_packet.DataCase.PID)
	for key in proto.PIDData.Loop.keys():
		if key == "None":
			continue
		var scene = pid_scene.instantiate()
		scene.parent = self
		scene.name = key
		%PIDs.add_child(scene, true)
		pids[proto.PIDData.Loop[key]] = scene
		

func _on_uid_button_pressed() -> void:
	var uid_packet = proto.gd_esp_packet.new()
	uid_packet.new_identify_request()
	uid_packet.get_identify_request().set_discriminator(discriminator)
	connection.send_packet(uid_packet)

func on_uid(packet: proto.esp_gd_packet):
	if packet.get_motor_identification().get_discriminator() == discriminator:
		uid = packet.get_motor_identification().get_name()

func _on_jump_bootloader_pressed() -> void:
	var bl_packet = proto.gd_esp_packet.new()
	bl_packet.new_bootloader_jump()
	bl_packet.get_bootloader_jump().set_discriminator(discriminator)
	connection.send_packet(bl_packet)

func on_get_pid(loop: proto.PIDData.Loop):
	var packet = proto.gd_esp_packet.new()
	var pid = packet.new_PID()
	pid.set_loop_id(loop)
	pid.set_motor_index(discriminator)
	connection.send_packet(packet)

func on_set_pid(loop: proto.PIDData.Loop, P, I, D, limit, ramp, lowpass):
	var packet = proto.gd_esp_packet.new()
	var pid = packet.new_PID()
	pid.set_loop_id(loop)
	pid.set_motor_index(discriminator)
	var settings = pid.new_settings()
	settings.set_P(P)
	settings.set_I(I)
	settings.set_D(D)
	settings.set_limit(limit)
	settings.set_ramp(ramp)
	settings.set_low_pass(lowpass)
	connection.send_packet(packet)

func on_pid(packet: proto.esp_gd_packet):
	var pid = packet.get_PID()
	var scene = pids.get(pid.get_loop_id())
	(scene as PIDSetting).on_data(pid)

func _on_pid_enable_toggled(toggled_on: bool) -> void:
	%PIDs.visible = toggled_on
