@tool
extends Node3D

# world.gd
# Main world orchestrator:
# - Spawns Return Vehicle (Rocket) directly at the landing point (no weird pad, scaled imposing size).
# - Spawns player at the landing site, 4.5m in front of the rocket, facing the pod.
# - Spawns Crashed Survival Pod using the downloaded Sci-Fi Pod model from Assets/sci-fi_pod_collection.glb via PodSpawn Marker3D.
# - Provides 3D Editor Planet Preview and auto-snapping for easy pod placement.
# - Spawns Geological Cave Environments in Distant Mathematical Pit Craters.
# - Spawns 6 historic NASA mission artifacts on crater rims.
# - Live Signal Tracker (Outer Wilds point-to-point exploration).
# - Drives Day/Night Cycle with NASA Mars sky & Phobos/Deimos orbits.

const SurvivalSystem = preload("res://Scripts/survival/survival_system.gd")
const CrashedPodScene = preload("res://Scenes/machines/crashed_pod.tscn")
const ReturnVehicleScene = preload("res://Scenes/machines/return_vehicle.tscn")
const ArtifactScene = preload("res://Scenes/artifacts/artifact_marker.tscn")
const PavonisTubeScene = preload("res://Scenes/planet/caves/pavonis_tube.tscn")
const NoctisFissureScene = preload("res://Scenes/planet/caves/noctis_fissure.tscn")
const ElysiumCavernScene = preload("res://Scenes/planet/caves/elysium_cavern.tscn")
const CrashBaseScene = preload("res://Scenes/machines/crash_base.tscn")
const RoverSiteScene = preload("res://Scenes/machines/rover_site.tscn")
const SpaceCargoScene = preload("res://Scenes/machines/space_cargo.tscn")
const WaterIcePickupScene = preload("res://Scenes/machines/water_ice_pickup.tscn")
const EventManagerScript = preload("res://Scripts/events/mission_event_manager.gd")

@export_group("Pod Placement")
@export var pod_scene: PackedScene = preload("res://Scenes/machines/crashed_pod.tscn"):
	set(val):
		pod_scene = val
		if Engine.is_editor_hint():
			_update_editor_placement()

@export var pod_position: Vector3 = Vector3(-30.9295, 499.9644, -30.9295):
	set(val):
		pod_position = val
		if Engine.is_editor_hint() and has_node("PodSpawn"):
			var marker = get_node("PodSpawn") as Marker3D
			if marker and marker.position != val:
				marker.position = val
		if Engine.is_editor_hint():
			_update_editor_placement()

@export var pod_rotation_y: float = 0.0:
	set(val):
		pod_rotation_y = val
		if Engine.is_editor_hint() and has_node("PodSpawn"):
			var marker = get_node("PodSpawn") as Marker3D
			if marker and marker.rotation.y != val:
				marker.rotation.y = val
		if Engine.is_editor_hint():
			_update_editor_placement()

@export var snap_pod_to_terrain: bool = false:
	set(val):
		if Engine.is_editor_hint():
			_snap_marker_to_terrain()

@onready var planet: Node3D = $ProceduralMars
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var day_night_system: DayNightCycle = $DayNightSystem
@onready var pod_spawn: Marker3D = $PodSpawn if has_node("PodSpawn") else null

var survival := SurvivalSystem.new()
var event_manager: Node = null

var shelter_pos := Vector3.ZERO
var cave_pos := Vector3.ZERO
var crashed_pod_node: Area3D = null
var return_vehicle_node: Area3D = null
var crash_base_node: Node3D = null
var rover_site_node: Node3D = null
var cargo_site_node: Node3D = null
var water_ice_pickups_root: Node3D = null
var lava_tube_node: Area3D = null
var cave_defs: Array = [
	{"name": "Noctis Labyrinthus Chasm", "short": "Noctis Chasm", "depth": 3.0},
	{"name": "Elysium Magma Cavern", "short": "Elysium Cavern", "depth": 3.0}
]

var _last_marker_pos: Vector3 = Vector3.ZERO
var _last_marker_rot_y: float = 0.0

# Guidance, Beacons & POIs
var registry_pois: Array[Dictionary] = []
var beacon_scan_timer: float = 0.0
var current_objective_name: String = "Reach Survival Pod"
var current_objective_pos: Variant = null

# Point-to-Point Exploration Tracker (Outer Wilds style)
var tracked_pois: Array[Dictionary] = []
var signal_scan_timer: float = 0.0
var clean_recording_mode: bool = false

# Historical NASA mission data for crater rim discovery
const HISTORIC_MISSIONS = [
	{
		"crater_idx": 4,
		"name": "Mariner 4 (1965)",
		"short_name": "Mariner 4",
		"lore": "Mariner 4 performed humanity's first successful Mars flyby, returning the first 22 close-up photographs showing ancient lunar-like impact craters.",
		"part": "Navigation Gyroscope"
	},
	{
		"crater_idx": 9,
		"name": "Viking 1 (1976)",
		"short_name": "Viking 1",
		"lore": "Viking 1 became the first spacecraft to safely touch down on Mars and operate for over 6 Earth years (2,245 Sols), sending back color photos and soil analysis.",
		"part": "Heat Shield Ceramic Tile"
	},
	{
		"crater_idx": 15,
		"name": "Opportunity Rover (2004)",
		"short_name": "Opportunity",
		"lore": "Opportunity was designed for a 90-sol mission but drove for 14.5 Earth years and over 45 km, discovering hematite spherules ('blueberries') proving past liquid water.",
		"part": "Solar Array Relay"
	},
	{
		"crater_idx": 23,
		"name": "Curiosity Rover (2012)",
		"short_name": "Curiosity",
		"lore": "Curiosity is a car-sized robot exploring Gale Crater. It discovered ancient freshwater lake environments containing organic carbon molecules necessary for life.",
		"part": "Methane Fuel Injector"
	},
	{
		"crater_idx": 31,
		"name": "Sojourner (1997)",
		"short_name": "Sojourner",
		"lore": "Sojourner was humanity's first wheeled Mars rover. It was no larger than a microwave oven and proved that robotic rovers could navigate Martian boulders.",
		"part": "" # Scientific data + suit repair kit
	},
	{
		"crater_idx": 42,
		"name": "InSight Lander (2018)",
		"short_name": "InSight",
		"lore": "InSight used an ultra-sensitive seismometer to detect over 1,300 'marsquakes', successfully mapping the crust, mantle, and liquid metallic core of Mars.",
		"part": "" # Scientific data + suit repair kit
	}
]

