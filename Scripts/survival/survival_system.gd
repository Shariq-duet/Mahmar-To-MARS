extends Resource
class_name SurvivalSystem

# survival_system.gd
# Sol 1 Mars Survival Mechanics:
# - Oxygen: starts 100. Drains 0.05/s inside pod, 1.5x outside, 3.0x while jetpacking.
#   Repaired scrubber multiplies drain by 0.5. Zero power doubles drain.
# - Power: starts 100. Generation follows sun: peak 2.0/s at noon, 0 at night.
#   Dust storm halves generation for 60s. Repaired power unit adds 50% generation.
#   Consumption is 0.8/s. Scrubber repair costs 10 power.
# - Water: starts 100. Drains 0.03/s. Each water_ice pickup adds 10, capped at 100.
# - Food: starts 100. Drains 10 per sol. Displayed on HUD.
# - Health: regenerates 1/s inside pod when oxygen, power, water, food are all > 20.
#   Drains 2/s when ANY of them is 0.
# - Suit Integrity: starts 100. Drops 2/s outside during a storm. Restores inside pod.
# - Radiation & Storms:
#   * Sol 2 Dust Storm: lasts 60s, halving power generation.
#   * Sol 3 Solar Radiation Storm: warns 30s ahead, lasts 90s.
#     Health drains 3/s outside pod, 0 inside pod.
# - Failure: if health reaches 0, emits player_died("Crew lost").
# - Stats printed once per sol.

signal health_changed(value: float)
signal oxygen_changed(value: float)
signal power_changed(value: float)
signal water_changed(value: float)
signal food_changed(value: float)
signal suit_changed(value: float)
signal radiation_changed(value: float)
signal storm_warning(message: String, is_active: bool)
signal player_died(reason: String)
signal sol_advanced(current_sol: int)

# Max constant
const MAX_VAL: float = 100.0

@export_group("Sol Timing")
@export var sol_duration_sec: float = 600.0 # 1 Mars Sol = 10 real minutes (600s)
@export var current_sol: int = 1
@export var time_in_sol: float = 0.0

@export_group("Oxygen")
@export var oxygen: float = 100.0
@export var o2_drain_inside: float = 0.05            # 0.05 per second inside pod
@export var base_o2_rate: float:                     # Compatibility getter/setter for pod repair systems
	get:
		return o2_drain_inside
	set(val):
		o2_drain_inside = val
@export var o2_outside_mult: float = 1.5            # 1.5x outside pod
@export var o2_jetpack_mult: float = 3.0            # 3.0x while jetpacking
@export var o2_scrubber_repair_mult: float = 0.5    # Repaired scrubber: 0.5x drain
@export var o2_zero_power_mult: float = 2.0         # Power at 0 doubles drain

@export_group("Power")
@export var power: float = 100.0
@export var solar_power_gain: float = 0.0            # Legacy property alias
@export var base_power_drain: float:                 # Compatibility getter/setter
	get:
		return power_consumption
	set(val):
		power_consumption = val
@export var power_peak_solar: float = 2.0           # Peak 2.0/s at noon, 0 at night
@export var power_consumption: float = 0.8          # Consumption is 0.8/s
@export var power_repaired_mult: float = 1.5        # Repaired power unit adds 50% (+0.5 = 1.5x)
@export var power_dust_storm_mult: float = 0.5      # Dust storm halves generation
@export var scrubber_repair_power_cost: float = 10.0 # Scrubber repair costs 10 power

@export_group("Water")
@export var water: float = 100.0
@export var water_drain_rate: float = 0.03          # Drains 0.03 per second
@export var water_ice_replenish: float = 10.0       # Each water_ice pickup adds 10, capped at 100

@export_group("Food")
@export var food: float = 100.0
@export var food_drain_per_sol: float = 10.0        # Drains 10 per sol

@export_group("Health")
@export var health: float = 100.0
@export var health_regen_rate: float = 1.0          # Regenerates 1/s inside pod when all > 20
@export var health_drain_rate: float = 2.0          # Drains 2/s when any is 0
@export var health_regen_threshold: float = 20.0

@export_group("Suit Integrity")
@export var suit_integrity: float = 100.0
@export var suit_storm_drain: float = 2.0           # Drops 2/s outside during a storm
@export var suit_restore_rate: float = 5.0          # Restores inside pod

