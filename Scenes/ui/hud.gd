extends CanvasLayer

# hud.gd
# Restyled Junior Astronaut HUD:
# - Unified Theme: near-black 75% opacity, 1px cyan border (#3FD0F0), 2px corner radius.
# - 6px bars with 25% ticks, dynamic cyan/amber/red colors.
# - 12px uppercase labels, 14px values.
# - 24px screen edge margins; central 60% keep-clear zone.
# - Astronaut stack top-left (Health always, others < 90%).
# - Outpost stack top-right (revealed after pod, only < 90%).
# - Compass strip top-center (~40% width) with N, E, S, W & discovered POI markers.
# - Bottom-center objective line with 3s messages above it.
# - Bottom-left signals list of discovered POIs.
# - Center Press E prompt and circular hold-progress ring.
# - 5-second idle fade to 40% opacity.

const SurvivalSystem = preload("res://Scripts/survival/survival_system.gd")
const CompassStripScript = preload("res://Scripts/ui/compass_strip.gd")
const ProgressRingScript = preload("res://Scripts/ui/progress_ring.gd")
const HUDBarScript = preload("res://Scripts/ui/hud_bar.gd")

# Top-Left: Astronaut stack
@onready var control_root: Control = $Control
@onready var survival_meters: PanelContainer = $Control/TopLeft/SurvivalMeters
@onready var health_box: HBoxContainer = $Control/TopLeft/SurvivalMeters/Margin/VBox/HealthBox
@onready var health_bar: ProgressBar = $Control/TopLeft/SurvivalMeters/Margin/VBox/HealthBox/HealthBar
@onready var health_val: Label = $Control/TopLeft/SurvivalMeters/Margin/VBox/HealthBox/HealthVal

@onready var o2_box: HBoxContainer = $Control/TopLeft/SurvivalMeters/Margin/VBox/O2Box
@onready var o2_bar: ProgressBar = $Control/TopLeft/SurvivalMeters/Margin/VBox/O2Box/O2Bar
@onready var o2_val: Label = $Control/TopLeft/SurvivalMeters/Margin/VBox/O2Box/O2Val

@onready var suit_box: HBoxContainer = $Control/TopLeft/SurvivalMeters/Margin/VBox/SuitBox
@onready var suit_bar: ProgressBar = $Control/TopLeft/SurvivalMeters/Margin/VBox/SuitBox/SuitBar
@onready var suit_val: Label = $Control/TopLeft/SurvivalMeters/Margin/VBox/SuitBox/SuitVal

@onready var jetpack_box: HBoxContainer = $Control/TopLeft/SurvivalMeters/Margin/VBox/JetpackBox
@onready var jetpack_bar: ProgressBar = $Control/TopLeft/SurvivalMeters/Margin/VBox/JetpackBox/JetpackBar
@onready var jetpack_val: Label = $Control/TopLeft/SurvivalMeters/Margin/VBox/JetpackBox/JetpackVal

# Top-Right: Outpost stack
@onready var base_meters: PanelContainer = $Control/TopRight/BaseMeters
@onready var power_box: HBoxContainer = $Control/TopRight/BaseMeters/Margin/VBox/PowerBox
@onready var power_bar: ProgressBar = $Control/TopRight/BaseMeters/Margin/VBox/PowerBox/PowerBar
@onready var power_val: Label = $Control/TopRight/BaseMeters/Margin/VBox/PowerBox/PowerVal

@onready var water_box: HBoxContainer = $Control/TopRight/BaseMeters/Margin/VBox/WaterBox
@onready var water_bar: ProgressBar = $Control/TopRight/BaseMeters/Margin/VBox/WaterBox/WaterBar
@onready var water_val: Label = $Control/TopRight/BaseMeters/Margin/VBox/WaterBox/WaterVal

@onready var food_box: HBoxContainer = $Control/TopRight/BaseMeters/Margin/VBox/FoodBox
@onready var food_bar: ProgressBar = $Control/TopRight/BaseMeters/Margin/VBox/FoodBox/FoodBar
@onready var food_val: Label = $Control/TopRight/BaseMeters/Margin/VBox/FoodBox/FoodVal