func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor_pod_preview()
		return

	# Initialize survival vitals
	survival.power = 100.0
	
	if planet and player and planet.has_method("get_surface_point"):
		_spawn_world_entities()

	# Connect Day/Night celestial cycle
	if day_night_system:
		day_night_system.set_player_reference(player)

	# Connect Jetpack fuel HUD gauge
	if player and player.has_signal("jetpack_fuel_changed") and hud:
		player.jetpack_fuel_changed.connect(hud.update_jetpack_fuel)

	# Bind HUD
	if hud and hud.has_method("bind_survival_system"):
		hud.bind_survival_system(survival)
	
	# Initialize Mission Event Manager
	event_manager = EventManagerScript.new()
	event_manager.name = "MissionEventManager"
	add_child(event_manager)
	event_manager.initialize(survival, hud)

	# Sol 1 Welcome Guidance
	get_tree().create_timer(1.2).timeout.connect(func():
		if hud and hud.has_method("show_alert"):
			hud.show_alert("🚀 Sol 1 Crash Landing: You are wounded! Walk forward to the Survival Pod to stabilize.", false)
	)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_process_editor_tool()

func _ensure_editor_planet_preview() -> void:
	var prev_planet = get_node_or_null("_EditorPlanetPreview")
	if not prev_planet:
		var p_mesh = MeshInstance3D.new()
		p_mesh.name = "_EditorPlanetPreview"
		var s = SphereMesh.new()
		s.radius = 500.0
		s.height = 1000.0
		s.radial_segments = 64
		s.rings = 32
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.82, 0.35, 0.18, 1.0)
		mat.roughness = 0.95
		s.material = mat
		p_mesh.mesh = s
		add_child(p_mesh)
		p_mesh.owner = null

func _setup_editor_pod_preview() -> void:
	_ensure_editor_planet_preview()
	var marker = get_node_or_null("PodSpawn") as Marker3D
	if marker:
		_last_marker_pos = marker.position
		_last_marker_rot_y = marker.rotation.y
		pod_position = marker.position
		pod_rotation_y = marker.rotation.y
	_update_editor_placement()

func _snap_marker_to_terrain() -> void:
	var marker = get_node_or_null("PodSpawn") as Marker3D
	if not marker:
		return
	var p = get_node_or_null("ProceduralMars")
	if p and p.has_method("get_surface_point"):
		var dir = marker.global_position.normalized()
		var surf = p.get_surface_point(dir)
		marker.global_position = surf
		pod_position = marker.position
		print("[EDITOR TOOL] Snapped PodSpawn marker to terrain surface at: %s (Height: %.2f m)" % [surf, surf.length()])
		_update_editor_placement()

func _process_editor_tool() -> void:
	_ensure_editor_planet_preview()
	var marker = get_node_or_null("PodSpawn") as Marker3D
	if not marker:
		return
	if marker.position != _last_marker_pos or marker.rotation.y != _last_marker_rot_y:
		_last_marker_pos = marker.position
		_last_marker_rot_y = marker.rotation.y
		
		# Auto-snap altitude to Mars terrain surface with 0.35m grounding offset so it never floats
		var p = get_node_or_null("ProceduralMars")
		if p and p.has_method("get_surface_point") and marker.position.length_squared() > 100.0:
			var norm = marker.global_position.normalized()
			var surf = p.get_surface_point(norm)
			var target_pos = surf - norm * 0.35
			var delta_h = abs(marker.global_position.length() - target_pos.length())
			if delta_h > 0.05:
				marker.global_position = target_pos
				_last_marker_pos = marker.position
		
		pod_position = marker.position
		pod_rotation_y = marker.rotation.y
		_update_editor_placement()

func _update_editor_placement() -> void:
	if not Engine.is_editor_hint():
		return
	var marker = get_node_or_null("PodSpawn") as Marker3D
	if not marker or not pod_scene:
		return
	var preview = get_node_or_null("_EditorPodPreview") as Node3D
	if not preview:
		preview = pod_scene.instantiate() as Node3D
		preview.name = "_EditorPodPreview"
		add_child(preview)
		preview.owner = null
	
	var p = get_node_or_null("ProceduralMars")
	var target_pos = marker.global_position
	var normal = target_pos.normalized() if target_pos.length_squared() > 1.0 else Vector3.UP
	if p and p.has_method("get_surface_point"):
		var surf = p.get_surface_point(normal)
		if surf.length() > 10.0:
			target_pos = surf
			normal = (surf - p.global_position).normalized()
	_align_to_surface(preview, target_pos, normal, 0.0)
	preview.rotate_object_local(Vector3.UP, pod_rotation_y)
	if "root_scale" in preview:
		preview.scale = preview.root_scale
	else:
		preview.scale = Vector3(2.184125, 0.62735, 2.21257)

