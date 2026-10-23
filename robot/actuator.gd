extends HBoxContainer

class_name Actuator

@export var discriminator : int = 0:
	set(new_value):
		$Discriminator.text = str(new_value)
		discriminator = new_value
@export var uid : String = "":
	set(new_value):
		$UIDButton.hide()
		$UIDText.show()
		$UIDText.text = new_value
		uid = new_value


func _on_uid_button_pressed() -> void:
	(get_parent() as NetworkViewer)._on_child_want_uid(discriminator)


func _on_jump_bootloader_pressed() -> void:
	(get_parent() as NetworkViewer)._on_child_want_bootloader(discriminator)
