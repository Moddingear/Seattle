extends Camera3D

@export var orbit :bool = true
@export var orbit_origin: Vector3 = Vector3.ZERO
@export var orbit_patch: Vector2 = Vector2(0.5, 0) #Size of linear orbit section
@export var sensitivity = -0.001
@export var linear_sensitivity = 1
@export var orbit_distance = 2

var look_rotation: Vector2 = Vector2(0, -0.1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("orbit_toggle"):
		orbit = !orbit
		if orbit:
			#keep position: nothing to do
			pass
		else:
			# keep angle from orbit
			look_rotation.x = get_position_from_angle().y
	if event.is_action_pressed("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_released("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func deadzone(x, center, length):
	if abs(x-center) < length /2:
		return 0
	if x > center:
		return x-length/2
	else:
		return x+length/2
			
func get_position_from_angle() -> Vector3: #position_x, angle, position_z
	#length of side is linear_sensitivity * orbit_patch
	#length of arc is pi/2
	#angle is between -PI PI
	var x_length = orbit_patch.x * linear_sensitivity
	var z_length = orbit_patch.y * linear_sensitivity
	var total_length = x_length*2 + z_length*2 + TAU
	var remapped_length = look_rotation.x * total_length / TAU
	var quarter_length = total_length/4
	var angle_x = wrapf(remapped_length, -quarter_length, quarter_length) * (-1 if abs(remapped_length) > quarter_length else 1)
	var xpos = clampf(angle_x, -x_length/2, x_length/2) / linear_sensitivity
	var angle_z = wrapf(remapped_length + quarter_length, -quarter_length, quarter_length) * (-1 if remapped_length > 0 else 1)
	var zpos = clampf(angle_z, -z_length/2, z_length/2) / linear_sensitivity
	var angle_low = clampf(deadzone(remapped_length, 0, x_length), -PI/2, PI/2)
	var angle_high = clampf(deadzone(remapped_length, 0, x_length+PI+z_length*2), -PI/2, PI/2)
	var angle = angle_low+angle_high
	return Vector3(xpos, angle, zpos)
		
func normalize_rotation():
	look_rotation.x = wrapf(look_rotation.x, -PI, PI)
	look_rotation.y = clampf(look_rotation.y, -PI/2, 0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		var event_mouse = event as InputEventMouseMotion
		look_rotation += event_mouse.relative * sensitivity
		normalize_rotation()

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	#forward is -z in godot
	look_rotation.x += Input.get_axis("look_x-", "look_x+") * delta * (1 if orbit else -1)
	look_rotation.y += Input.get_axis("look_y-", "look_y+") * delta * (1 if orbit else -1)
	normalize_rotation()
	var angle = look_rotation.x
	var orbit_patch_position = Vector3.ZERO
	if orbit:
		orbit_patch_position = get_position_from_angle()
		angle = orbit_patch_position.y
	var look_basis := Basis.from_euler(Vector3(look_rotation.y, angle, 0), EULER_ORDER_YZX)
	var look_vector := -look_basis.z
	if orbit:
		position = orbit_origin + Vector3(orbit_patch_position.x, 0, orbit_patch_position.z) - look_vector * orbit_distance
	else:
		var move_x = Input.get_axis("left", "right")
		var move_y = Input.get_axis("down", "up")
		var move_z = Input.get_axis("forward", "back")
		position.x += (cos(angle) * move_x + sin(angle) * move_z) * delta
		position.z += (cos(angle) * move_z - sin(angle) * move_x) * delta
		position.y += move_y * delta
	basis = look_basis 
	
