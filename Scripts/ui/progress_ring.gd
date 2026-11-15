extends Control
class_name ProgressRing

# progress_ring.gd
# Circular progress ring drawn around interaction center when holding E.

const COLOR_RING_BG = Color(0.25, 0.82, 0.94, 0.2)
const COLOR_RING_FILL = Color("#3fd0f0")

var progress: float = 0.0:
	set(val):
		progress = clampf(val, 0.0, 1.0)
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(80, 80)
	visible = false

func set_progress(val: float) -> void:
	progress = val

func _draw() -> void:
	if not visible:
		return
	var center = size * 0.5
	var radius = 28.0
	var width = 3.0
	
	# Background full ring
	draw_arc(center, radius, 0, TAU, 48, COLOR_RING_BG, width, true)
	
	# Filled arc
	if progress > 0.001:
		var start_angle = -PI * 0.5
		var end_angle = start_angle + progress * TAU
		draw_arc(center, radius, start_angle, end_angle, 48, COLOR_RING_FILL, width, true)