func _spawn_world_entities() -> void:
	# Clean up any editor preview nodes
	var editor_preview = get_node_or_null("_EditorPodPreview")
	if editor_preview:
		editor_preview.queue_free()
	var editor_planet = get_node_or_null("_EditorPlanetPreview")
	if editor_planet:
		editor_planet.queue_free()

	# 1. Landing Site & Rocket Placement
	var spawn_dir = Vector3.UP
	var landing_pt: Vector3 = planet.get_surface_point(spawn_dir)
	var landing_normal = (landing_pt - planet.global_position).normalized()

	# Spawn Rocket right at the exact landing site (no weird pad, sits on landing fins)
	return_vehicle_node = ReturnVehicleScene.instantiate()
	add_child(return_vehicle_node)
	_align_to_surface(return_vehicle_node, landing_pt, landing_normal, 0.0)
	return_vehicle_node.launch_success.connect(_on_mav_launch_success)

	tracked_pois.append({
		"id": "mav",
		"name": "Rocket Ship",
		"icon": "🚀",
		"pos": landing_pt,
		"active": true
	})

	# Spawn Player directly at the landing site (4.5m in front of rocket, facing toward the pod from registry)
	var reg_temp = get_node_or_null("/root/PlacementRegistry")
	var target_pod_pos: Vector3 = reg_temp.get_position("pod") if (reg_temp and reg_temp.has_method("get_position") and reg_temp.get_position("pod") != null) else pod_position
	var to_pod_vec = target_pod_pos - landing_pt
	var player_offset_dir = (to_pod_vec - landing_normal * to_pod_vec.dot(landing_normal)).normalized()
	if player_offset_dir.length_squared() < 0.01:
		player_offset_dir = Vector3(0, 0, 1).normalized()
	var player_dir = (landing_pt + player_offset_dir * 4.5).normalized()
	var player_pt = planet.get_surface_point(player_dir)
	var player_normal = (player_pt - planet.global_position).normalized()
	player.global_position = player_pt
	var to_pod_tangent = (target_pod_pos - player_pt)
	to_pod_tangent = (to_pod_tangent - player_normal * to_pod_tangent.dot(player_normal)).normalized()
	var player_right = to_pod_tangent.cross(player_normal).normalized()
	player.global_transform.basis = Basis(player_right, player_normal, -to_pod_tangent).orthonormalized()
	shelter_pos = player_pt
	if player.has_method("start_cinematic_lying_intro"):
		player.start_cinematic_lying_intro()
	print("[SPAWN] Rocket spawned at landing site: ", landing_pt)
	print("[SPAWN] Player spawned beside rocket at landing site: ", player.global_position)
	print("[SPAWN] Distance from player to rocket: %.2f m" % player.global_position.distance_to(landing_pt))

	# 2. Spawn Crashed Survival Pod using PlacementRegistry
	var reg = get_node_or_null("/root/PlacementRegistry")
	var reg_pod_pos = reg.get_position("pod") if reg else null
	var pod_pt: Vector3 = reg_pod_pos if reg_pod_pos != null else planet.get_surface_point(pod_position.normalized())
	var marker_pos = pod_pt
	var marker_rot_y = pod_rotation_y
	var pod_entry = reg.get_entry("pod") if reg else {}
	if pod_entry.has("yaw"):
		marker_rot_y = deg_to_rad(float(pod_entry.get("yaw", 0.0)))
	elif pod_spawn:
		marker_rot_y = pod_spawn.rotation.y
	if pod_spawn:
		pod_spawn.global_position = pod_pt
	
	var pod_dir = (pod_pt - planet.global_position).normalized()
	var pod_normal = (pod_pt - planet.global_position).normalized()

	var marker_height = (marker_pos - planet.global_position).length()
	var surface_height = (pod_pt - planet.global_position).length()
	var height_diff = abs(marker_height - surface_height)

	print("\n==================================================")
	print("CRASHED POD PLACEMENT & SURFACE SNAPPING")
	print("==================================================")
	print("PodSpawn Marker Position:    %s" % marker_pos)
	print("PodSpawn Marker Height:      %.4f m" % marker_height)
	print("Snapped Surface Point:       %s" % pod_pt)
	print("Snapped Surface Height:      %.4f m" % surface_height)
	print("Difference (Marker vs Surf): %.4f units (target <= 0.5 units)" % height_diff)
	print("Surface Snapping Status:     %s" % ("PASS" if height_diff <= 0.5 else "FAIL"))
	print("==================================================\n")

	assert(height_diff <= 0.5, "Difference between marker height and surface height must be <= 0.5 units! (got %.4f)" % height_diff)

	var effective_scene = pod_scene if pod_scene else CrashedPodScene
	crashed_pod_node = effective_scene.instantiate()
	add_child(crashed_pod_node)
	_align_to_surface(crashed_pod_node, pod_pt, pod_normal, 0.0)
	crashed_pod_node.rotate_object_local(Vector3.UP, marker_rot_y)
	if "root_scale" in crashed_pod_node:
		crashed_pod_node.scale = crashed_pod_node.root_scale
	else:
		crashed_pod_node.scale = Vector3(2.184125, 0.62735, 2.21257)

	if crashed_pod_node.has_method("setup_surroundings"):
		crashed_pod_node.setup_surroundings(planet)
	if crashed_pod_node.has_method("align_floor_to_hatch"):
		crashed_pod_node.align_floor_to_hatch()

	# Confirm trigger area and scaling
	var col_shape = crashed_pod_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var door_node = crashed_pod_node.find_child("Line0022", true, false) as Node3D
	print("\n==================================================")
	print("CRASHED POD SCALING & TRIGGER ALIGNMENT")
	print("Pod Global Scale:                    %s" % crashed_pod_node.global_transform.basis.get_scale())
	var floor_body = crashed_pod_node.get_node_or_null("InteriorFloor")
	if floor_body:
		var floor_col = floor_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if floor_col and floor_col.shape is BoxShape3D:
			var fs = floor_col.shape.size
			var s = crashed_pod_node.scale
			print("Interior Floor Bounding Size:        Width X = %.2f m, Depth Z = %.2f m, Thickness Y = %.2f m" % [fs.x * s.x, fs.z * s.z, fs.y * s.y])
	if col_shape:
		print("Pod Trigger Global Position:         %s" % col_shape.global_position)
	if door_node:
		print("Hatch Global Position:               %s" % door_node.global_position)
		if col_shape:
			var hatch_dist = col_shape.global_position.distance_to(door_node.global_position)
			print("Trigger vs Hatch Distance:           %.4f units (target <= 1.0 unit)" % hatch_dist)
			assert(hatch_dist <= 1.0, "Trigger must match hatch position within 1 unit!")
	var base_pt = crashed_pod_node.to_global(Vector3(0.0, 0.0, 0.0))
	var base_surf_diff = abs((base_pt - planet.global_position).length() - (pod_pt - planet.global_position).length())
	print("Pod Base vs Surface Difference:      %.4f units (target <= 0.5 units)" % base_surf_diff)
	assert(base_surf_diff <= 0.5, "Pod base height difference must be <= 0.5 units!")
	print("==================================================\n")

	crashed_pod_node.body_entered.connect(_on_pod_body_entered)
	crashed_pod_node.solar_deployed.connect(_on_pod_solar_deployed)
	crashed_pod_node.survival_ref = survival
	crashed_pod_node.scrubber_repaired_signal.connect(_on_scrubber_repaired)

	# 2b. Spawn Crash Base from PlacementRegistry
	var crash_pos = reg.get_position("crash_base") if reg else null
	if crash_pos == null:
		crash_pos = planet.get_surface_point(Vector3(-0.090302, 0.993322, 0.070235).normalized())
	var crash_norm = (crash_pos - planet.global_position).normalized()
	crash_base_node = CrashBaseScene.instantiate()
	add_child(crash_base_node)
	_align_to_surface(crash_base_node, crash_pos, crash_norm, 0.0)
	print("[SPAWN] Crash Base spawned at: ", crash_pos)

	# 2c. Spawn Rover Site from PlacementRegistry
	var rover_pos = reg.get_position("rover_site") if reg else null
	if rover_pos == null:
		rover_pos = planet.get_surface_point(Vector3(-0.0805, 0.9723, 0.2192).normalized())
	var rover_norm = (rover_pos - planet.global_position).normalized()
	rover_site_node = RoverSiteScene.instantiate()
	add_child(rover_site_node)
	_align_to_surface(rover_site_node, rover_pos, rover_norm, 0.0)
	print("[SPAWN] Rover Site spawned at: ", rover_pos)

	# 2d. Resolve Noctis Chasm and Water Deposit positions from PlacementRegistry
	var noctis_pos = reg.get_position("noctis_chasm") if reg else null
	if noctis_pos == null:
		noctis_pos = planet.get_cave_pit_surface_point(0)

	var water_pos = reg.get_position("water_deposit") if reg else null
	if water_pos == null:
		water_pos = planet.get_surface_point(Vector3(0.0511, 0.9760, 0.2115).normalized())

	# 2e. Spawn Cargo Site from PlacementRegistry
	var cargo_pos = reg.get_position("cargo_site") if reg else null
	if cargo_pos == null:
		cargo_pos = planet.get_surface_point(Vector3(-0.244309, 0.948667, -0.214991).normalized())
	var cargo_norm = (cargo_pos - planet.global_position).normalized()
	cargo_site_node = SpaceCargoScene.instantiate()
	add_child(cargo_site_node)
	_align_to_surface(cargo_site_node, cargo_pos, cargo_norm, 0.0)
	print("[SPAWN] Space Cargo spawned at crevasse rim: ", cargo_pos)

	# 2f. Spawn 5 Water Ice Pickups scattered on the ice patch
	var ice_center = planet.get_surface_point(planet.water_ice_dir) if "water_ice_dir" in planet else water_pos
	var ice_center_norm = (ice_center - planet.global_position).normalized()
	var ice_fwd = Vector3.UP.cross(ice_center_norm).normalized()
	var ice_right = ice_fwd.cross(ice_center_norm).normalized()
	
	water_ice_pickups_root = Node3D.new()
	water_ice_pickups_root.name = "WaterIcePickups"
	add_child(water_ice_pickups_root)
	
	var ice_rng = RandomNumberGenerator.new()
	ice_rng.seed = 987654
	
	for p_idx in range(5):
		var p_ang = float(p_idx) / 5.0 * TAU + ice_rng.randf_range(-0.25, 0.25)
		var p_dist = ice_rng.randf_range(4.0, 16.0) # within 20m ice basin
		var p_tangent = (ice_right * cos(p_ang) + ice_fwd * sin(p_ang)).normalized()
		var p_dir = (ice_center_norm * cos(p_dist / 500.0) + p_tangent * sin(p_dist / 500.0)).normalized()
		var p_surface = planet.get_surface_point(p_dir)
		var p_normal = (p_surface - planet.global_position).normalized()
		
		var pickup_inst = WaterIcePickupScene.instantiate() as WaterIcePickup
		pickup_inst.name = "WaterIcePickup_%d" % (p_idx + 1)
		pickup_inst.sample_id = p_idx + 1
		water_ice_pickups_root.add_child(pickup_inst)
		_align_to_surface(pickup_inst, p_surface, p_normal, 0.5)
	print("[SPAWN] 5 Water Ice Pickups spawned on ice basin (radius 20m)")

	# 2g. Setup Registry POIs & Beacons (Home, MAV Rocket, Crash Base, Rover Site, Cargo Site, Water Deposit, Noctis Chasm)
	registry_pois = [
		{
			"id": "home",
			"name": "Home Base",
			"icon": "🏠",
			"pos": pod_pt,
			"color": Color("#3fd0f0"),
			"beacon_node": null
		},
		{
			"id": "mav_rocket",
			"name": "MAV Rocket",
			"icon": "🚀",
			"pos": landing_pt,
			"color": Color("#f0a830"),
			"beacon_node": null
		},
		{
			"id": "crash_base",
			"name": "Crash Base",
			"icon": "📦",
			"pos": crash_pos,
			"color": Color("#e0a030"),
			"beacon_node": null
		},
		{
			"id": "rover_site",
			"name": "Rover Site",
			"icon": "🚙",
			"pos": rover_pos,
			"color": Color("#e0a030"),
			"beacon_node": null
		},
		{
			"id": "cargo_site",
			"name": "Cargo Site",
			"icon": "📦",
			"pos": cargo_pos,
			"color": Color("#50e050"),
			"beacon_node": null
		},
		{
			"id": "water_deposit",
			"name": "Water Deposit",
			"icon": "❄️",
			"pos": water_pos,
			"color": Color("#3fd0f0"),
			"beacon_node": null
		},
		{
			"id": "noctis_chasm",
			"name": "Noctis Chasm",
			"icon": "🕳️",
			"pos": noctis_pos,
			"color": Color("#b040d0"),
			"beacon_node": null
		}
	]

	for poi in registry_pois:
		var p_pos = poi["pos"] as Vector3
		var p_norm = (p_pos - planet.global_position).normalized()
		var b_node = _create_poi_beacon(poi["id"], poi["name"], p_pos, p_norm, poi["color"])
		poi["beacon_node"] = b_node

	# 2f. Generate route obstacles along routes from Home to Crash Base, Water Deposit, and Rover Site
	_generate_route_obstacles()

	tracked_pois.append({
		"id": "base",
		"name": "Crash Base",
		"icon": "🏠",
		"pos": pod_pt,
		"active": true
	})

	# 3. Spawn Geological Cave Environments in Distant Mathematical Pit Craters
	cave_defs = [
		{"scene": NoctisFissureScene, "name": "Noctis Labyrinthus Chasm", "short": "Noctis Chasm", "depth": 3.0},
		{"scene": ElysiumCavernScene, "name": "Elysium Magma Cavern", "short": "Elysium Cavern", "depth": 3.0}
	]

	for i in cave_defs.size():
		var pit_pt = planet.get_cave_pit_surface_point(i)
		var pit_normal = (pit_pt - planet.global_position).normalized()
		
		var approach = pit_pt - player.global_position
		var intended_fwd = (approach - pit_normal * approach.dot(pit_normal)).normalized()
		if intended_fwd.length_squared() < 0.01:
			intended_fwd = Vector3.FORWARD
		
		var cave_inst = cave_defs[i]["scene"].instantiate()
		add_child(cave_inst)
		var depth_offset = -float(cave_defs[i]["depth"])
		_align_to_surface(cave_inst, pit_pt, pit_normal, depth_offset, intended_fwd)
		print("Spawned cave environment [%s] at mathematical pit: %s (up_offset: %.1f)" % [cave_defs[i]["name"], pit_pt, depth_offset])

		tracked_pois.append({
			"id": "cave_" + str(i),
			"name": cave_defs[i]["short"],
			"icon": "🕳️",
			"pos": pit_pt,
			"active": true
		})

	call_deferred("_check_cave_visibility")

	# 4. Spawn 6 Historic NASA Probes on Crater Rims
	for mission in HISTORIC_MISSIONS:
		var rim_pt = planet.get_crater_rim_point(mission["crater_idx"])
		var rim_normal = (rim_pt - planet.global_position).normalized()
		
		var artifact = ArtifactScene.instantiate()
		artifact.mission_name = mission["name"]
		artifact.lore_fact = mission["lore"]
		artifact.repair_part = mission["part"]
		
		add_child(artifact)
		_align_to_surface(artifact, rim_pt, rim_normal, 0.0)
		artifact.artifact_collected.connect(_on_artifact_collected.bind(mission["name"]))
		print("Spawned artifact [%s] at crater rim: %s" % [mission["name"], rim_pt])

		tracked_pois.append({
			"id": mission["name"],
			"name": mission["short_name"],
			"icon": "🛰️",
			"pos": rim_pt,
			"active": true
		})