@export_group("Radiation & Solar Storm (Sol 3)")
@export var solar_storm_sol: int = 3
@export var solar_storm_warn_time: float = 30.0     # Warns 30s ahead
@export var solar_storm_duration: float = 90.0      # Lasts 90s
@export var radiation_health_drain: float = 3.0     # Outside pod: health drains 3/s; inside: 0

@export_group("Dust Storm (Sol 2)")
@export var dust_storm_sol: int = 2
@export var dust_storm_start_time: float = 10.0     # Starts 10s into Sol 2
@export var dust_storm_duration: float = 60.0       # Lasts 60s, halving power generation

# Runtime states
var is_in_shelter: bool = false
var is_shield_active: bool = false
var is_sprinting: bool = false
var is_jetpacking: bool = false
var is_scrubber_repaired: bool = false
var is_power_unit_repaired: bool = false
var sun_factor: float = 1.0 # 0.0 at night, 1.0 at noon

var dust_storm_active: bool = false
var solar_storm_warning_active: bool = false
var solar_storm_active: bool = false
var is_alive: bool = true

var last_printed_sol: int = -1

func tick(delta: float) -> void:
	if not is_alive:
		return
	
	_update_sol_cycle(delta)
	_update_storms(delta)
	_update_oxygen(delta)
	_update_power(delta)
	_update_water(delta)
	_update_food(delta)
	_update_suit_and_health(delta)
	
	if current_sol != last_printed_sol:
		last_printed_sol = current_sol
		print_survival_stats()

func _update_sol_cycle(delta: float) -> void:
	time_in_sol += delta
	if time_in_sol >= sol_duration_sec:
		time_in_sol -= sol_duration_sec
		current_sol += 1
		sol_advanced.emit(current_sol)

func _update_storms(_delta: float) -> void:
	# Sol 2 Dust Storm (lasts 60s)
	if current_sol == dust_storm_sol:
		var in_dust = (time_in_sol >= dust_storm_start_time and time_in_sol < (dust_storm_start_time + dust_storm_duration))
		if in_dust and not dust_storm_active:
			dust_storm_active = true
			storm_warning.emit("⚠️ DUST STORM ACTIVE: Solar generation reduced by 50%!", true)
			print("[WEATHER] Sol %d Dust Storm started (duration: %.0fs, power gen halved)" % [current_sol, dust_storm_duration])
		elif not in_dust and dust_storm_active:
			dust_storm_active = false
			storm_warning.emit("", false)
			print("[WEATHER] Sol %d Dust Storm passed" % current_sol)
	else:
		dust_storm_active = false
	
	# Sol 3 Solar Storm (warns 30s ahead, lasts 90s)
	if current_sol == solar_storm_sol:
		var storm_start = 60.0
		var warn_start = storm_start - solar_storm_warn_time
		var storm_end = storm_start + solar_storm_duration
		
		# Warning period (30s before)
		if time_in_sol >= warn_start and time_in_sol < storm_start:
			if not solar_storm_warning_active and not solar_storm_active:
				solar_storm_warning_active = true
				var rem = int(ceil(storm_start - time_in_sol))
				storm_warning.emit("⚠️ SOLAR RADIATION STORM WARNING: Incoming in %ds! Seek shelter inside pod!" % rem, true)
				print("[WEATHER] Sol %d Solar Storm Warning: incoming in %.0fs!" % [current_sol, solar_storm_warn_time])
		else:
			solar_storm_warning_active = false
		
		# Active period (90s duration)
		if time_in_sol >= storm_start and time_in_sol < storm_end:
			if not solar_storm_active:
				solar_storm_active = true
				storm_warning.emit("⚠️ SOLAR RADIATION STORM ACTIVE: High radiation! Pod shelter protects crew!", true)
				print("[WEATHER] Sol %d Solar Storm ACTIVE: lasting %.0fs (Health drain 3/s outside pod, 0 inside)" % [current_sol, solar_storm_duration])
		else:
			if solar_storm_active:
				solar_storm_active = false
				storm_warning.emit("", false)
				print("[WEATHER] Sol %d Solar Storm subsided." % current_sol)
	else:
		solar_storm_warning_active = false
		solar_storm_active = false

