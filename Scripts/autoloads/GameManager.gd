extends Node

# Autoload: GameManager
# Manages active planets, player reference, input fallbacks, session inventory and state.

var planets: Array[Node3D] = []
var player: CharacterBody3D = null
var player_in_ship: bool = false

# Session persistence for inventory and machine repair states
signal inventory_changed

var filter_core: int = 0:
	set(val):
		filter_core = val
		inventory_changed.emit()

var power_unit_core: int = 0:
	set(val):
		power_unit_core = val
		inventory_changed.emit()

var water_ice: int = 0:
	set(val):
		water_ice = val
		inventory_changed.emit()

var crate_collected: bool = false
var scrubber_repaired: bool = false
var power_core_collected: bool = false
var power_unit_repaired: bool = false
var water_repaired: bool = false
var cargo_filter_core_collected: bool = false
var cargo_power_core_collected: bool = false
var discovered_pois: Dictionary = {}

func _ready() -> void:
	_setup_default_inputs()
	# Ensure cores start at 0 for each session
	filter_core = 0
	power_unit_core = 0
	water_ice = 0

func reset_session() -> void:
	crate_collected = false
	scrubber_repaired = false
	power_core_collected = false
	power_unit_repaired = false
	water_repaired = false
	cargo_filter_core_collected = false
	cargo_power_core_collected = false
	discovered_pois.clear()
	filter_core = 0
	power_unit_core = 0
	water_ice = 0
	inventory_changed.emit()

func add_water_ice(amount: int = 1) -> void:
	water_ice += amount

func add_filter_core(amount: int = 1) -> void:
	filter_core += amount

func use_filter_core(amount: int = 1) -> bool:
	if filter_core >= amount:
		filter_core -= amount
		return true
	return false

func add_power_core(amount: int = 1) -> void:
	power_unit_core += amount

func use_power_core(amount: int = 1) -> bool:
	if power_unit_core >= amount:
		power_unit_core -= amount
		return true
	return false

func is_poi_discovered(poi_id: String) -> bool:
	return discovered_pois.get(poi_id, false)

func mark_poi_discovered(poi_id: String) -> void:
	discovered_pois[poi_id] = true

func register_planet(planet: Node3D) -> void:
	if not planets.has(planet):
		planets.append(planet)

func unregister_planet(planet: Node3D) -> void:
	planets.erase(planet)

func get_nearest_planet(from_pos: Vector3) -> Node3D:
	if planets.is_empty():
		return null
	var nearest: Node3D = null
	var min_dist: float = INF
	for p in planets:
		if is_instance_valid(p):
			var dist = from_pos.distance_squared_to(p.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest = p
	return nearest

# Programmatic fallback to ensure keys are mapped if project.godot doesn't have them
func _setup_default_inputs() -> void:
	_ensure_key_action("move_forward", [KEY_W, KEY_UP])
	_ensure_key_action("move_back", [KEY_S, KEY_DOWN])
	_ensure_key_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_key_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_key_action("jump", [KEY_SPACE])
	_ensure_key_action("run", [KEY_SHIFT])
	_ensure_key_action("interact", [KEY_E])
	_ensure_key_action("pause", [KEY_ESCAPE])

func _ensure_key_action(action_name: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for code in keycodes:
		var has_event = false
		for ev in InputMap.action_get_events(action_name):
			if ev is InputEventKey and ev.physical_keycode == code:
				has_event = true
				break
		if not has_event:
			var event = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action_name, event)
