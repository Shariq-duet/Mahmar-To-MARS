extends Node3D
class_name ProceduralPlanet

# ProceduralPlanet.gd
# Cube-sphere with Nowell's mapping, FastNoiseLite fBm, analytical crater displacement,
# and blended subterranean cave entrance cutout with raised lip & basalt vertex tinting.

@export var radius: float = 500.0
@export var resolution: int = 64            # quads per cube-face edge
@export var height_scale: float = 22.0      # fBm terrain amplitude
@export var planet_seed: int = 1337
@export var crater_count: int = 90
@export var crater_min_radius: float = 0.025   # angular radius (radians)
@export var crater_max_radius: float = 0.12
@export var crater_depth: float = 0.35         # fraction of crater radius
@export var rim_height: float = 0.10           # fraction of crater radius
@export var base_color: Color = Color(0.82, 0.32, 0.14, 1.0)     # Mars rust regolith
@export var entrance_color: Color = Color(0.14, 0.11, 0.10, 1.0) # Scorched basalt-black lip
@export var small_rock_count: int = 6000                             # Tier 1 small rocks
@export var medium_boulder_count: int = 800                          # Tier 2 medium boulders
@export var large_outcrop_count: int = 100                           # Tier 3 large crags/outcrops
@export var geometric_roughness_amplitude: float = 0.33           # 1.5% of height_scale (small high-frequency displacement)

const FACE_NORMALS: Array[Vector3] = [
	Vector3.UP, Vector3.DOWN, Vector3.LEFT,
	Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK
]
const CRATER_STRIDE := 7        # dir.xyz, cos_cut, angular_r, depth, rim
const CRATER_INFLUENCE := 1.6   # craters affect terrain out to 1.6 radii

var cave_centers: Array[Dictionary] = [
	{
		"name": "Noctis Labyrinthus Chasm",
		"dir": Vector3(0.24, 0.95, 0.18).normalized(),
		"hole_rad": 0.024,
		"lip_height": 3.0
	},
	{
		"name": "Elysium Magma Cavern",
		"dir": Vector3(-0.48, 0.78, -0.38).normalized(),
		"hole_rad": 0.024,
		"lip_height": 3.0
	}
]

var _noise := FastNoiseLite.new()
var _roughness_noise := FastNoiseLite.new()
var _mountain_noise := FastNoiseLite.new()
var _craters := PackedFloat32Array()
var mesh_instance: MeshInstance3D = null
var static_body: StaticBody3D = null
var boulder_container: Node3D = null

# Water Deposit Site (Mountain range + Ice basin)
var water_deposit_dir: Vector3 = Vector3(0.0511, 0.9760, 0.2115).normalized()
var water_ice_dir: Vector3 = (Vector3(0.0511, 0.9760, 0.2115) + Vector3(0.015, -0.012, -0.028)).normalized()
const WATER_RANGE_RADIUS: float = 90.0
const WATER_ICE_RADIUS: float = 20.0
const WATER_MOUNTAIN_AMPLITUDE: float = 120.0

# Crevasse near cargo_site (linear cut 30 units long, 8 units wide, steep walls, dark floor)
var crevasse_center_dir: Vector3 = Vector3(-0.250689, 0.942621, -0.220606).normalized()
var crevasse_axis: Vector3 = Vector3(-0.660565, 0.0, 0.750768).normalized() # along fissure
var crevasse_cross: Vector3 = crevasse_center_dir.cross(crevasse_axis).normalized() # across fissure
const CREVASSE_LENGTH: float = 30.0
const CREVASSE_WIDTH: float = 8.0
const CREVASSE_DEPTH: float = 12.0

var patch_vertex_count: int = 0

func get_patch_vertex_count() -> int:
	return patch_vertex_count

func _ready() -> void:
	generate()