# Top-Center: Compass & Sol
@onready var compass_strip: Control = $Control/TopCenter/CompassStrip
@onready var sol_panel: PanelContainer = $Control/TopCenter/SolPanel
@onready var sol_label: Label = $Control/TopCenter/SolPanel/Margin/SolLabel

# Bottom-Left: Signals list & Inventory
@onready var signals_panel: PanelContainer = get_node_or_null("Control/BottomLeft/VBox/SignalsPanel") if has_node("Control/BottomLeft/VBox/SignalsPanel") else get_node_or_null("Control/BottomLeft/SignalsPanel")
@onready var signals_list: VBoxContainer = get_node_or_null("Control/BottomLeft/VBox/SignalsPanel/Margin/VBox/ListContainer") if has_node("Control/BottomLeft/VBox/SignalsPanel/Margin/VBox/ListContainer") else get_node_or_null("Control/BottomLeft/SignalsPanel/Margin/VBox/ListContainer")
@onready var signal_label: Label = get_node_or_null("Control/BottomLeft/VBox/SignalsPanel/Margin/VBox/LegacySignalLabel") if has_node("Control/BottomLeft/VBox/SignalsPanel/Margin/VBox/LegacySignalLabel") else get_node_or_null("Control/BottomLeft/SignalsPanel/Margin/VBox/LegacySignalLabel")
@onready var inventory_panel: PanelContainer = get_node_or_null("Control/BottomLeft/VBox/InventoryPanel")
@onready var inventory_label: Label = get_node_or_null("Control/BottomLeft/VBox/InventoryPanel/Margin/InventoryLabel")

# Bottom-Center: Objective & Messages
@onready var objective_banner: PanelContainer = $Control/BottomCenter/ObjectiveBanner
@onready var objective_label: Label = $Control/BottomCenter/ObjectiveBanner/Margin/ObjectiveLabel
@onready var alert_banner: PanelContainer = $Control/BottomCenter/AlertBanner
@onready var alert_text: Label = $Control/BottomCenter/AlertBanner/Margin/AlertText

# Center: Prompt & Progress Ring
@onready var center_prompt_box: VBoxContainer = $Control/CenterPrompt
@onready var center_prompt_label: Label = $Control/CenterPrompt/PromptLabel
@onready var progress_ring: Control = $Control/CenterPrompt/ProgressRing

# Overlays and Popups
@onready var jetpack_banner: PanelContainer = $Control/JetpackOnlineBanner
@onready var jetpack_label: Label = $Control/JetpackOnlineBanner/Margin/Label
@onready var fade_overlay: ColorRect = $Control/FadeOverlay
@onready var lore_popup: PanelContainer = $Control/LorePopup
@onready var lore_title: Label = $Control/LorePopup/Margin/VBox/LoreTitle
@onready var lore_body: Label = $Control/LorePopup/Margin/VBox/LoreBody
@onready var lore_part: Label = $Control/LorePopup/Margin/VBox/LorePart
@onready var pause_menu: PanelContainer = $Control/PauseMenu
@onready var death_screen: PanelContainer = $Control/DeathScreen
@onready var death_reason_label: Label = $Control/DeathScreen/Margin/VBox/DeathReason
@onready var win_screen: PanelContainer = $Control/WinScreen
@onready var placement_dialog: PanelContainer = $Control/PlacementDialog
@onready var placement_coords: Label = $Control/PlacementDialog/Margin/VBox/CoordsLabel
@onready var placement_name_input: LineEdit = $Control/PlacementDialog/Margin/VBox/NameInput
@onready var placement_save_btn: Button = $Control/PlacementDialog/Margin/VBox/BtnBox/SaveBtn
@onready var placement_cancel_btn: Button = $Control/PlacementDialog/Margin/VBox/BtnBox/CancelBtn

var recorded_placement_pos: Vector3 = Vector3.ZERO

var survival: RefCounted = null
var hud_revealed: bool = false
var outpost_revealed: bool = false
var jetpack_unlocked: bool = false

