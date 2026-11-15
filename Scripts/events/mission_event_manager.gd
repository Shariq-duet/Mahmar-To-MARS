extends Node
class_name MissionEventManager

# mission_event_manager.gd
# Handles Mars mission events (Solar storms, dust storms, equipment failure, DONKI integration).

signal event_started(event_name: String, description: String)
signal event_ended(event_name: String)

@export var tutorial_sol_safe: bool = true
@export var event_interval_sec: float = 85.0 # Frequency of events after tutorial

var survival: RefCounted = null
var hud: CanvasLayer = null
var event_timer: float = 0.0
var active_event: String = ""
var active_event_duration: float = 0.0

var http_request: HTTPRequest = null
var using_real_donki: bool = false

# Available random events
enum EventType {
	SOLAR_STORM,
	DUST_STORM,
	EQUIPMENT_FAILURE,
	OXYGEN_LEAK,
	DELAYED_RESUPPLY
}

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_donki_request_completed)
	
	# Attempt to fetch real NASA DONKI Solar Flare data
	_fetch_nasa_donki()

func initialize(sys: RefCounted, hud_node: CanvasLayer) -> void:
	survival = sys
	hud = hud_node

func _physics_process(delta: float) -> void:
	if not survival:
		return
	
	# During Sol 1 (tutorial sol), no dangerous events trigger
	if tutorial_sol_safe and survival.current_sol <= 1:
		return
	
	if active_event != "":
		active_event_duration -= delta
		if active_event_duration <= 0.0:
			_end_current_event()
	else:
		event_timer += delta
		if event_timer >= event_interval_sec:
			event_timer = 0.0
			_trigger_random_event()

func _fetch_nasa_donki() -> void:
	# Fetch last 30 days of solar flare events from NASA DONKI
	var url = "https://api.nasa.gov/DONKI/FLR?api_key=DEMO_KEY"
	var err = http_request.request(url)
	if err != OK:
		print("DONKI Request failed to initiate, using simulated events.")
		using_real_donki = false

func _on_donki_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		var parse_err = json.parse(body.get_string_from_utf8())
		if parse_err == OK and json.data is Array and json.data.size() > 0:
			using_real_donki = true
			print("Connected to NASA DONKI! Active solar flare records fetched: ", json.data.size())
			return
	
	print("DONKI response code: %d, falling back to simulated solar flares." % response_code)
	using_real_donki = false

func _trigger_random_event() -> void:
	var event_id = randi() % 5
	match event_id:
		0: _trigger_solar_storm()
		1: _trigger_dust_storm()
		2: _trigger_oxygen_leak()
		3: _trigger_equipment_failure()
		4: _trigger_delayed_resupply()

func _trigger_solar_storm() -> void:
	active_event = "Solar Storm"
	active_event_duration = 35.0
	survival.solar_storm_active = true
	var source_str = "NASA DONKI LIVE FEED" if using_real_donki else "SIMULATED SOLAR PROBE"
	var msg = "⚠️ [%s] SOLAR FLARE DETECTED! Radiation rising. Seek shelter in Habitat Dome!" % source_str
	event_started.emit(active_event, msg)
	if hud and hud.has_method("show_alert"):
		hud.show_alert(msg, true)

func _trigger_dust_storm() -> void:
	active_event = "Dust Storm"
	active_event_duration = 45.0
	survival.dust_storm_active = true
	var msg = "🌪️ DUST STORM APPROACHING! Solar panel power output dropped by 80%."
	event_started.emit(active_event, msg)
	if hud and hud.has_method("show_alert"):
		hud.show_alert(msg, true)

func _trigger_oxygen_leak() -> void:
	active_event = "Life Support Malfunction"
	active_event_duration = 30.0
	survival.has_suit_breach = true
	var msg = "🚨 LIFE SUPPORT MALFUNCTION: Oxygen leak detected! Use a repair kit or return to shelter."
	event_started.emit(active_event, msg)
	if hud and hud.has_method("show_alert"):
		hud.show_alert(msg, true)

func _trigger_equipment_failure() -> void:
	active_event = "Power Grid Trip"
	active_event_duration = 30.0
	survival.power = max(0.0, survival.power - 25.0)
	var msg = "⚡ BASE POWER GRID FAILURE: Inverter tripped! Lost 25% battery reserve."
	event_started.emit(active_event, msg)
	if hud and hud.has_method("show_alert"):
		hud.show_alert(msg, true)

func _trigger_delayed_resupply() -> void:
	active_event = "Delayed Resupply"
	active_event_duration = 40.0
	survival.water = max(10.0, survival.water - 15.0)
	survival.food = max(10.0, survival.food - 15.0)
	var msg = "📦 CARGO DELAY: Earth resupply delayed by orbital geometry. Rationing water & food!"
	event_started.emit(active_event, msg)
	if hud and hud.has_method("show_alert"):
		hud.show_alert(msg, true)

func _end_current_event() -> void:
	if active_event == "Solar Storm":
		survival.solar_storm_active = false
		if hud and hud.has_method("show_alert"):
			hud.show_alert("☀️ Solar flare passed. Radiation levels stabilizing.", false)
	elif active_event == "Dust Storm":
		survival.dust_storm_active = false
		if hud and hud.has_method("show_alert"):
			hud.show_alert("☀️ Dust storm cleared. Solar arrays back to full power.", false)
	elif active_event == "Life Support Malfunction":
		survival.has_suit_breach = (survival.suit_integrity < 25.0)
		if hud and hud.has_method("show_alert"):
			hud.show_alert("✅ Life support pressure stabilized.", false)
	
	event_ended.emit(active_event)
	active_event = ""