func _check_cave_visibility() -> void:
	var space_state = get_world_3d().direct_space_state
	for i in cave_defs.size():
		var pit_pt = planet.get_cave_pit_surface_point(i)
		var pit_normal = (pit_pt - planet.global_position).normalized()
		var ray_origin = pit_pt + pit_normal * 8.0
		var ray_target = pit_pt - pit_normal * 8.0
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
		var result = space_state.intersect_ray(query)
		var cave_name = cave_defs[i]["name"]
		if result.is_empty():
			print("[CAVE VISIBILITY CHECK] %s: OPEN" % cave_name)
		elif result["collider"] != planet.static_body:
			print("[CAVE VISIBILITY CHECK] %s: OPEN" % cave_name)
		else:
			var hit_depth = (result["position"] - pit_pt).dot(pit_normal)
			if hit_depth < -1.5:
				print("[CAVE VISIBILITY CHECK] %s: OPEN" % cave_name)
			else:
				print("[CAVE VISIBILITY CHECK] %s: BLOCKED" % cave_name)

func _align_to_surface(node: Node3D, pos: Vector3, normal: Vector3, up_offset: float = 0.0, intended_fwd: Vector3 = Vector3.ZERO) -> void:
	var up = normal.normalized()
	var fwd = intended_fwd
	if fwd.length_squared() < 0.001 or abs(fwd.normalized().dot(up)) > 0.95:
		fwd = Vector3.FORWARD
		if abs(up.dot(fwd)) > 0.85:
			fwd = Vector3.RIGHT
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var right = fwd.cross(up).normalized()
	fwd = up.cross(right).normalized()
	node.global_transform = Transform3D(Basis(right, up, -fwd), pos + up * up_offset)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	
	var key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	
	# Debug key F: Time scale fast-forward
	if key == KEY_F:
		if Engine.time_scale > 1.5:
			Engine.time_scale = 1.0
			print("[DEBUG] Time scale reset to 1.0x")
			if hud and hud.has_method("show_message"):
				hud.show_message("⏩ Time Speed: 1.0x", 1.5)
		else:
			Engine.time_scale = 10.0
			print("[DEBUG] Time scale set to 10.0x fast-forward")
			if hud and hud.has_method("show_message"):
				hud.show_message("⏩ Fast-Forward: 10.0x", 1.5)
		return

	# Debug keys 1-4 and F12 only run when debug_placement is true
	var reg = get_node_or_null("/root/PlacementRegistry")
	var is_debug = reg.debug_placement if (reg and "debug_placement" in reg) else true
	if not is_debug:
		return
	
	# F12: Clean recording mode (Hide debug HUD and gizmos)
	if key == KEY_F12:
		_toggle_clean_recording_mode()
		get_viewport().set_input_as_handled()
		return
	
	# 1: Teleport to Pod Entrance
	if key == KEY_1:
		var target = Vector3.ZERO
		if crashed_pod_node:
			var door = crashed_pod_node.find_child("Line0022", true, false)
			if door:
				var p_up = (door.global_position - planet.global_position).normalized()
				var p_fwd = (door.global_position - crashed_pod_node.global_position)
				p_fwd = (p_fwd - p_up * p_fwd.dot(p_up)).normalized()
				target = door.global_position + p_fwd * 1.5
			else:
				target = crashed_pod_node.global_position
		elif reg and reg.has_method("get_position") and reg.get_position("pod") != null:
			target = reg.get_position("pod")
		else:
			target = pod_position
		_teleport_player(target, "Pod Entrance")
		get_viewport().set_input_as_handled()
	# 2: Teleport to Cargo Site
	elif key == KEY_2:
		var target = Vector3.ZERO
		if cargo_site_node:
			target = cargo_site_node.global_position
		elif reg and reg.has_method("get_position") and reg.get_position("cargo_site") != null:
			target = reg.get_position("cargo_site")
		_teleport_player(target, "Cargo Site")
		get_viewport().set_input_as_handled()
	# 3: Teleport to Rover Site
	elif key == KEY_3:
		var target = Vector3.ZERO
		if rover_site_node:
			target = rover_site_node.global_position
		elif reg and reg.has_method("get_position") and reg.get_position("rover_site") != null:
			target = reg.get_position("rover_site")
		_teleport_player(target, "Rover Site")
		get_viewport().set_input_as_handled()
	# 4: Teleport to Water Deposit Base
	elif key == KEY_4:
		var target = Vector3.ZERO
		if planet and "water_ice_dir" in planet:
			target = planet.get_surface_point(planet.water_ice_dir)
		elif reg and reg.has_method("get_position") and reg.get_position("water_deposit") != null:
			target = reg.get_position("water_deposit")
		_teleport_player(target, "Water Deposit Base")
		get_viewport().set_input_as_handled()