# Idle fade logic: drops to 40% opacity after 5 seconds with no value change
var idle_timer: float = 0.0
var is_idle_faded: bool = false
const IDLE_TIMEOUT: float = 5.0
const IDLE_OPACITY: float = 0.40

var last_health_int: int = -1
var last_o2_int: int = -1
var last_suit_int: int = -1
var last_power_int: int = -1
var last_water_int: int = -1
var last_food_int: int = -1
var last_jetpack_int: int = -1

func _ready() -> void:
	if alert_banner: alert_banner.visible = false
	if lore_popup: lore_popup.visible = false
	if pause_menu: pause_menu.visible = false
	if death_screen: death_screen.visible = false
	if win_screen: win_screen.visible = false
	if placement_dialog: placement_dialog.visible = false
	if objective_banner: objective_banner.visible = false
	if jetpack_banner: jetpack_banner.visible = false
	if center_prompt_box: center_prompt_box.visible = false
	if progress_ring: progress_ring.visible = false
	if fade_overlay: fade_overlay.color = Color(0, 0, 0, 0)
	
	if placement_save_btn:
		placement_save_btn.pressed.connect(_on_save_placement_pressed)
	if placement_cancel_btn:
		placement_cancel_btn.pressed.connect(close_placement_dialog)
	if placement_name_input:
		placement_name_input.text_submitted.connect(func(_t): _on_save_placement_pressed())
	
	if death_screen:
		var d_restart = death_screen.find_child("RestartBtn", true, false) as Button
		if d_restart and not d_restart.pressed.is_connected(_on_restart_pressed):
			d_restart.pressed.connect(_on_restart_pressed)
	if win_screen:
		var w_restart = win_screen.find_child("WinRestartBtn", true, false) as Button
		if w_restart and not w_restart.pressed.is_connected(_on_restart_pressed):
			w_restart.pressed.connect(_on_restart_pressed)
	
	# Outpost meters stay completely hidden until pod arrival sequence
	if base_meters:
		base_meters.visible = false
	
	# Initial bar visibility checks
	_update_astronaut_bar_visibility()
	_update_outpost_bar_visibility()
	
	# Connect to GameManager inventory updates
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("inventory_changed"):
		gm.inventory_changed.connect(_update_inventory_display)
	_update_inventory_display()

func _update_inventory_display() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var fc: int = gm.filter_core if gm else 0
	var pc: int = gm.power_unit_core if gm else 0
	var wi: int = gm.water_ice if gm else 0
	if inventory_label:
		inventory_label.text = "FILTER CORE: %d    POWER CORE: %d    WATER ICE: %d" % [fc, pc, wi]

func _process(delta: float) -> void:
	idle_timer += delta
	if idle_timer >= IDLE_TIMEOUT and not is_idle_faded:
		_fade_hud(true)

func _notify_hud_activity() -> void:
	idle_timer = 0.0
	if is_idle_faded:
		_fade_hud(false)

var idle_fade_tween: Tween = null

func _fade_hud(faded: bool) -> void:
	is_idle_faded = faded
	if not control_root:
		return
	var target_alpha = IDLE_OPACITY if faded else 1.0
	if idle_fade_tween and idle_fade_tween.is_valid():
		idle_fade_tween.kill()
	idle_fade_tween = create_tween()
	idle_fade_tween.tween_property(control_root, "modulate:a", target_alpha, 0.4)

func bind_survival_system(sys: RefCounted) -> void:
	survival = sys
	survival.health_changed.connect(_on_health_changed)
	survival.oxygen_changed.connect(_on_oxygen_changed)
	survival.suit_changed.connect(_on_suit_changed)
	survival.power_changed.connect(_on_power_changed)
	survival.water_changed.connect(_on_water_changed)
	survival.food_changed.connect(_on_food_changed)
	survival.sol_advanced.connect(_on_sol_advanced)
	survival.player_died.connect(_on_player_died)
	if survival.has_signal("storm_warning"):
		survival.storm_warning.connect(_on_storm_warning)
	
	_on_health_changed(survival.health)
	_on_oxygen_changed(survival.oxygen)
	_on_suit_changed(survival.suit_integrity)
	_on_power_changed(survival.power)
	_on_water_changed(survival.water)
	_on_food_changed(survival.food)
	_on_sol_advanced(survival.current_sol)

