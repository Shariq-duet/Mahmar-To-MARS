extends Node3D
class_name DayNightCycle

# day_night_cycle.gd
# NASA Mars Celestial Simulation:
# - Drives Sun orbit around Mars (1 Sol = ~10 real minutes / 600s).
# - Disables Sun and enables Moon DirectionalLight3D (cool blue-white, 0.25 energy, shadows on) at night.
# - Night ambient light tuned to 0.15 for readability while remaining dark.
# - Orbits Martian moons Phobos (fast, rising in the west) and Deimos.
# - Feeds sun direction and player zenith into mars_sky.gdshader.
# - Prints sun, noon, and moon state changes once per sol.

signal sol_advanced(current_sol: int)

@export_group("Sol Day/Night Cycle")
@export var sol_duration_seconds: float = 600.0 # 10 real minutes = 1 Mars Sol
@export var time_of_sol: float = 150.0          # Start in mid-morning daylight
@export var sun_orbit_inclination_deg: float = 25.0
@export var orbit_radius: float = 900.0
@export var current_sol: int = 1

@export_group("Lighting Nodes")
@export var sun_light: DirectionalLight3D
@export var moon_light: DirectionalLight3D
@export var world_env: WorldEnvironment

@export_group("Night Lighting Tuning")
@export var moon_energy: float = 0.25           # Cool blue-white moon energy about 0.25
@export var moon_color: Color = Color(0.72, 0.82, 1.0) # Cool blue-white
@export var night_ambient_energy: float = 0.15  # Ambient energy about 0.15 at night
@export var night_ambient_color: Color = Color(0.12, 0.16, 0.24) # Legible, dark night sky ambient
@export var day_ambient_energy: float = 0.9     # Ambient energy during day
@export var day_ambient_color: Color = Color(0.38, 0.28, 0.22)

var phobos_node: Node3D = null
var deimos_node: Node3D = null
var player_node: Node3D = null
var sky_material: ShaderMaterial = null

var phobos_orbit_angle: float = 0.0
var deimos_orbit_angle: float = 0.0

var last_sun_above_horizon: bool = true
var printed_sunrise_sol: int = -1
var printed_sunset_sol: int = -1
var printed_noon_sol: int = -1

func _ready() -> void:
	# Retrieve or create sky material
	if world_env and world_env.environment and world_env.environment.sky:
		sky_material = world_env.environment.sky.sky_material as ShaderMaterial
	
	# Fallback search or create moon DirectionalLight3D if not wired
	if not moon_light:
		var found_moon = get_node_or_null("../MoonLight") as DirectionalLight3D
		if found_moon:
			moon_light = found_moon
		else:
			moon_light = DirectionalLight3D.new()
			moon_light.name = "MoonLight"
			moon_light.light_color = moon_color
			moon_light.light_energy = moon_energy
			moon_light.shadow_enabled = true
			add_child(moon_light)
	
	if moon_light:
		moon_light.light_color = moon_color
		moon_light.shadow_enabled = true
	
	_create_martian_moons()
	_update_celestial_bodies(0.0)

func set_player_reference(p: Node3D) -> void:
	player_node = p

func _process(delta: float) -> void:
	time_of_sol += delta
	if time_of_sol >= sol_duration_seconds:
		time_of_sol -= sol_duration_seconds
		current_sol += 1
		sol_advanced.emit(current_sol)
		print("[CELESTIAL] Advance to Sol %d (1 Sol = %.0fs)" % [current_sol, sol_duration_seconds])
	
	_update_celestial_bodies(delta)

func get_sun_factor() -> float:
	var sol_progress: float = time_of_sol / sol_duration_seconds
	var sun_angle: float = sol_progress * TAU
	var incl_rad = deg_to_rad(sun_orbit_inclination_deg)
	var sun_pos := Vector3(
		cos(sun_angle) * orbit_radius,
		sin(sun_angle) * cos(incl_rad) * orbit_radius,
		sin(sun_angle) * sin(incl_rad) * orbit_radius
	)
	var local_up = Vector3.UP
	if player_node:
		local_up = (player_node.global_position - global_position).normalized()
	return clampf(sun_pos.normalized().dot(local_up), 0.0, 1.0)

