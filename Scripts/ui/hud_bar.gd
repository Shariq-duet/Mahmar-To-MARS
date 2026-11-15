extends ProgressBar
class_name HUDBar

# hud_bar.gd
# 6px tall bar with 25%, 50%, 75% tick marks and dynamic color states:
# Cyan (#3FD0F0) normally, Amber (#F0A830) < 40%, Red (#E0463C) < 20%.

const COLOR_CYAN = Color("#3fd0f0")
const COLOR_AMBER = Color("#f0a830")
const COLOR_RED = Color("#e0463c")
const COLOR_BG = Color(0.08, 0.1, 0.12, 0.8)
const COLOR_TICK = Color(0.02, 0.02, 0.03, 0.85)

func _ready() -> void:
	custom_minimum_size = Vector2(0, 6)
	size.y = 6
	show_percentage = false
	_update_styles()
	value_changed.connect(func(_v): _update_styles())

func _update_styles() -> void:
	var pct = 100.0
	if max_value > min_value:
		pct = clampf((value - min_value) / (max_value - min_value) * 100.0, 0.0, 100.0)
	
	var fill_color = COLOR_CYAN
	if pct < 20.0:
		fill_color = COLOR_RED
	elif pct < 40.0:
		fill_color = COLOR_AMBER
	
	# Background style
	var bg_box = StyleBoxFlat.new()
	bg_box.bg_color = COLOR_BG
	bg_box.set_corner_radius_all(1)
	add_theme_stylebox_override("background", bg_box)
	
	# Fill style
	var fill_box = StyleBoxFlat.new()
	fill_box.bg_color = fill_color
	fill_box.set_corner_radius_all(1)
	add_theme_stylebox_override("fill", fill_box)
	
	queue_redraw()

func _draw() -> void:
	# Draw tick marks at 25%, 50%, 75%
	var bar_w = size.x
	var bar_h = size.y
	if bar_w <= 10.0:
		return
	
	var ticks = [0.25, 0.50, 0.75]
	for t in ticks:
		var x = round(bar_w * t)
		draw_line(Vector2(x, 0), Vector2(x, bar_h), COLOR_TICK, 1.0)