func _update_astronaut_bar_visibility() -> void:
	if not survival:
		return
	# Health always visible
	if health_box: health_box.visible = true
	# Others only when below 90%
	if o2_box: o2_box.visible = (survival.oxygen < 90.0)
	if suit_box: suit_box.visible = (survival.suit_integrity < 90.0)
	if jetpack_box:
		var j_val = jetpack_bar.value if jetpack_bar else 100.0
		jetpack_box.visible = (jetpack_unlocked and j_val < 90.0)

func _update_outpost_bar_visibility() -> void:
	if not outpost_revealed or not survival:
		if base_meters: base_meters.visible = false
		return
	
	var p_show = (survival.power < 90.0)
	var w_show = (survival.water < 90.0)
	var f_show = (survival.food < 90.0)
	
	if power_box: power_box.visible = p_show
	if water_box: water_box.visible = w_show
	if food_box: food_box.visible = f_show
	
	if base_meters:
		base_meters.visible = (p_show or w_show or f_show)

# -------------------------------------------------------------------------
# Dynamic Bar Value Handlers
# -------------------------------------------------------------------------
func _on_health_changed(val: float) -> void:
	var iv = int(val)
	if iv != last_health_int:
		last_health_int = iv
		_notify_hud_activity()
	if health_bar: health_bar.value = val
	if health_val: health_val.text = "%d%%" % iv
	_update_astronaut_bar_visibility()

func _on_oxygen_changed(val: float) -> void:
	var iv = int(val)
	var is_bar_visible = (val < 90.0)
	if iv != last_o2_int:
		if is_bar_visible:
			_notify_hud_activity()
		last_o2_int = iv
	if o2_bar: o2_bar.value = val
	if o2_val:
		o2_val.text = ("LOW: %d%%" if val < 20.0 else "%d%%") % iv
	_update_astronaut_bar_visibility()

func _on_suit_changed(val: float) -> void:
	var iv = int(val)
	var is_bar_visible = (val < 90.0)
	if iv != last_suit_int:
		if is_bar_visible:
			_notify_hud_activity()
		last_suit_int = iv
	if suit_bar: suit_bar.value = val
	if suit_val:
		suit_val.text = ("BREACH! %d%%" if val < 25.0 else "%d%%") % iv
	_update_astronaut_bar_visibility()

func update_jetpack_fuel(current: float, max_val: float) -> void:
	var pct = clamp((current / max_val) * 100.0, 0.0, 100.0)
	var iv = int(pct)
	var is_bar_visible = (jetpack_unlocked and pct < 90.0)
	if iv != last_jetpack_int:
		if is_bar_visible:
			_notify_hud_activity()
		last_jetpack_int = iv
	if jetpack_bar:
		jetpack_bar.max_value = max_val
		jetpack_bar.value = current
	if jetpack_val:
		jetpack_val.text = "%d%%" % iv
	_update_astronaut_bar_visibility()

func _on_power_changed(val: float) -> void:
	var iv = int(val)
	var is_bar_visible = (outpost_revealed and val < 90.0)
	if iv != last_power_int:
		if is_bar_visible:
			_notify_hud_activity()
		last_power_int = iv
	if power_bar: power_bar.value = val
	if power_val: power_val.text = "%d%%" % iv
	_update_outpost_bar_visibility()

func _on_water_changed(val: float) -> void:
	var iv = int(val)
	var is_bar_visible = (outpost_revealed and val < 90.0)
	if iv != last_water_int:
		if is_bar_visible:
			_notify_hud_activity()
		last_water_int = iv
	if water_bar: water_bar.value = val
	if water_val: water_val.text = "%d%%" % iv
	_update_outpost_bar_visibility()

