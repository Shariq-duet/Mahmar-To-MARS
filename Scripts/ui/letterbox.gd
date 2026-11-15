extends CanvasLayer
class_name LetterboxUI

# letterbox.gd
# Letterbox cinematic UI with two black ColorRect bars (~12% screen height).
# Smoothly slides bars in at the start of cinematic sequences and slides out at the end.
# Automatically ensures HUD remains hidden while letterbox bars are visible.

signal slide_in_completed
signal slide_out_completed

@export var bar_height_ratio: float = 0.12 # 12% of viewport height
@export var hide_hud: bool = false # Only hide HUD when explicitly instructed (e.g. non-interactive cutscene)

@onready var top_bar: ColorRect = $TopBar
@onready var bottom_bar: ColorRect = $BottomBar

var hud_reference: CanvasLayer = null
var is_active: bool = false
var slide_progress: float = 0.0 # 0.0 = off-screen, 1.0 = fully on-screen
var tween: Tween = null

func _ready() -> void:
	layer = 15 # Render above regular game elements
	_apply_bar_offsets(0.0)

func set_hud(hud_node: CanvasLayer) -> void:
	hud_reference = hud_node
	if is_active and hide_hud and hud_reference:
		hud_reference.visible = false

func set_hud_visible(visible_state: bool) -> void:
	hide_hud = not visible_state
	var h = _find_hud()
	if h:
		h.visible = visible_state

func _find_hud() -> CanvasLayer:
	if hud_reference and is_instance_valid(hud_reference):
		return hud_reference
	var tree = get_tree()
	if tree and tree.root:
		var found = tree.root.find_child("HUD", true, false) as CanvasLayer
		if found:
			hud_reference = found
	return hud_reference

func slide_in(duration: float = 0.8) -> void:
	is_active = true
	if not is_inside_tree():
		await tree_entered
	
	if hide_hud:
		var h = _find_hud()
		if h:
			h.visible = false
	
	if tween and tween.is_valid():
		tween.kill()
	
	print("[LETTERBOX UI] Sliding letterbox bars in (height = %.0f%% screen)..." % (bar_height_ratio * 100.0))
	tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_apply_bar_offsets, slide_progress, 1.0, duration)
	tween.tween_callback(func():
		slide_in_completed.emit()
		print("[LETTERBOX UI] Letterbox bars fully slid in.")
	)

func slide_out(duration: float = 0.8) -> void:
	if tween and tween.is_valid():
		tween.kill()
	
	print("[LETTERBOX UI] Sliding letterbox bars out...")
	tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(_apply_bar_offsets, slide_progress, 0.0, duration)
	tween.tween_callback(func():
		is_active = false
		slide_out_completed.emit()
		var h = _find_hud()
		if h:
			h.visible = true
		print("[LETTERBOX UI] Letterbox bars fully slid out. HUD visibility restored.")
	)

func _process(_delta: float) -> void:
	# Ensure HUD stays hidden only if hide_hud is explicitly requested
	if is_active and hide_hud:
		var h = _find_hud()
		if h and h.visible:
			h.visible = false

func _apply_bar_offsets(p: float) -> void:
	slide_progress = p
	var vp_size = get_viewport().get_visible_rect().size
	var bar_h = vp_size.y * bar_height_ratio
	
	# Top bar: anchor top, height bar_h.
	# Off-screen (p=0): offset from -bar_h to 0.
	# On-screen (p=1): offset from 0 to bar_h.
	var top_y = -bar_h * (1.0 - p)
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 0.0
	top_bar.offset_right = 0.0
	top_bar.offset_top = top_y
	top_bar.offset_bottom = top_y + bar_h
	
	# Bottom bar: anchor bottom, height bar_h.
	# Off-screen (p=0): offset from 0 to +bar_h.
	# On-screen (p=1): offset from -bar_h to 0.
	var bottom_y = bar_h * (1.0 - p)
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_left = 0.0
	bottom_bar.offset_right = 0.0
	bottom_bar.offset_top = -bar_h + bottom_y
	bottom_bar.offset_bottom = bottom_y

func is_bars_visible() -> bool:
	return slide_progress > 0.01