func generate() -> void:
	_setup_noise()
	_build_craters()
	var mesh := _build_mesh()

	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "PlanetSurface"
	mesh_instance.mesh = mesh
	
	# Apply terrain shader with slope/altitude blending, triplanar noise, and cave vertex color blend
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://Assets/Shaders/mars_terrain.gdshader")
	mat.set_shader_parameter("planet_radius", radius)
	var center = global_position if is_inside_tree() else position
	mat.set_shader_parameter("planet_center", center)
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	# Concave collision built from the exact same triangles as the render mesh (with open holes).
	static_body = StaticBody3D.new()
	static_body.name = "PlanetCollider"
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = mesh.create_trimesh_shape()
	static_body.add_child(cs)
	add_child(static_body)
	print("ProceduralPlanet generated with radius ", radius, " and ", crater_count, " craters.")
	
	# Print water deposit metrics
	get_water_deposit_metrics()

	# Spawn procedural boulders via MultiMeshInstance3D (5 unique shapes) with dynamic collision pooling
	_spawn_boulders()

func get_water_deposit_metrics() -> Dictionary:
	var peak_h = _height(water_deposit_dir)
	var peak_pos = get_surface_point(water_deposit_dir)
	var ice_pos = get_surface_point(water_ice_dir)
	print("\n==================================================")
	print("[WATER DEPOSIT METRICS]")
	print("Mountain Peak Height:      %.2f m above base radius (Requirement >= 100m: %s)" % [peak_h, "PASS" if peak_h >= 100.0 else "FAIL"])
	print("Mountain Peak Global Pos:  %s (Alt: %.2f m)" % [peak_pos, peak_pos.length()])
	print("Water Ice Basin Radius:    %.1f m" % WATER_ICE_RADIUS)
	print("Water Ice Basin Center:    %s (Alt: %.2f m)" % [ice_pos, ice_pos.length()])
	print("High-Res Patch Vertices:   %d vertices (Target >= 2 per 4 units)" % patch_vertex_count)
	print("==================================================\n")
	return {
		"peak_height": peak_h,
		"ice_radius": WATER_ICE_RADIUS,
		"peak_pos": peak_pos,
		"ice_pos": ice_pos,
		"deposit_dir": water_deposit_dir,
		"ice_dir": water_ice_dir,
		"patch_vertex_count": patch_vertex_count
	}

func _spawn_boulders() -> void:
	if boulder_container and is_instance_valid(boulder_container):
		boulder_container.queue_free()
	var spawner_script = load("res://Scripts/planet/boulder_spawner.gd")
	var landing_dir = Vector3.UP
	boulder_container = spawner_script.create_boulder_system(self, 350, landing_dir, planet_seed + 101)
	add_child(boulder_container)
	var total_count = boulder_container.get_total_rock_count()
	var c_counts = boulder_container.get_cluster_counts()
	print("Spawned %d clustered procedural rocks across 350 clusters (boulder fields: %d, debris: %d, mixed: %d) in %d ms." % [
		total_count,
		c_counts["boulder field"],
		c_counts["debris field"],
		c_counts["mixed"],
		boulder_container.get_load_time_ms()
	])