func _teleport_player(target_pos: Vector3, location_name: String) -> void:
	if not player or not planet:
		return
	
	# Unlock player from intro cutscene if active so they can immediately move and record
	if "is_intro_active" in player and player.is_intro_active:
		player.is_intro_active = false
		player.input_locked = false
		if player.has_method("_finish_intro"):
			player._finish_intro()
		elif "letterbox_ui" in player and player.letterbox_ui:
			player.letterbox_ui.slide_out(0.2)
	
	var center = planet.global_position
	var up = (target_pos - center).normalized()
	
	# Place player on ground surface + slight elevation clearance
	var surf_pt = planet.get_surface_point(up) if planet.has_method("get_surface_point") else target_pos
	var final_pos = surf_pt + up * 0.7
	
	var fwd = -player.global_transform.basis.z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
		fwd = (fwd - up * fwd.dot(up)).normalized()
	var right = up.cross(fwd).normalized()
	fwd = right.cross(up).normalized()
	
	player.global_transform = Transform3D(Basis(right, up, -fwd), final_pos)
	player.velocity = Vector3.ZERO
	
	print("[TELEPORT] Teleported player to %s at position: %s" % [location_name, player.global_position])
	if hud and hud.has_method("show_message"):
		hud.show_message("Teleported to: %s" % location_name, 2.0)