func _on_food_changed(val: float) -> void:
	var iv = int(val)
	var is_bar_visible = (outpost_revealed and val < 90.0)
	if iv != last_food_int:
		if is_bar_visible:
			_notify_hud_activity()
		last_food_int = iv
	if food_bar: food_bar.value = val
	if food_val: food_val.text = "%d%%" % iv
	_update_outpost_bar_visibility()

func _on_sol_advanced(sol: int) -> void:
	_notify_hud_activity()
	if sol_label:
		sol_label.text = "☀️ SOL %d" % sol
	show_message("☀️ New Mars Sol %d has begun! Daily supplies refreshed." % sol, 4.0)

# -------------------------------------------------------------------------
# Prompt & Circular Progress Ring (Central 60%)
# -------------------------------------------------------------------------
func set_interaction_prompt(text: String) -> void:
	if center_prompt_box and center_prompt_box.visible and center_prompt_label and center_prompt_label.text == text.to_upper():
		return
	_notify_hud_activity()
	if center_prompt_box and center_prompt_label:
		center_prompt_label.text = text.to_upper()
		center_prompt_box.visible = true

func clear_interaction_prompt() -> void:
	if center_prompt_box and center_prompt_box.visible:
		_notify_hud_activity()
		center_prompt_box.visible = false

func show_progress_ring(prog: float = 0.0) -> void:
	_notify_hud_activity()
	if progress_ring:
		progress_ring.set_progress(prog)
		progress_ring.visible = true

func update_progress_ring(prog: float) -> void:
	_notify_hud_activity()
	if progress_ring:
		progress_ring.set_progress(prog)

func hide_progress_ring() -> void:
	if progress_ring and progress_ring.visible:
		_notify_hud_activity()
		progress_ring.visible = false
		progress_ring.set_progress(0.0)

# -------------------------------------------------------------------------
# Messages & Objectives (Bottom-Center)
# -------------------------------------------------------------------------
var message_tween: Tween = null

func show_message(text: String, duration: float = 3.0) -> void:
	_notify_hud_activity()
	if not alert_banner or not alert_text:
		return
	alert_text.text = text
	alert_banner.visible = true
	alert_banner.modulate.a = 0.0
	
	if message_tween and message_tween.is_valid():
		message_tween.kill()
	
	message_tween = create_tween()
	message_tween.tween_property(alert_banner, "modulate:a", 1.0, 0.2)
	message_tween.tween_interval(duration)
	message_tween.tween_property(alert_banner, "modulate:a", 0.0, 0.4)
	message_tween.tween_callback(func(): alert_banner.visible = false)

func show_alert(message: String, _is_warning: bool = true, duration: float = 3.0) -> void:
	show_message(message, duration)

func show_objective(text: String) -> void:
	_notify_hud_activity()
	if objective_label:
		objective_label.text = "🎯 CURRENT OBJECTIVE: " + text.to_upper()
	if objective_banner:
		objective_banner.visible = true
		objective_banner.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(objective_banner, "modulate:a", 1.0, 0.4)

# -------------------------------------------------------------------------
# Compass & Signals (Top-Center & Bottom-Left)
# -------------------------------------------------------------------------
func update_compass(player_node: Node3D, planet_node: Node3D, pois: Array[Dictionary], obj_pos: Variant = null, obj_name: String = "") -> void:
	if compass_strip:
		compass_strip.update_compass_data(player_node, planet_node, pois, obj_pos, obj_name)

func update_discovered_signals(pois: Array[Dictionary]) -> void:
	if not signals_panel or not signals_list:
		return
	
	# Clear existing dynamic signal labels
	for child in signals_list.get_children():
		child.queue_free()
	
	if pois.is_empty():
		signals_panel.visible = false
		return
	
	signals_panel.visible = true
	for poi in pois:
		var lbl = Label.new()
		var icon = poi.get("icon", "•")
		var p_name = str(poi.get("name", "")).to_upper()
		var dist = int(poi.get("dist", 0))
		lbl.text = "%s %-12s %4dm" % [icon, p_name, dist]
		lbl.add_theme_font_size_override("font_size", 12)
		var col = poi.get("color", Color("#3fd0f0"))
		lbl.add_theme_color_override("font_color", col)
		signals_list.add_child(lbl)

