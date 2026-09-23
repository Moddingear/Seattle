extends Node3D

func _ready() -> void:
	var flipped : Array= []
	while flipped.size() < get_child_count() /2:
		var selected: Node3D = get_children().pick_random()
		if selected in flipped:
			continue
		selected.rotate_x(PI)
		flipped.push_back(selected)