func _toggle_clean_recording_mode() -> void:
	clean_recording_mode = not clean_recording_mode
	
	if clean_recording_mode:
		if hud:
			hud.visible = false
		if player and "letterbox_ui" in player and player.letterbox_ui:
			player.letterbox_ui.set_hud_visible(false)
	else:
		if player and "letterbox_ui" in player and player.letterbox_ui:
			player.letterbox_ui.hide_hud = false
			player.letterbox_ui.is_active = false
		if hud:
			hud.visible = true
	
	# Hide / show all beacons
	for poi in registry_pois:
		var b_node = poi.get("beacon_node") as Node3D
		if b_node and is_instance_valid(b_node):
			b_node.visible = not clean_recording_mode
	
	# Hide / show debug marker spheres from PlacementRegistry
	var reg = get_node_or_null("/root/PlacementRegistry")
	if reg:
		for child in reg.get_children():
			if child.name.begins_with("DebugMarker_"):
				child.visible = not clean_recording_mode
	
	print("[RECORDING] F12 clean mode: %s (HUD and gizmos %s)" % ["ENABLED" if clean_recording_mode else "DISABLED", "HIDDEN" if clean_recording_mode else "VISIBLE"])



func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not survival or not player:
		return
	
	# Determine if player is in shelter or inside a natural rock cave
	var dist_to_shelter = player.global_position.distance_to(shelter_pos)
	var dist_to_pod = player.global_position.distance_to(crashed_pod_node.global_position) if crashed_pod_node else 999.0
	var inside_shelter = (dist_to_shelter < 16.0) or (dist_to_pod < 16.0)
	
	var inside_cave = false
	for poi in tracked_pois:
		if (poi["id"] as String).begins_with("cave_") and player.global_position.distance_to(poi["pos"]) < 26.0:
			inside_cave = true
			break

	survival.is_in_shelter = inside_shelter or inside_cave
	survival.is_shield_active = inside_cave
	survival.is_sprinting = Input.is_action_pressed("run")
	if player and "is_jetpacking" in player:
		survival.is_jetpacking = player.is_jetpacking
	if day_night_system and day_night_system.has_method("get_sun_factor"):
		survival.sun_factor = day_night_system.get_sun_factor()
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		survival.is_scrubber_repaired = gm.scrubber_repaired
		survival.is_power_unit_repaired = gm.power_unit_repaired
	survival.tick(delta)

	beacon_scan_timer += delta
	if beacon_scan_timer >= 0.25:
		beacon_scan_timer = 0.0
		_update_beacons_and_guidance()

	signal_scan_timer += delta
	if signal_scan_timer >= 0.15:
		signal_scan_timer = 0.0
		_update_signal_tracker()

func _create_poi_beacon(poi_id: String, poi_name: String, pos: Vector3, normal: Vector3, color: Color) -> Node3D:
	var beacon_root = Node3D.new()
	beacon_root.name = "Beacon_" + poi_id
	
	# Emissive column: 40 units tall, 0.3 units wide (radius 0.15)
	var col_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.15
	cyl.height = 40.0
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	col_mesh.mesh = cyl
	col_mesh.material_override = mat
	
	# Top Label: Faint label with name and distance
	var lbl = Label3D.new()
	lbl.name = "TopLabel"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 22
	lbl.modulate = Color(color.r, color.g, color.b, 0.6)
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	lbl.outline_size = 2
	lbl.position = Vector3(0, 20.5, 0)
	lbl.text = poi_name
	
	beacon_root.add_child(col_mesh)
	col_mesh.add_child(lbl)
	add_child(beacon_root)
	
	_align_to_surface(beacon_root, pos + normal * 20.0, normal, 0.0)
	beacon_root.visible = false
	return beacon_root

func _update_beacons_and_guidance() -> void:
	if not player or not is_instance_valid(player):
		return
	var p_pos = player.global_position
	var discovered_list: Array[Dictionary] = []
	var gm = get_node_or_null("/root/GameManager")
	
	for poi in registry_pois:
		var pos: Vector3 = poi["pos"]
		var dist = p_pos.distance_to(pos)
		
		# Discovery check: within 60 units for the first time
		var is_disc = gm.is_poi_discovered(poi["id"]) if gm else false
		if dist <= 60.0 and not is_disc:
			if gm:
				gm.mark_poi_discovered(poi["id"])
			is_disc = true
			print("[DISCOVERY] Discovered POI: %s (%s) at distance %.1fm" % [poi["id"], poi["name"], dist])
		
		# Beacon visibility: only between 15 and 150 units from player
		var b_node = poi.get("beacon_node") as Node3D
		if b_node and is_instance_valid(b_node):
			var in_range = (dist >= 15.0 and dist <= 150.0)
			b_node.visible = in_range and (not clean_recording_mode)
			if in_range:
				var lbl = b_node.find_child("TopLabel", true, false) as Label3D
				if lbl:
					lbl.text = "%s\n%dm" % [poi["name"], int(dist)]
		
		if is_disc:
			discovered_list.append({
				"id": poi["id"],
				"name": poi["name"],
				"icon": poi["icon"],
				"pos": pos,
				"color": poi["color"],
				"dist": dist
			})
	
	_update_objective_state()
	
	if hud:
		if hud.has_method("update_compass"):
			hud.update_compass(player, planet, discovered_list, current_objective_pos, current_objective_name)
		if hud.has_method("update_discovered_signals"):
			hud.update_discovered_signals(discovered_list)