func _update_celestial_bodies(delta: float) -> void:
	# Calculate Sun position along inclined orbital circle
	var sol_progress: float = time_of_sol / sol_duration_seconds
	var sun_angle: float = sol_progress * TAU
	
	var incl_rad = deg_to_rad(sun_orbit_inclination_deg)
	var sun_pos := Vector3(
		cos(sun_angle) * orbit_radius,
		sin(sun_angle) * cos(incl_rad) * orbit_radius,
		sin(sun_angle) * sin(incl_rad) * orbit_radius
	)
	
	var sun_dir = sun_pos.normalized()

	# Determine player local normal or default UP
	var local_up = Vector3.UP
	if player_node:
		local_up = (player_node.global_position - global_position).normalized()
	
	var sun_height = sun_dir.dot(local_up)
	var sun_is_up = (sun_height > -0.05)

	# Update Sun & Moon DirectionalLights
	if sun_is_up:
		if sun_light:
			if sun_light.is_inside_tree():
				sun_light.global_position = sun_pos
				sun_light.look_at(Vector3.ZERO, Vector3.UP)
			else:
				sun_light.position = sun_pos
			
			if sun_height > 0.15:
				var day_ratio = clamp((sun_height - 0.15) / 0.7, 0.0, 1.0)
				sun_light.light_energy = lerp(0.8, 1.45, day_ratio)
				sun_light.light_color = Color(1.0, 0.96, 0.90).lerp(Color(1.0, 0.98, 0.95), day_ratio)
				sun_light.visible = true
			else:
				var sunset_t = (sun_height + 0.05) / 0.20
				sun_light.light_energy = lerp(0.0, 0.8, sunset_t)
				sun_light.light_color = Color(0.45, 0.75, 1.0).lerp(Color(1.0, 0.95, 0.85), sunset_t)
				sun_light.visible = true
		
		# Moon disabled during daylight
		if moon_light:
			moon_light.visible = false
			moon_light.light_energy = 0.0
		
		# Ambient daylight lighting
		if world_env and world_env.environment:
			if sun_height > 0.1:
				world_env.environment.ambient_light_color = day_ambient_color
				world_env.environment.ambient_light_energy = day_ambient_energy
			else:
				var t_amb = clamp((sun_height + 0.05) / 0.15, 0.0, 1.0)
				world_env.environment.ambient_light_color = night_ambient_color.lerp(Color(0.22, 0.32, 0.48), t_amb)
				world_env.environment.ambient_light_energy = lerp(night_ambient_energy, 0.65, t_amb)
	else:
		# Sun disabled during night
		if sun_light:
			sun_light.visible = false
			sun_light.light_energy = 0.0
		
		# Moon enabled: cool blue-white, energy 0.25, shadows ON
		if moon_light:
			moon_light.visible = true
			moon_light.light_energy = moon_energy
			moon_light.light_color = moon_color
			moon_light.shadow_enabled = true
			var moon_pos = -sun_pos
			if moon_light.is_inside_tree():
				moon_light.global_position = moon_pos
				moon_light.look_at(Vector3.ZERO, Vector3.UP)
			else:
				moon_light.position = moon_pos
		
		# Ambient night lighting: 0.15 energy, terrain readable but dark
		if world_env and world_env.environment:
			world_env.environment.ambient_light_color = night_ambient_color
			world_env.environment.ambient_light_energy = night_ambient_energy

	# Print state changes once per sol
	if sun_is_up and not last_sun_above_horizon:
		last_sun_above_horizon = true
		if printed_sunrise_sol != current_sol:
			printed_sunrise_sol = current_sol
			print("[CELESTIAL] Sol %d Sunrise: Sun ENABLED (Energy: %.2f), Moon DISABLED" % [current_sol, sun_light.light_energy if sun_light else 1.0])
	elif not sun_is_up and last_sun_above_horizon:
		last_sun_above_horizon = false
		if printed_sunset_sol != current_sol:
			printed_sunset_sol = current_sol
			print("[CELESTIAL] Sol %d Sunset: Sun DISABLED, Moon ENABLED (Moon Energy: %.2f, Cool Blue-White, Shadows: ON, Night Ambient: %.2f)" % [
				current_sol,
				moon_light.light_energy if moon_light else moon_energy,
				night_ambient_energy
			])
	
	if sun_height > 0.85 and printed_noon_sol != current_sol:
		printed_noon_sol = current_sol
		print("[CELESTIAL] Sol %d Noon: Sun PEAK (Energy: %.2f, Max Solar Generation: 2.0/s)" % [current_sol, sun_light.light_energy if sun_light else 1.45])

	# Update Sky shader uniforms
	if sky_material:
		sky_material.set_shader_parameter("sun_direction", sun_dir)
		sky_material.set_shader_parameter("planet_up", local_up)

	# Update Phobos & Deimos Moons
	phobos_orbit_angle += delta * (TAU / (sol_duration_seconds / 3.13))
	if phobos_node:
		var ph_r = 720.0
		var ph_incl = deg_to_rad(30.0)
		var p_pos = Vector3(
			sin(phobos_orbit_angle) * ph_r,
			cos(phobos_orbit_angle) * cos(ph_incl) * ph_r,
			cos(phobos_orbit_angle) * sin(ph_incl) * ph_r
		)
		if phobos_node.is_inside_tree():
			phobos_node.global_position = p_pos
			phobos_node.look_at(Vector3.ZERO, Vector3.UP)
		else:
			phobos_node.position = p_pos

	deimos_orbit_angle += delta * (TAU / (sol_duration_seconds * 3.0))
	if deimos_node:
		var de_r = 1100.0
		var de_incl = deg_to_rad(-15.0)
		var d_pos = Vector3(
			cos(deimos_orbit_angle) * de_r,
			sin(deimos_orbit_angle) * cos(de_incl) * de_r,
			sin(deimos_orbit_angle) * sin(de_incl) * de_r
		)
		if deimos_node.is_inside_tree():
			deimos_node.global_position = d_pos
			deimos_node.look_at(Vector3.ZERO, Vector3.UP)
		else:
			deimos_node.position = d_pos

func _create_martian_moons() -> void:
	phobos_node = Node3D.new()
	phobos_node.name = "Phobos"
	var ph_mi = MeshInstance3D.new()
	var ph_mesh = SphereMesh.new()
	ph_mesh.radius = 16.0
	ph_mesh.height = 24.0
	var ph_mat = StandardMaterial3D.new()
	ph_mat.albedo_color = Color(0.55, 0.52, 0.50)
	ph_mat.roughness = 0.95
	ph_mat.metallic = 0.05
	ph_mi.mesh = ph_mesh
	ph_mi.material_override = ph_mat
	phobos_node.add_child(ph_mi)
	add_child(phobos_node)

	deimos_node = Node3D.new()
	deimos_node.name = "Deimos"
	var de_mi = MeshInstance3D.new()
	var de_mesh = SphereMesh.new()
	de_mesh.radius = 9.0
	de_mesh.height = 14.0
	var de_mat = StandardMaterial3D.new()
	de_mat.albedo_color = Color(0.68, 0.65, 0.62)
	de_mat.roughness = 0.90
	de_mi.mesh = de_mesh
	de_mi.material_override = de_mat
	deimos_node.add_child(de_mi)
	add_child(deimos_node)
