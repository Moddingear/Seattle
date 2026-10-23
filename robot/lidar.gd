extends Control

@onready var connection : robot_connection = $"../Connection"
@onready var draw_area := $draw_area
var cutoff_time_us : int
@export var max_distance = 5
@export var distance_steps_per_meter = 5
var last_end_angle = 0;

const proto = preload("res://protoc/gd_esp.gd")

class DisplayPoint:
	var distance : float
	var angle : float
	var intensity : float
	var flags :int
	var time_us : int
	
var display_points:Array[DisplayPoint] = []



func _ready() -> void:
	connection.register_callback(on_lidar_data, proto.gd_esp_packet.DataCase.LIDAR_DATA);
	queue_redraw()

func clamp_angle_rad(angle:float)->float:
	var wrapped = fposmod(angle, TAU)
	if wrapped > PI:
		return wrapped - TAU
	return wrapped
	
func decode_i8f2d14(data: PackedByteArray, offset:int):
	var point = DisplayPoint.new()
	point.intensity = data.decode_u8(offset)
	var distance_flags = data.decode_u16(offset+1)
	point.flags = distance_flags & 0b11
	point.distance = (distance_flags >> 2)
	return point
	
func on_lidar_data(packet: proto.gd_esp_packet):
	var data : proto.LidarData = packet.get_lidar_data()
	var source_name = data.get_lidar_source()
	var start_angle_rad = deg_to_rad(data.get_start_angle())
	var end_angle_rad = deg_to_rad(data.get_end_angle())
	#print("last end angle %f, end angle %f" % [last_end_angle, end_angle_rad])
	var nbdisplay_before = len(display_points)
	display_points = display_points.filter(func(point:DisplayPoint): 
		if last_end_angle < end_angle_rad: #normal case
			return point.angle <= last_end_angle || point.angle >= end_angle_rad
		else: #angle wraparound, keep everything between start_angle and end_angle
			return last_end_angle >= point.angle && point.angle >= end_angle_rad
	)
	last_end_angle = end_angle_rad
	var num_purged = nbdisplay_before - len(display_points)
	#print("Purged %d points by filter" % num_purged)
	if num_purged>60:
		#breakpoint
		pass
	#make end_angle > start_angle
	if end_angle_rad < start_angle_rad:
		if absf(start_angle_rad) > absf(end_angle_rad):
			start_angle_rad -= TAU
		else:
			end_angle_rad += TAU
	var time_now = Time.get_ticks_usec()
	if source_name.contains("|"):
		var bytes_per_point = 0
		var decode_function : Callable
		var format = source_name.substr(source_name.find("|")+1)
		match format:
			"I8F2D14":
				bytes_per_point = 3
				decode_function = decode_i8f2d14
			_:
				push_error("Could not parse lidar data format %s!" % format)
				breakpoint
		var raw = data.get_raw()
		if len(raw) % bytes_per_point != 0:
			breakpoint
		var num_points = len(raw)/bytes_per_point
		var np_lerp = maxf(num_points-1, 1)
		for i in len(raw)/bytes_per_point:
			var display_point :DisplayPoint = decode_function.call(raw, i*bytes_per_point)
			display_point.angle = fposmod(lerpf(start_angle_rad, end_angle_rad, i/np_lerp), TAU)
			display_point.time_us = time_now
			display_points.push_back(display_point)
	else:
		var data_points : Array[proto.LidarData.LidarPoint] = data.get_points()
		var num_points = len(data_points)
		var np_lerp = maxf(num_points-1, 1)
		for i in num_points:
			var data_point = data_points[i]
			var display_point = DisplayPoint.new()
			display_point.angle = fposmod(lerpf(start_angle_rad, end_angle_rad, i/np_lerp), TAU)
			display_point.distance = data_point.get_distance()
			display_point.intensity = data_point.get_luminosity()
			display_point.flags = 0
			display_point.time_us = time_now
			display_points.append(display_point)
	#cutoff_time_us = time_now - 1000000/6.0 
	#display_points = display_points.filter(point_filter)
	queue_redraw()

func point_filter(point:DisplayPoint)->bool:
	if point.time_us < cutoff_time_us:
		return false
	return true
	
func _draw() -> void:
	var area :Rect2= draw_area.get_rect()
	var center := area.get_center()
	var extent :float=min(area.size.x, area.size.y)/2
	var dist_to_px = extent/(1000*max_distance)
	var num_quadrants = 24
	draw_rect(area, Color.BLACK)
	for i in range(num_quadrants):
		var end = center + Vector2.from_angle(i*TAU/num_quadrants) * extent
		draw_line(center, end, Color.from_hsv(float(i)/num_quadrants, 1, 1))
		draw_string(ThemeDB.fallback_font, end, "%d" % [i*360/num_quadrants])
	for i in range(1, max_distance*distance_steps_per_meter+1):
		var distance :float = float(i)/distance_steps_per_meter
		var radius :float = distance*extent/max_distance
		var whole :bool = i%distance_steps_per_meter == 0
		draw_circle(center, radius, Color.GRAY if whole else Color.DIM_GRAY, false)
		if whole:
			draw_string(ThemeDB.fallback_font, center + Vector2(radius, 0), "%dm" % [i/distance_steps_per_meter])
	for point in display_points:
		var point_location :Vector2 = center + point.distance * dist_to_px * Vector2.from_angle(point.angle)
		draw_circle(point_location, 2, Color.from_hsv(0,0,sqrt(point.intensity/255.0)))
		if point.flags:
			draw_circle(point_location, 1, Color.RED)