func _update_objective_state() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var pod_pos = crashed_pod_node.global_position if crashed_pod_node else shelter_pos
	var rocket_pos = return_vehicle_node.global_position if return_vehicle_node else Vector3(0, 500, 0)
	var cargo_pos = cargo_site_node.global_position if cargo_site_node else (crash_base_node.global_position if crash_base_node else pod_pos)
	
	if gm and gm.scrubber_repaired:
		current_objective_name = "Return to MAV Rocket"
		current_objective_pos = rocket_pos
	elif gm and (gm.filter_core > 0 or gm.cargo_filter_core_collected or gm.crate_collected):
		current_objective_name = "Repair the oxygen scrubber"
		current_objective_pos = pod_pos
	elif crashed_pod_node and crashed_pod_node.arrival_sequence_completed:
		current_objective_name = "Get filter core from Cargo Site"
		current_objective_pos = cargo_pos
	else:
		current_objective_name = "Reach Survival Pod"
		current_objective_pos = pod_pos

func _on_scrubber_repaired() -> void:
	current_objective_name = "Return to MAV Rocket"
	var rocket_pos = return_vehicle_node.global_position if return_vehicle_node else Vector3(0, 500, 0)
	current_objective_pos = rocket_pos
	if hud and hud.has_method("show_objective"):
		hud.show_objective("Return to MAV Rocket")

func _update_signal_tracker() -> void:
	if not hud or tracked_pois.is_empty():
		return

	var p_pos = player.global_position
	var poi_distances = []

	for poi in tracked_pois:
		if poi.get("active", true):
			var dist = p_pos.distance_to(poi["pos"])
			poi_distances.append({
				"text": "%s %s (%dm)" % [poi["icon"], poi["name"], int(dist)],
				"dist": dist
			})

	poi_distances.sort_custom(func(a, b): return a["dist"] < b["dist"])

	var count = min(3, poi_distances.size())
	var parts = []
	for i in count:
		parts.append(poi_distances[i]["text"])
	
	var final_str = "📡 SIGNALS: " + "  •  ".join(PackedStringArray(parts))
	if hud.has_method("update_signals"):
		hud.update_signals(final_str)

func register_runtime_poi(poi_name: String, pos: Vector3, color: Color) -> void:
	var normal = (pos - planet.global_position).normalized() if planet else Vector3.UP
	var b_node = _create_poi_beacon(poi_name, poi_name.capitalize(), pos, normal, color)
	var new_poi = {
		"id": poi_name,
		"name": poi_name.capitalize(),
		"icon": "📍",
		"pos": pos,
		"color": color,
		"beacon_node": b_node
	}
	registry_pois.append(new_poi)
	tracked_pois.append({
		"id": poi_name,
		"name": poi_name.capitalize(),
		"icon": "📍",
		"pos": pos,
		"active": true
	})
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.mark_poi_discovered(poi_name)
	_update_beacons_and_guidance()
	print("[WORLD] Runtime POI registered: %s at %s" % [poi_name, pos])

func _on_pod_body_entered(body: Node3D) -> void:
	if body == player or body.is_in_group("player"):
		if crashed_pod_node and crashed_pod_node.has_method("start_arrival_sequence"):
			crashed_pod_node.start_arrival_sequence(player, hud)
		elif player and player.has_method("set_haggard") and player.is_haggard:
			player.set_haggard(false)
			if hud and hud.has_method("show_alert"):
				hud.show_alert("🏠 Survival Shelter reached! Adrenaline stabilized; normal movement restored.", false)

func _on_pod_solar_deployed() -> void:
	survival.solar_power_gain = 0.8
	if player and player.has_method("set_haggard") and player.is_haggard:
		player.set_haggard(false)
	if hud and hud.has_method("show_alert"):
		hud.show_alert("⚡ Solar arrays online! Generating renewable energy from Martian sunlight.", false)

func _on_artifact_collected(m_name: String, lore: String, part: String, mission_key: String) -> void:
	if part != "":
		if return_vehicle_node and return_vehicle_node.has_method("install_part"):
			return_vehicle_node.install_part(part)
	else:
		survival.use_repair_kit()
	
	for poi in tracked_pois:
		if poi["id"] == mission_key:
			poi["active"] = false
			break

	if hud and hud.has_method("show_artifact_card"):
		hud.show_artifact_card(m_name, lore, part)
	if hud and hud.has_method("show_alert"):
		hud.show_alert("🛰️ DISCOVERED: %s" % m_name, false)

func _on_mav_launch_success() -> void:
	if hud and hud.has_method("show_victory_screen"):
		hud.show_victory_screen()

