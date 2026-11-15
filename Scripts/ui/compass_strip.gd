extends Control
class_name CompassStrip

# compass_strip.gd
# Thin compass strip along top edge (~40% screen width).
# Renders N, E, S, W, current objective, and discovered POIs relative to player surface bearing.
# Clamps off-range markers to strip ends with distance visible.

const COLOR_CYAN = Color("#3fd0f0")
const COLOR_BG = Color(0.04, 0.05, 0.07, 0.75)
const COLOR_BORDER = Color("#3fd0f0")
const COLOR_CARDINAL = Color(0.9, 0.9, 0.95, 0.9)
const FOV_RAD = PI * 0.5 # 90 degrees left and right (180 deg total window)

var player: Node3D = null
var planet: Node3D = null
var discovered_pois: Array[Dictionary] = [] # [{id, name, icon, pos, color}]
var objective_pos: Variant = null
var objective_name: String = ""

var font: Font = null
var font_size: int = 11

func _ready() -> void:
	custom_minimum_size = Vector2(460, 26)
	font = ThemeDB.fallback_font

func update_compass_data(p: Node3D, pl: Node3D, pois: Array[Dictionary], obj_pos: Variant = null, obj_name: String = "") -> void:
	player = p
	planet = pl
	discovered_pois = pois
	objective_pos = obj_pos
	objective_name = obj_name
	queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	var half_w = w * 0.5
	var center_x = half_w
	
	# Background box: near-black 75% opacity, 1px cyan border, 2px corner radius
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, COLOR_BG, true)
	draw_rect(rect, COLOR_BORDER, false, 1.0)
	
	# Center tick indicating straight ahead (player facing)
	draw_line(Vector2(center_x, 0), Vector2(center_x, 6), COLOR_CYAN, 2.0)
	draw_line(Vector2(center_x, h - 4), Vector2(center_x, h), COLOR_CYAN, 1.0)
	
	if not player or not is_instance_valid(player):
		return
	
	var p_pos = player.global_position
	var planet_center = planet.global_position if planet and is_instance_valid(planet) else Vector3.ZERO
	var up = (p_pos - planet_center).normalized()
	if up.length_squared() < 0.01:
		up = Vector3.UP
	
	var fwd = -player.global_transform.basis.z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
		fwd = (fwd - up * fwd.dot(up)).normalized()
	var right = fwd.cross(up).normalized()
	
	# Determine North on sphere
	var north_proj = Vector3.UP - up * Vector3.UP.dot(up)
	var north_dir = Vector3.ZERO
	if north_proj.length_squared() > 0.001:
		north_dir = north_proj.normalized()
	else:
		north_dir = -Vector3.FORWARD - up * (-Vector3.FORWARD).dot(up)
		if north_dir.length_squared() > 0.001:
			north_dir = north_dir.normalized()
		else:
			north_dir = fwd
			
	var east_dir = up.cross(north_dir).normalized()
	var south_dir = -north_dir
	var west_dir = -east_dir
	
	var cardinals = [
		{"label": "N", "dir": north_dir},
		{"label": "E", "dir": east_dir},
		{"label": "S", "dir": south_dir},
		{"label": "W", "dir": west_dir}
	]
	
	# Draw cardinal points
	for c in cardinals:
		var c_dir: Vector3 = c["dir"]
		var bearing = atan2(c_dir.dot(right), c_dir.dot(fwd))
		if abs(bearing) <= FOV_RAD:
			var cx = center_x + (bearing / FOV_RAD) * (half_w - 20)
			draw_line(Vector2(cx, 1), Vector2(cx, 5), COLOR_CARDINAL, 1.0)
			if font:
				var str_w = font.get_string_size(c["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
				draw_string(font, Vector2(cx - str_w * 0.5, h - 6), c["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR_CARDINAL)
	
	# Draw discovered POIs
	for poi in discovered_pois:
		var pos = poi.get("pos", Vector3.ZERO) as Vector3
		var dist = p_pos.distance_to(pos)
		var delta_v = pos - p_pos
		var surf_v = (delta_v - up * delta_v.dot(up)).normalized()
		if surf_v.length_squared() < 0.001:
			continue
		
		var bearing = atan2(surf_v.dot(right), surf_v.dot(fwd))
		var is_clamped = false
		var marker_x = center_x
		
		var usable_half_w = half_w - 32.0
		if abs(bearing) <= FOV_RAD:
			marker_x = center_x + (bearing / FOV_RAD) * usable_half_w
		else:
			is_clamped = true
			if bearing > 0:
				marker_x = center_x + usable_half_w
			else:
				marker_x = center_x - usable_half_w
		
		var col = poi.get("color", COLOR_CYAN) as Color
		var icon = poi.get("icon", "•")
		var dist_str = "%dm" % int(dist)
		var text = "%s%s" % [icon, dist_str]
		
		if font:
			var txt_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
			var draw_x = clampf(marker_x - txt_size.x * 0.5, 2.0, w - txt_size.x - 2.0)
			draw_string(font, Vector2(draw_x, 15), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, col)
		
		# Draw a small notch on the top rim
		draw_line(Vector2(marker_x, 0), Vector2(marker_x, 3), col, 2.0)
	
	# Draw Objective Marker if set
	if objective_pos is Vector3:
		var obj_v = (objective_pos as Vector3) - p_pos
		var obj_surf = (obj_v - up * obj_v.dot(up)).normalized()
		if obj_surf.length_squared() > 0.001:
			var obj_bearing = atan2(obj_surf.dot(right), obj_surf.dot(fwd))
			var obj_half_w = half_w - 32.0
			var obj_x = center_x
			if abs(obj_bearing) <= FOV_RAD:
				obj_x = center_x + (obj_bearing / FOV_RAD) * obj_half_w
			else:
				obj_x = center_x + (obj_half_w if obj_bearing > 0 else -obj_half_w)
			
			var obj_dist = int(p_pos.distance_to(objective_pos))
			var obj_text = "🎯%dm" % obj_dist
			if font:
				var sz = font.get_string_size(obj_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
				var ox = clampf(obj_x - sz.x * 0.5, 2.0, w - sz.x - 2.0)
				draw_string(font, Vector2(ox, h - 2), obj_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1, 0.9, 0.2, 1.0))
