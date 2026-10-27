extends Control

class_name PIDSetting

const proto = preload("res://protoc/gd_esp.gd")
var parent : Actuator = null

func _on_get_pressed() -> void:
	parent.on_get_pid(proto.PIDData.Loop.get(name))

func on_data(packet: proto.PIDData):
	var settings = packet.get_settings()
	%P.value = settings.get_P()
	%I.value = settings.get_I()
	%D.value = settings.get_D()
	%Limit.value = settings.get_limit()
	%Ramp.value = settings.get_ramp()
	%LowPass.value = settings.get_low_pass()