# -------------------------------------------------------------------------
# ROUTE OBSTACLES (PART D)
# -------------------------------------------------------------------------
func _generate_route_obstacles() -> void:
	var existing = get_node_or_null("RouteObstacles")
	if existing:
		existing.queue_free()
	
	var obs_root = Node3D.new()
	obs_root.name = "RouteObstacles"
	add_child(obs_root)
	
	var reg = get_node_or_null("/root/PlacementRegistry")
	var home_pos = reg.get_position("home") if reg else (crashed_pod_node.global_position if crashed_pod_node else shelter_pos)
	
	var routes = [
		{"name": "Home to Crash Base", "dest_id": "crash_base", "dest_pos": reg.get_position("crash_base") if reg else null},
		{"name": "Home to Water Deposit", "dest_id": "water_deposit", "dest_pos": reg.get_position("water_deposit") if reg else null},
		{"name": "Home to Rover Site", "dest_id": "rover_site", "dest_pos": reg.get_position("rover_site") if reg else null}
	]
	
	var planet_center = planet.global_position
	var planet_rad = planet.radius if "radius" in planet else 500.0
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 20261115
	
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.18, 0.14, 0.12, 1.0)
	rock_mat.roughness = 0.92
	
	var all_placed_obstacles: Array[Dictionary] = []
	var route_counts = {}
	
	print("\n==================================================")
	print("GENERATING ROUTE OBSTACLES (PART D)")
	print("==================================================")
	
	for route in routes:
		var r_name: String = route["name"]
		var dest_pos: Vector3 = route["dest_pos"]
		if dest_pos == Vector3.ZERO or dest_pos == null:
			continue
		
		var p_start = home_pos
		var p_end = dest_pos
		var dir_start = (p_start - planet_center).normalized()
		var dir_end = (p_end - planet_center).normalized()
		
		var total_angle = acos(clampf(dir_start.dot(dir_end), -1.0, 1.0))
		var total_surface_dist = total_angle * planet_rad
		
		# Sample every 10 units along the surface path
		var step_dist = 10.0
		var num_steps = int(total_surface_dist / step_dist)
		var obstacles_placed_this_route = 0
		
		for s in range(1, num_steps):
			var dist_along = float(s) * step_dist
			var t = dist_along / total_surface_dist
			
			# 25% chance to place an obstacle (fallback ensures at least 1 per route)
			var roll = rng.randf()
			var must_place = (s == maxi(1, num_steps / 2) and obstacles_placed_this_route == 0)
			if roll > 0.25 and not must_place:
				continue
			
			# Slerp direction along great-circle path
			var path_dir = dir_start.slerp(dir_end, t).normalized()
			var path_center = planet.get_surface_point(path_dir)
			var path_norm = (path_center - planet_center).normalized()
			
			# Path tangent (forward) and lateral vector (side)
			var fwd = (dir_end - path_dir * path_dir.dot(dir_end)).normalized()
			var side = fwd.cross(path_norm).normalized()
			
			# Decide: cluster of 2-4 rocks OR one large outcrop
			var is_large_outcrop = (rng.randf() < 0.40)
			
			# Lateral offset ensuring the 4-unit clear lane is completely untouched
			# Clear lane: [-2.0, 2.0]. Obstacle footprint must be inside [-6.0, 6.0] and strictly outside [-2.0, 2.0]
			var side_sign = -1.0 if rng.randf() < 0.5 else 1.0
			var d_lat = 0.0
			var est_radius = 0.0
			
			if is_large_outcrop:
				est_radius = 1.45
				d_lat = rng.randf_range(3.6, 4.3) * side_sign # 3.6 - 1.45 = 2.15 > 2.0; 4.3 + 1.45 = 5.75 <= 6.0
			else:
				est_radius = 0.65
				d_lat = rng.randf_range(3.1, 4.8) * side_sign # 3.1 - 0.65 = 2.45 > 2.0; 4.8 + 0.65 = 5.45 <= 6.0
			
			# Compute target position on planet surface
			var ang_lat = d_lat / planet_rad
			var obs_dir = (path_norm * cos(ang_lat) + side * sin(ang_lat)).normalized()
			var obs_pos = planet.get_surface_point(obs_dir)
			
			# 4. Cave hole check
			if planet.has_method("cave_mask") and planet.cave_mask(obs_dir) > 0.05:
				continue
			if "cave_centers" in planet:
				var in_cave = false
				for c in planet.cave_centers:
					if acos(clampf(obs_dir.dot(c.dir), -1.0, 1.0)) < c.hole_rad * 1.5:
						in_cave = true
						break
				if in_cave:
					continue
			
			# Overlap check with POIs (Home, Pod, CrashBase, WaterDeposit, RoverSite, caves)
			var overlap_poi = false
			for poi in registry_pois:
				if obs_pos.distance_to(poi["pos"]) < 8.0:
					overlap_poi = true
					break
			if overlap_poi:
				continue
			
			# Rocket clearance check: strictly >= 60.0 units from mav_rocket
			var rk_pos = return_vehicle_node.global_position if return_vehicle_node else Vector3(0, 494.424, 0)
			if obs_pos.distance_to(rk_pos) < 60.0:
				continue
			
			# Overlap check with previously placed obstacles (> 3.5m)
			var overlap_other = false
			for prev in all_placed_obstacles:
				if obs_pos.distance_to(prev["pos"]) < 3.5:
					overlap_other = true
					break
			if overlap_other:
				continue
			
			var obs_node = Node3D.new()
			obs_node.name = "Obs_%s_%d" % [route["dest_id"], s]
			obs_root.add_child(obs_node)
			
			var obs_up = (obs_pos - planet_center).normalized()
			_align_to_surface(obs_node, obs_pos, obs_up, 0.0)
			
			if is_large_outcrop:
				# Large outcrop: scale 2.6-3.2m, sunk ~20%
				var mesh_inst = MeshInstance3D.new()
				var c_mesh = BoxMesh.new()
				var ox = rng.randf_range(2.6, 3.2)
				var oy = rng.randf_range(2.8, 3.6)
				var oz = rng.randf_range(2.6, 3.2)
				c_mesh.size = Vector3(ox, oy, oz)
				mesh_inst.mesh = c_mesh
				mesh_inst.material_override = rock_mat
				mesh_inst.position = Vector3(0, oy * 0.40, 0)
				mesh_inst.rotation = Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(0, TAU), rng.randf_range(-0.1, 0.1))
				obs_node.add_child(mesh_inst)
				
				# 5. Large outcrops get colliders
				var col_body = StaticBody3D.new()
				col_body.name = "OutcropCollider"
				var cs = CollisionShape3D.new()
				var col_shape = SphereShape3D.new()
				var col_rad = maxf(ox, oz) * 0.5 * 1.05
				col_shape.radius = col_rad
				cs.shape = col_shape
				col_body.add_child(cs)
				obs_node.add_child(col_body)
				col_body.position = Vector3(0, oy * 0.45, 0)
				
				all_placed_obstacles.append({
					"pos": obs_pos,
					"route": r_name,
					"type": "outcrop",
					"radius": col_rad,
					"d_lat": absf(d_lat)
				})
			else:
				# Cluster of 2 to 4 small/medium rocks
				var rock_count = rng.randi_range(2, 4)
				for r_idx in range(rock_count):
					var r_mi = MeshInstance3D.new()
					var r_box = BoxMesh.new()
					var rx = rng.randf_range(0.4, 0.9)
					var ry = rng.randf_range(0.3, 0.7)
					var rz = rng.randf_range(0.4, 0.9)
					r_box.size = Vector3(rx, ry, rz)
					r_mi.mesh = r_box
					r_mi.material_override = rock_mat
					
					var r_offset_angle = rng.randf_range(0, TAU)
					var r_offset_dist = rng.randf_range(0.2, 0.5)
					r_mi.position = Vector3(cos(r_offset_angle) * r_offset_dist, ry * 0.45, sin(r_offset_angle) * r_offset_dist)
					r_mi.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0, TAU), rng.randf_range(-0.15, 0.15))
					obs_node.add_child(r_mi)
				
				all_placed_obstacles.append({
					"pos": obs_pos,
					"route": r_name,
					"type": "cluster_%d" % rock_count,
					"radius": 0.65,
					"d_lat": absf(d_lat)
				})
			
			obstacles_placed_this_route += 1
		
		route_counts[r_name] = obstacles_placed_this_route
		print("  Route [%s] (Length %.1fm): %d obstacles placed" % [r_name, total_surface_dist, obstacles_placed_this_route])
	
	print("Total Route Obstacles Placed: %d" % all_placed_obstacles.size())
	print("==================================================\n")