# Legacy method for compatibility
func update_signals(text: String) -> void:
	if signal_label:
		signal_label.text = text

# -------------------------------------------------------------------------
# Sol 1 Life Pod Arrival Staged Reveals & Screen Fade
# -------------------------------------------------------------------------
func fade_screen(target_alpha: float, duration: float) -> void:
	if not fade_overlay:
		fade_overlay = get_node_or_null("Control/FadeOverlay") as ColorRect
	if not fade_overlay:
		return
	var tw = create_tween()
	tw.tween_property(fade_overlay, "color:a", target_alpha, duration)
	await tw.finished

func reveal_hud_staged(fade_dur: float, gap: float, t0: float) -> void:
	outpost_revealed = true
	if base_meters:
		base_meters.visible = true
		base_meters.modulate.a = 0.0
		var tw_base = create_tween()
		tw_base.tween_property(base_meters, "modulate:a", 1.0, fade_dur)
	
	var items = [
		{"name": "Health", "node": health_box, "panel": survival_meters},
		{"name": "Oxygen", "node": o2_box, "panel": survival_meters},
		{"name": "Suit", "node": suit_box, "panel": survival_meters},
		{"name": "Outpost Power", "node": power_box, "panel": base_meters},
		{"name": "Outpost Water", "node": water_box, "panel": base_meters},
		{"name": "Outpost Food", "node": food_box, "panel": base_meters}
	]
	
	var last_start_time: float = -1.0
	for i in range(items.size()):
		var item = items[i]
		if item.panel and item.panel.modulate.a < 1.0:
			item.panel.modulate.a = 1.0
		
		var t_now = (Time.get_ticks_msec() / 1000.0) - t0
		if last_start_time >= 0.0:
			var actual_gap = t_now - last_start_time
			print("  [HUD REVEAL] %d. %s Bar fading in at t = %.2fs (Gap since previous: %.2fs)" % [i + 1, item.name, t_now, actual_gap])
		else:
			print("  [HUD REVEAL] %d. %s Bar fading in at t = %.2fs (Initial element)" % [i + 1, item.name, t_now])
		last_start_time = t_now
		
		if item.node:
			item.node.visible = true
			item.node.modulate.a = 0.0
			var tw = create_tween()
			tw.tween_property(item.node, "modulate:a", 1.0, fade_dur)
		
		if i < items.size() - 1:
			await get_tree().create_timer(gap).timeout
		else:
			await get_tree().create_timer(fade_dur).timeout
			
	hud_revealed = true
	_update_astronaut_bar_visibility()
	_update_outpost_bar_visibility()

func show_jetpack_online(duration: float = 3.0) -> void:
	jetpack_unlocked = true
	_notify_hud_activity()
	if jetpack_box:
		jetpack_box.visible = true
		var tw_box = create_tween()
		tw_box.tween_property(jetpack_box, "modulate:a", 1.0, 0.5)
	if jetpack_banner:
		jetpack_banner.visible = true
		jetpack_banner.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(jetpack_banner, "modulate:a", 1.0, 0.3)
		var hold_time = max(0.2, duration - 0.6)
		tw.tween_interval(hold_time)
		tw.tween_property(jetpack_banner, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func(): jetpack_banner.visible = false)

# -------------------------------------------------------------------------
# Popups, Screens & Inputs
# -------------------------------------------------------------------------
func show_artifact_card(m_name: String, lore: String, part: String) -> void:
	if lore_popup:
		lore_title.text = "🛰️ DISCOVERED: " + m_name.to_upper()
		lore_body.text = lore
		if part != "":
			lore_part.text = "🔧 RECOVERED PART: " + part + "\n(Installed in Mars Ascent Vehicle!)"
			lore_part.visible = true
		else:
			lore_part.text = "📦 Scientific data logged. Suit integrity restored with spare kit!"
			lore_part.visible = true
		
		lore_popup.visible = true
		lore_popup.modulate.a = 0.0
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		var tw = create_tween()
		tw.tween_property(lore_popup, "modulate:a", 1.0, 0.3)