func _update_oxygen(delta: float) -> void:
	var drain = o2_drain_inside
	if not is_in_shelter:
		drain *= o2_outside_mult
	if is_jetpacking:
		drain *= o2_jetpack_mult
	if is_scrubber_repaired:
		drain *= o2_scrubber_repair_mult
	if power <= 0.0:
		drain *= o2_zero_power_mult
	
	oxygen = max(0.0, oxygen - drain * delta)
	oxygen_changed.emit(oxygen)

func _update_power(delta: float) -> void:
	# Solar generation follows sun: peak 2.0/s at noon, 0 at night
	var gen = max(0.0, sun_factor) * power_peak_solar
	if is_power_unit_repaired:
		gen *= power_repaired_mult
	if dust_storm_active:
		gen *= power_dust_storm_mult
	
	var net = gen - power_consumption
	power = clampf(power + net * delta, 0.0, MAX_VAL)
	power_changed.emit(power)

func _update_water(delta: float) -> void:
	water = max(0.0, water - water_drain_rate * delta)
	water_changed.emit(water)

func _update_food(delta: float) -> void:
	var rate = food_drain_per_sol / sol_duration_sec
	food = max(0.0, food - rate * delta)
	food_changed.emit(food)

func _update_suit_and_health(delta: float) -> void:
	# Suit integrity
	if is_in_shelter:
		suit_integrity = min(MAX_VAL, suit_integrity + suit_restore_rate * delta)
	elif dust_storm_active or solar_storm_active:
		suit_integrity = max(0.0, suit_integrity - suit_storm_drain * delta)
	suit_changed.emit(suit_integrity)
	
	# Health rules
	var is_depleted = (oxygen <= 0.0 or power <= 0.0 or water <= 0.0 or food <= 0.0)
	if is_depleted:
		health = max(0.0, health - health_drain_rate * delta)
	elif is_in_shelter and oxygen > health_regen_threshold and power > health_regen_threshold and water > health_regen_threshold and food > health_regen_threshold:
		health = min(MAX_VAL, health + health_regen_rate * delta)
	
	# Solar storm radiation damage outside pod (3/s)
	if solar_storm_active and not is_in_shelter:
		health = max(0.0, health - radiation_health_drain * delta)
	
	health_changed.emit(health)
	
	if health <= 0.0 and is_alive:
		is_alive = false
		var cause = "Life support failure"
		if oxygen <= 0.0: cause = "Oxygen depleted"
		elif solar_storm_active and not is_in_shelter: cause = "Lethal solar radiation"
		elif water <= 0.0: cause = "Dehydration"
		elif power <= 0.0: cause = "Life support system freeze"
		print("[SURVIVAL] Crew lost: %s" % cause)
		player_died.emit("Crew lost: " + cause)

func add_water_ice() -> void:
	water = min(MAX_VAL, water + water_ice_replenish)
	water_changed.emit(water)
	print("[SURVIVAL] Water Ice added: +%.1f -> Water: %.1f%%" % [water_ice_replenish, water])

func deduct_power(amount: float) -> bool:
	if power >= amount:
		power = max(0.0, power - amount)
		power_changed.emit(power)
		return true
	return false

func print_survival_stats() -> void:
	print("\n==================================================")
	print("SURVIVAL VITALS (SOL %d, Time: %.1fs / %.1fs)" % [current_sol, time_in_sol, sol_duration_sec])
	print("==================================================")
	print("  Health:         %5.1f / 100.0" % health)
	print("  Oxygen:         %5.1f / 100.0 (Scrubber Repaired: %s)" % [oxygen, is_scrubber_repaired])
	print("  Power:          %5.1f / 100.0 (Power Unit Repaired: %s, Sun Factor: %.2f)" % [power, is_power_unit_repaired, sun_factor])
	print("  Water:          %5.1f / 100.0" % water)
	print("  Food:           %5.1f / 100.0 (Drain: %.1f/sol)" % [food, food_drain_per_sol])
	print("  Suit Integrity: %5.1f / 100.0" % suit_integrity)
	print("  Shelter:        %s | Jetpacking: %s" % ["Inside Pod" if is_in_shelter else "Outside", is_jetpacking])
	print("  Dust Storm:     %s | Solar Storm: %s" % [dust_storm_active, solar_storm_active])
	print("==================================================\n")
