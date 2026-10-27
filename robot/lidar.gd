extends Control

const proto = preload("res://protoc/gd_esp.gd")
@export var connection : robot_connection_client

@onready var draw_area := $draw_area
var cutoff_time_us : int
@export var max_distance = 5
@export var distance_steps_per_meter = 5
var last_end_angle = 0;

class DisplayPoint:
	var distance : float
	var angle : float
	var intensity : float
	var flags :int
	var time_us : int
	
var display_points:Array[DisplayPoint] = []
var recycled_display_points:Array[DisplayPoint] = []


func _ready() -> void:
	connection.register_callback(on_lidar_data, proto.esp_gd_packet.DataCase.LIDAR_DATA);
	queue_redraw()

func clamp_angle_rad(angle:float)->float:
	var wrapped = fposmod(angle, TAU)
	if wrapped > PI:
		return wrapped - TAU
	return wrapped
	
func decode_i8f2d14(data: PackedByteArray, offset:int, point: DisplayPoint) -> DisplayPoint:
	point.intensity = data.decode_u8(offset)
	var distance_flags = data.decode_u16(offset+1)
	point.flags = distance_flags & 0b11
	point.distance = (distance_flags >> 2)
	return point

func angle_filter(test_angle, start_angle, end_angle):
	if start_angle < end_angle: #normal case
		return test_angle <= start_angle || test_angle >= end_angle
	else: #angle wraparound, keep everything between start_angle and end_angle
		return start_angle >= test_angle && test_angle >= end_angle
	
func on_lidar_data(packet: proto.esp_gd_packet):
	var data : proto.LidarData = packet.get_lidar_data()
	var source_name = data.get_lidar_source()
	var start_angle_rad = deg_to_rad(data.get_start_angle())
	var end_angle_rad = deg_to_rad(data.get_end_angle())
	#print("last end angle %f, end angle %f" % [last_end_angle, end_angle_rad])
	var nbdisplay_before = len(display_points)
	var reuse_display_points:Array[DisplayPoint] = []
	for point in display_points:
		if angle_filter(point.angle, last_end_angle, end_angle_rad):
			reuse_display_points.push_back(point)
		else:
			recycled_display_points.push_back(point)
	display_points = reuse_display_points
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
		var num_points :int= len(raw)/bytes_per_point
		var np_lerp := maxf(num_points-1, 1)
		var num_invalid = 0
		for i in num_points:
			var display_point = recycled_display_points.pop_back()
			if display_point == null:
				display_point = DisplayPoint.new()
			decode_function.call(raw, i*bytes_per_point, display_point)
			display_point.angle = fposmod(lerpf(start_angle_rad, end_angle_rad, i/np_lerp), TAU)
			display_point.time_us = time_now
			if display_point.distance < 0.05:
				recycled_display_points.push_back(display_point)
				num_invalid+=1
				#print("Point too close, index %d/%d, raw %s, flags %d" % [i, num_points, raw.slice(i*bytes_per_point, (i+1)*bytes_per_point).hex_encode(), display_point.flags])
			else:
				display_points.push_back(display_point)
		if num_invalid:
			pass
			#printerr("Got %d invalid lidar points" % num_invalid)
	else:
		var data_points : Array[proto.LidarData.LidarPoint] = data.get_points()
		var num_points := len(data_points)
		var np_lerp := maxf(num_points-1, 1)
		for i in num_points:
			var data_point = data_points[i]
			var display_point = recycled_display_points.pop_back()
			if display_point == null:
				display_point = DisplayPoint.new()
			display_point.angle = fposmod(lerpf(start_angle_rad, end_angle_rad, i/np_lerp), TAU)
			display_point.distance = data_point.get_distance()
			display_point.intensity = data_point.get_luminosity()
			display_point.flags = 0
			display_point.time_us = time_now
			display_points.append(display_point)
	queue_redraw()

	
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
	if 0:
		for point in display_points:
			var point_location :Vector2 = center + point.distance * dist_to_px * Vector2.from_angle(point.angle)
			draw_circle(point_location, 2, Color.from_hsv(0,0,sqrt(point.intensity/255.0)))
			if point.flags:
				draw_circle(point_location, 1, Color.RED)
	else:
		display_points.sort_custom(func(a:DisplayPoint, b:DisplayPoint):
			return a.angle < b.angle
		)
		var num_points = display_points.size()
		var coords := PackedVector2Array()
		coords.resize(num_points)
		var colors := PackedColorArray()
		colors.resize(num_points)
		for i in num_points:
			var point := display_points[i]
			coords[i] = center + point.distance * dist_to_px * Vector2.from_angle(point.angle)
			colors[i] = Color.RED if point.flags else Color.from_hsv(1/3.0,1,sqrt(point.intensity/128.0))
		draw_polyline_colors(coords, colors, 2)