func close_lore_popup() -> void:
	if lore_popup:
		var tw = create_tween()
		tw.tween_property(lore_popup, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func():
			lore_popup.visible = false
			if not pause_menu.visible and not death_screen.visible and not win_screen.visible:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		)

func _on_storm_warning(msg: String, is_active: bool) -> void:
	if not alert_banner or not alert_text:
		return
	if is_active:
		alert_text.text = msg
		alert_banner.visible = true
		alert_banner.modulate.a = 1.0
	else:
		alert_banner.visible = false

func show_victory_screen(sol_count: int = 1) -> void:
	if win_screen:
		win_screen.visible = true
		var title = win_screen.find_child("WinTitle", true, false) as Label
		if title:
			title.text = "Mission complete"
		var body = win_screen.find_child("WinBody", true, false) as Label
		if body:
			body.text = "Survived: Sol %d\nRepaired MAV Rocket and escaped Mars!" % sol_count
		var restart_btn = win_screen.find_child("WinRestartBtn", true, false) as Button
		if restart_btn:
			restart_btn.text = "Restart"
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_player_died(reason: String) -> void:
	if death_screen:
		death_screen.visible = true
		var title = death_screen.find_child("Title", true, false) as Label
		if title:
			title.text = "Crew lost"
		if death_reason_label:
			death_reason_label.text = reason
		var restart_btn = death_screen.find_child("RestartBtn", true, false) as Button
		if restart_btn:
			restart_btn.text = "Restart"
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func open_placement_dialog(pos: Vector3) -> void:
	recorded_placement_pos = pos
	_notify_hud_activity()
	if placement_coords:
		placement_coords.text = "Position: (%.1f, %.1f, %.1f) | Radius: %.1fm" % [pos.x, pos.y, pos.z, pos.length()]
	if placement_name_input:
		var reg = get_node_or_null("/root/PlacementRegistry")
		var default_idx = reg.next_marker_index if reg and "next_marker_index" in reg else 1
		placement_name_input.text = "marker_%d" % default_idx
		placement_name_input.select_all()
	if placement_dialog:
		placement_dialog.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Lock player input while typing so WASD does not walk
	var player = get_tree().root.find_child("Player", true, false)
	if player and "is_input_locked" in player:
		player.is_input_locked = true
	
	if placement_name_input:
		placement_name_input.grab_focus()

func close_placement_dialog() -> void:
	if placement_dialog and placement_dialog.visible:
		placement_dialog.visible = false
		if not pause_menu.visible and not death_screen.visible and not win_screen.visible and not (lore_popup and lore_popup.visible):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		# Restore player input
		var player = get_tree().root.find_child("Player", true, false)
		if player and "is_input_locked" in player:
			player.is_input_locked = false

func _on_save_placement_pressed() -> void:
	var entry_name = placement_name_input.text.strip_edges() if placement_name_input else ""
	if entry_name.is_empty():
		entry_name = "marker"
	
	# Sanitize name (lowercase, underscores)
	entry_name = entry_name.to_lower().replace(" ", "_")
	
	var reg = get_node_or_null("/root/PlacementRegistry")
	if reg and reg.has_method("save_player_placement"):
		reg.save_player_placement(entry_name, recorded_placement_pos)
	
	show_message("📍 Saved '%s' to placements.json!" % entry_name, 4.0)
	close_placement_dialog()

func toggle_pause() -> void:
	if pause_menu:
		pause_menu.visible = not pause_menu.visible
		if pause_menu.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if placement_dialog and placement_dialog.visible:
		if event is InputEventKey and event.pressed and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
			close_placement_dialog()
			get_viewport().set_input_as_handled()
			return
		return

	if lore_popup and lore_popup.visible:
		if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event.physical_keycode == KEY_E or event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER)):
			close_lore_popup()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_P or event.keycode == KEY_P):
		var player = get_tree().root.find_child("Player", true, false)
		if player and is_instance_valid(player):
			open_placement_dialog(player.global_position)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if not death_screen.visible and not win_screen.visible:
			toggle_pause()