# Helper to find exact mathematical surface position for any unit direction vector
func get_surface_point(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var center = global_position if is_inside_tree() else position
	return center + d * (radius + _height(d))

# Calculates exact 3D position on the rim of a specific crater
func get_crater_rim_point(crater_idx: int) -> Vector3:
	if _craters.is_empty():
		_build_craters()
	var o = (crater_idx % crater_count) * CRATER_STRIDE
	var center_d = Vector3(_craters[o], _craters[o + 1], _craters[o + 2]).normalized()
	var r = _craters[o + 4]
	
	var perp = Vector3.UP.cross(center_d)
	if perp.length_squared() < 0.01:
		perp = Vector3.RIGHT.cross(center_d)
	perp = perp.normalized()
	
	var rim_dir = (center_d * cos(r) + perp * sin(r)).normalized()
	return get_surface_point(rim_dir)

# ---------- Noise ----------
func _setup_noise() -> void:
	_noise.seed = planet_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 5
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.5

	# High-frequency geometric surface roughness (amplitude <= 1.5% of height_scale)
	_roughness_noise.seed = planet_seed + 77
	_roughness_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_roughness_noise.frequency = 6.0
	_roughness_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_roughness_noise.fractal_octaves = 3
	_roughness_noise.fractal_lacunarity = 2.2
	_roughness_noise.fractal_gain = 0.5

	# Ridged multifractal noise for water deposit mountain range
	_mountain_noise.seed = planet_seed + 309
	_mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mountain_noise.frequency = 4.0
	_mountain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_mountain_noise.fractal_octaves = 4
	_mountain_noise.fractal_lacunarity = 2.0
	_mountain_noise.fractal_gain = 0.5

# ---------- Craters ----------
func _build_craters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed
	_craters.resize(crater_count * CRATER_STRIDE)
	for i in crater_count:
		var d := Vector3(rng.randfn(0, 1), rng.randfn(0, 1), rng.randfn(0, 1)).normalized()
		var r := lerpf(crater_min_radius, crater_max_radius, pow(rng.randf(), 2.0))
		var o := i * CRATER_STRIDE
		_craters[o] = d.x
		_craters[o + 1] = d.y
		_craters[o + 2] = d.z
		_craters[o + 3] = cos(r * CRATER_INFLUENCE)
		_craters[o + 4] = r
		_craters[o + 5] = crater_depth * r * radius
		_craters[o + 6] = rim_height * r * radius

func _crater_height(d: Vector3) -> float:
	var h := 0.0
	var o := 0
	while o < _craters.size():
		var dt := d.x * _craters[o] + d.y * _craters[o + 1] + d.z * _craters[o + 2]
		if dt > _craters[o + 3]:
			var x := acos(clampf(dt, -1.0, 1.0)) / _craters[o + 4]
			if x < 1.0:
				h -= _craters[o + 5] * (1.0 - x * x)
			var t := (x - 1.0) / 0.18
			h += _craters[o + 6] * exp(-t * t)
		o += CRATER_STRIDE
	return h

# ---------- Cave Mask & Lip Influence ----------
# Returns 0.0 outside the opening, rising to 1.0 at the center.
# Used both to skip triangles (hole) and to blend the edge (rim).
func cave_mask(d: Vector3) -> float:
	var m := 0.0
	for c in cave_centers:
		var angle := acos(clampf(d.dot(c.dir), -1.0, 1.0))
		var t := 1.0 - smoothstep(c.hole_rad * 0.9, c.hole_rad * 1.25, angle)
		m = maxf(m, t)
	return m

# Combined influence function: returns Vector2(hole_mask, lip_band) in one pass per vertex
func cave_influence(d: Vector3) -> Vector2:
	var max_m := 0.0
	var max_lip := 0.0
	for c in cave_centers:
		var angle := acos(clampf(d.dot(c.dir), -1.0, 1.0))
		var t := 1.0 - smoothstep(c.hole_rad * 0.9, c.hole_rad * 1.25, angle)
		max_m = maxf(max_m, t)
		var lip := exp(-pow((angle - c.hole_rad * 1.15) / (c.hole_rad * 0.35), 2.0))
		max_lip = maxf(max_lip, lip)
	return Vector2(max_m, max_lip)

func get_cave_pit_count() -> int:
	return cave_centers.size()

func get_cave_pit_dir(idx: int) -> Vector3:
	return (cave_centers[idx % cave_centers.size()]["dir"] as Vector3).normalized()

func get_cave_pit_name(idx: int) -> String:
	return cave_centers[idx % cave_centers.size()]["name"] as String

func get_cave_pit_surface_point(idx: int) -> Vector3:
	var d = get_cave_pit_dir(idx)
	return get_surface_point(d)

func _crevasse_height(d: Vector3) -> float:
	var delta_dir = d - crevasse_center_dir * d.dot(crevasse_center_dir)
	var surf_s = delta_dir * radius
	var s_along = surf_s.dot(crevasse_axis)
	var s_cross = surf_s.dot(crevasse_cross)
	
	var half_len = CREVASSE_LENGTH * 0.5 # 15.0
	var half_wid = CREVASSE_WIDTH * 0.5 # 4.0
	
	var u_len = absf(s_along) / half_len
	var u_wid = absf(s_cross) / half_wid
	
	if u_len < 1.0 and u_wid < 1.0:
		var f_len = 0.5 * (1.0 + cos(clampf(u_len, 0.0, 1.0) * PI))
		var f_wall = 1.0 - pow(u_wid, 6.0) # steep rock walls and flat floor
		return -CREVASSE_DEPTH * f_wall * f_len
	elif u_len < 1.0 and u_wid >= 1.0 and u_wid < 1.35:
		var f_len = 0.5 * (1.0 + cos(clampf(u_len, 0.0, 1.0) * PI))
		var lip_t = (u_wid - 1.0) / 0.35
		var f_lip = sin(lip_t * PI)
		return 0.6 * f_lip * f_len
	return 0.0

func _height(d: Vector3) -> float:
	var h := _noise.get_noise_3dv(d * 2.0) * height_scale + _crater_height(d)
	# High-frequency geometric surface roughness micro-ripples
	h += _roughness_noise.get_noise_3dv(d * 8.0) * geometric_roughness_amplitude
	for c in cave_centers:
		var angle := acos(clampf(d.dot(c.dir), -1.0, 1.0))
		# Raised lip just outside the hole, fading to nothing further out.
		var lip := exp(-pow((angle - c.hole_rad * 1.15) / (c.hole_rad * 0.35), 2.0))
		h += lip * (c.lip_height as float)
	
	# Additive height term near water_deposit (ridged mountain range)
	var w_angle := acos(clampf(d.dot(water_deposit_dir), -1.0, 1.0))
	var w_dist := w_angle * radius
	if w_dist < WATER_RANGE_RADIUS:
		var n_raw = _mountain_noise.get_noise_3dv(d * 5.0)
		var ridged = 1.0 - absf(n_raw)
		ridged = ridged * ridged
		var falloff = 0.5 * (1.0 + cos(clampf(w_dist / WATER_RANGE_RADIUS, 0.0, 1.0) * PI))
		var mtn_h = ridged * WATER_MOUNTAIN_AMPLITUDE * falloff
		h += mtn_h
	
	# Water ice patch shallow flat-ish basin at foot of slope
	var ice_angle := acos(clampf(d.dot(water_ice_dir), -1.0, 1.0))
	var ice_dist := ice_angle * radius
	if ice_dist < WATER_ICE_RADIUS:
		var basin_falloff = 0.5 * (1.0 + cos(clampf(ice_dist / WATER_ICE_RADIUS, 0.0, 1.0) * PI))
		h -= 3.5 * basin_falloff
	
	# Crevasse linear cut near cargo_site
	h += _crevasse_height(d)
	return h

# ---------- Cube-sphere mesh ----------
func _cube_to_sphere(c: Vector3) -> Vector3:
	var x2 := c.x * c.x
	var y2 := c.y * c.y
	var z2 := c.z * c.z
	return Vector3(
		c.x * sqrt(1.0 - y2 * 0.5 - z2 * 0.5 + y2 * z2 / 3.0),
		c.y * sqrt(1.0 - z2 * 0.5 - x2 * 0.5 + z2 * x2 / 3.0),
		c.z * sqrt(1.0 - x2 * 0.5 - y2 * 0.5 + x2 * y2 / 3.0)
	)

func _build_mesh() -> ArrayMesh:
	var n := resolution
	var K := 6
	var key_to_idx := {}
	var dirs := PackedVector3Array()
	var idx := PackedInt32Array()

	var patch_i_min = 27
	var patch_i_max = 39
	var patch_j_min = 19
	var patch_j_max = 31

	var get_vert = func(c: Vector3) -> int:
		var key = Vector3i(roundi(c.x * n * K), roundi(c.y * n * K), roundi(c.z * n * K))
		if key_to_idx.has(key):
			return key_to_idx[key]
		var new_idx = dirs.size()
		key_to_idx[key] = new_idx
		dirs.append(_cube_to_sphere(c).normalized())
		return new_idx

	for face_idx in FACE_NORMALS.size():
		var fn: Vector3 = FACE_NORMALS[face_idx]
		var a := Vector3(fn.y, fn.z, fn.x)
		var b := fn.cross(a)
		var is_up_face = (fn == Vector3.UP)

		for j in n:
			for i in n:
				var in_patch = is_up_face and (i >= patch_i_min and i <= patch_i_max and j >= patch_j_min and j <= patch_j_max)
				var is_transition = is_up_face and not in_patch and (i >= patch_i_min - 1 and i <= patch_i_max + 1 and j >= patch_j_min - 1 and j <= patch_j_max + 1)

				if in_patch:
					# Fully subdivided KxK
					for sj in K:
						for si in K:
							var gi0 = i * K + si
							var gi1 = gi0 + 1
							var gj0 = j * K + sj
							var gj1 = gj0 + 1

							var c00 = fn + (2.0 * gi0 / (n * K) - 1.0) * a + (2.0 * gj0 / (n * K) - 1.0) * b
							var c10 = fn + (2.0 * gi1 / (n * K) - 1.0) * a + (2.0 * gj0 / (n * K) - 1.0) * b
							var c01 = fn + (2.0 * gi0 / (n * K) - 1.0) * a + (2.0 * gj1 / (n * K) - 1.0) * b
							var c11 = fn + (2.0 * gi1 / (n * K) - 1.0) * a + (2.0 * gj1 / (n * K) - 1.0) * b

							var v00 = get_vert.call(c00)
							var v10 = get_vert.call(c10)
							var v01 = get_vert.call(c01)
							var v11 = get_vert.call(c11)

							_add_tri(idx, dirs, v00, v10, v11)
							_add_tri(idx, dirs, v00, v11, v01)
				elif is_transition:
					# Border transition quad: fan from center to edge points
					var c00 = fn + (2.0 * i / n - 1.0) * a + (2.0 * j / n - 1.0) * b
					var c10 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * j / n - 1.0) * b
					var c01 = fn + (2.0 * i / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
					var c11 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b

					var v_center = get_vert.call((c00 + c10 + c01 + c11) * 0.25)

					var has_north = (j + 1 >= patch_j_min and j + 1 <= patch_j_max and i >= patch_i_min and i <= patch_i_max)
					var has_south = (j - 1 >= patch_j_min and j - 1 <= patch_j_max and i >= patch_i_min and i <= patch_i_max)
					var has_east  = (i + 1 >= patch_i_min and i + 1 <= patch_i_max and j >= patch_j_min and j <= patch_j_max)
					var has_west  = (i - 1 >= patch_i_min and i - 1 <= patch_i_max and j >= patch_j_min and j <= patch_j_max)

					# South edge (c00 to c10)
					var s_pts = []
					var k_s = K if has_south else 1
					for s in range(k_s + 1):
						var u = float(s) / float(k_s)
						s_pts.append(get_vert.call(c00.lerp(c10, u)))
					for s in range(k_s):
						_add_tri(idx, dirs, s_pts[s], s_pts[s + 1], v_center)

					# North edge (c01 to c11)
					var n_pts = []
					var k_n = K if has_north else 1
					for s in range(k_n + 1):
						var u = float(s) / float(k_n)
						n_pts.append(get_vert.call(c01.lerp(c11, u)))
					for s in range(k_n):
						_add_tri(idx, dirs, n_pts[s + 1], n_pts[s], v_center)

					# West edge (c00 to c01)
					var w_pts = []
					var k_w = K if has_west else 1
					for s in range(k_w + 1):
						var v = float(s) / float(k_w)
						w_pts.append(get_vert.call(c00.lerp(c01, v)))
					for s in range(k_w):
						_add_tri(idx, dirs, w_pts[s + 1], w_pts[s], v_center)

					# East edge (c10 to c11)
					var e_pts = []
					var k_e = K if has_east else 1
					for s in range(k_e + 1):
						var v = float(s) / float(k_e)
						e_pts.append(get_vert.call(c10.lerp(c11, v)))
					for s in range(k_e):
						_add_tri(idx, dirs, e_pts[s], e_pts[s + 1], v_center)
				else:
					# Standard quad
					var c00 = fn + (2.0 * i / n - 1.0) * a + (2.0 * j / n - 1.0) * b
					var c10 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * j / n - 1.0) * b
					var c01 = fn + (2.0 * i / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
					var c11 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b

					var v00 = get_vert.call(c00)
					var v10 = get_vert.call(c10)
					var v01 = get_vert.call(c01)
					var v11 = get_vert.call(c11)

					# Skip any triangle with vertices fully inside the cave hole
					if cave_mask(dirs[v00]) > 0.85 or cave_mask(dirs[v10]) > 0.85 or cave_mask(dirs[v11]) > 0.85:
						pass
					else:
						_add_tri(idx, dirs, v00, v10, v11)

					if cave_mask(dirs[v00]) > 0.85 or cave_mask(dirs[v11]) > 0.85 or cave_mask(dirs[v01]) > 0.85:
						pass
					else:
						_add_tri(idx, dirs, v00, v11, v01)

	# Count vertices in water mountain patch (within 90m)
	patch_vertex_count = 0
	for k in dirs.size():
		var d = dirs[k]
		var d_mtn = acos(clampf(d.dot(water_deposit_dir), -1.0, 1.0)) * radius
		if d_mtn <= 90.0:
			patch_vertex_count += 1

	var pos := PackedVector3Array()
	pos.resize(dirs.size())
	for k in dirs.size():
		pos[k] = dirs[k] * (radius + _height(dirs[k]))

	# Vertex colors: lerp base regolith color into dark basalt near opening and raised lip
	var colors := PackedColorArray()
	colors.resize(pos.size())
	for k in dirs.size():
		var inf := cave_influence(dirs[k])
		var blend := clampf(maxf(inf.x, inf.y), 0.0, 1.0)
		var c = base_color.lerp(entrance_color, blend)
		
		# Crevasse dark basalt floor tint
		var cr_delta = dirs[k] - crevasse_center_dir * dirs[k].dot(crevasse_center_dir)
		var cr_s = cr_delta * radius
		var cr_along = absf(cr_s.dot(crevasse_axis))
		var cr_cross = absf(cr_s.dot(crevasse_cross))
		if cr_along < 16.0 and cr_cross < 4.2:
			var cr_blend = clampf((1.0 - cr_cross / 4.2) * (1.0 - cr_along / 16.0), 0.0, 1.0)
			var dark_floor = Color(0.12, 0.09, 0.08, 1.0)
			c = c.lerp(dark_floor, cr_blend * 0.85)
		
		# Water ice patch vertex color: pale blue-white, blended in with a noise edge
		var ice_a := acos(clampf(dirs[k].dot(water_ice_dir), -1.0, 1.0))
		var ice_d := ice_a * radius
		if ice_d < WATER_ICE_RADIUS + 4.0:
			var edge_n = _roughness_noise.get_noise_3dv(dirs[k] * 14.0) * 2.2
			var noisy_dist = ice_d + edge_n
			var ice_blend = clampf((WATER_ICE_RADIUS - noisy_dist) / 3.5, 0.0, 1.0)
			if ice_blend > 0.0:
				var ice_col = Color(0.72, 0.88, 0.98, 1.0)
				c = c.lerp(ice_col, ice_blend)
		
		colors[k] = c

	var normals := PackedVector3Array()
	normals.resize(pos.size())
	for t in range(0, idx.size(), 3):
		var ia := idx[t]
		var ib := idx[t + 1]
		var ic := idx[t + 2]
		var nrm := (pos[ic] - pos[ia]).cross(pos[ib] - pos[ia])
		normals[ia] += nrm
		normals[ib] += nrm
		normals[ic] += nrm
	for k in normals.size():
		normals[k] = normals[k].normalized()

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _add_tri(idx: PackedInt32Array, dirs: PackedVector3Array, a: int, b: int, c: int) -> void:
	if cave_mask(dirs[a]) > 0.85 or cave_mask(dirs[b]) > 0.85 or cave_mask(dirs[c]) > 0.85:
		return
	var pa := dirs[a]
	var pb := dirs[b]
	var pc := dirs[c]
	if (pb - pa).cross(pc - pa).dot(pa + pb + pc) > 0.0:
		idx.append(a); idx.append(c); idx.append(b)
	else:
		idx.append(a); idx.append(b); idx.append(c)
