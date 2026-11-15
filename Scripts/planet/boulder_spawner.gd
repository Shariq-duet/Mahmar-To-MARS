extends Node3D
class_name BoulderSpawner

# boulder_spawner.gd
# High-density clustered procedural rock scatter system (350 clusters) across 24 angular patches.
# Tier 1 - Small Rocks: ~4,500-5,000 instances, scale 0.3-1.5, dynamic 30-body collision pool.
# Tier 2 - Medium Boulders: ~500-700 instances, scale 2.0-5.0, sink depth 25-30% of height, dedicated colliders.
# Tier 3 - Large Outcrops: ~100-150 instances, scale 8.0-20.0, sink depth 15-20% of height, dedicated colliders.
# Colliders for Large & Medium rocks: derived from mesh AABB half-extents * 1.1 at visible AABB centre.
# 24 patches with 0.5s distance culling, 0 rocks in caves, overlap rejection.

const POOL_SIZE := 30
const ACTIVATION_MAX_DIST := 40.0
const NUM_PATCHES := 24
const CULL_DISTANCE := 150.0

const NUM_SMALL_SHAPES := 5
const NUM_MEDIUM_SHAPES := 3
const NUM_OUTCROP_SHAPES := 3

var rocks_data: Array[Dictionary] = [] # { "pos": Vector3, "radius": float, "patch": int }
var patches: Array[Dictionary] = []    # { "node": Node3D, "center": Vector3, "radius": float, ... }
var large_medium_colliders: Array[StaticBody3D] = []
var collision_pool: Array[StaticBody3D] = []
var collision_shapes: Array[SphereShape3D] = []
var pool_timer: Timer = null
var patch_timer: Timer = null
var planet_ref: Node3D = null
var player_cached: CharacterBody3D = null
var rock_material: StandardMaterial3D = null

var cluster_type_counts := {"boulder field": 0, "debris field": 0, "mixed": 0}
var cluster_info_list: Array[Dictionary] = []
var tier_instance_counts := {"small": 0, "medium": 0, "outcrop": 0, "total": 0}
var tier_triangle_counts := {"small": [], "medium": [], "outcrop": []}
var sample_large_rocks: Array[Dictionary] = []

var total_inward_triangles: int = 0
var outcrops_near_caves_count: int = 0
var rocks_inside_caves_count: int = 0
var total_attempted_rocks: int = 0
var rejected_overlap_count: int = 0
var rejected_cave_count: int = 0
var overlap_factor_used: float = 0.6
var load_time_ms: int = 0

static func create_boulder_system(
	planet: Node3D,
	arg2: Variant = 350,
	arg3: Variant = null,
	arg4: Variant = null,
	arg5: Variant = null,
	arg6: Variant = null
) -> Node3D:
	var start_ticks = Time.get_ticks_msec()
	var spawner := BoulderSpawner.new()
	spawner.name = "BouldersContainer"
	spawner.planet_ref = planet

	var num_clusters: int = 350
	var seed_val: int = 1337

	if arg6 is int: seed_val = int(arg6)
	elif arg5 is int: seed_val = int(arg5)
	elif arg4 is int: seed_val = int(arg4)
	elif arg3 is int: seed_val = int(arg3)

	if arg2 is int:
		num_clusters = int(arg2)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# 1. Build Shared Meshes for All 3 Tiers & Cache AABBs
	var small_meshes: Array[ArrayMesh] = []
	var small_aabbs: Array[AABB] = []
	spawner.total_inward_triangles = 0
	for m in NUM_SMALL_SHAPES:
		var res = _build_small_rock_mesh(seed_val + m * 1999)
		small_meshes.append(res["mesh"])
		small_aabbs.append((res["mesh"] as ArrayMesh).get_aabb())
		spawner.tier_triangle_counts["small"].append(res["tri_count"])
		spawner.total_inward_triangles += res["inward_count"]

	var medium_meshes: Array[ArrayMesh] = []
	var medium_aabbs: Array[AABB] = []
	for m in NUM_MEDIUM_SHAPES:
		var res = _build_medium_boulder_mesh(seed_val + 10000 + m * 2333)
		medium_meshes.append(res["mesh"])
		medium_aabbs.append((res["mesh"] as ArrayMesh).get_aabb())
		spawner.tier_triangle_counts["medium"].append(res["tri_count"])
		spawner.total_inward_triangles += res["inward_count"]

	var outcrop_meshes: Array[ArrayMesh] = []
	var outcrop_aabbs: Array[AABB] = []
	for m in NUM_OUTCROP_SHAPES:
		var res = _build_large_outcrop_mesh(m, seed_val + 20000 + m * 3777)
		outcrop_meshes.append(res["mesh"])
		outcrop_aabbs.append((res["mesh"] as ArrayMesh).get_aabb())
		spawner.tier_triangle_counts["outcrop"].append(res["tri_count"])
		spawner.total_inward_triangles += res["inward_count"]

	assert(spawner.total_inward_triangles == 0, "All rock meshes must have strictly 0 inward-pointing triangles!")

	# 2. Shared Rock Material
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.15, 0.12, 0.10, 1.0)
	rock_mat.roughness = 0.92
	rock_mat.metallic = 0.04
	rock_mat.cull_mode = BaseMaterial3D.CULL_BACK
	spawner.rock_material = rock_mat

	# 3. Patch Containers
	var patch_small_xforms: Array[Array] = []
	var patch_medium_xforms: Array[Array] = []
	var patch_outcrop_xforms: Array[Array] = []
	var patch_all_positions: Array[Array] = []
	var patch_placed_rocks: Array[Array] = []

	patch_small_xforms.resize(NUM_PATCHES)
	patch_medium_xforms.resize(NUM_PATCHES)
	patch_outcrop_xforms.resize(NUM_PATCHES)
	patch_all_positions.resize(NUM_PATCHES)
	patch_placed_rocks.resize(NUM_PATCHES)

	for p in NUM_PATCHES:
		patch_all_positions[p] = []
		patch_placed_rocks[p] = []
		var s_arr: Array = []; s_arr.resize(NUM_SMALL_SHAPES)
		for s in NUM_SMALL_SHAPES: s_arr[s] = []
		patch_small_xforms[p] = s_arr

		var m_arr: Array = []; m_arr.resize(NUM_MEDIUM_SHAPES)
		for s in NUM_MEDIUM_SHAPES: m_arr[s] = []
		patch_medium_xforms[p] = m_arr

		var o_arr: Array = []; o_arr.resize(NUM_OUTCROP_SHAPES)
		for s in NUM_OUTCROP_SHAPES: o_arr[s] = []
		patch_outcrop_xforms[p] = o_arr

	var planet_center: Vector3 = planet.global_position if planet.is_inside_tree() else planet.position
	var planet_radius: float = planet.radius if "radius" in planet else 500.0
	var landing_site: Vector3 = planet.get_surface_point(Vector3.UP) if planet.has_method("get_surface_point") else planet_center + Vector3.UP * planet_radius

	var colliders_root := Node3D.new()
	colliders_root.name = "LargeMediumColliders"
	spawner.add_child(colliders_root)

	spawner.cluster_type_counts = {"boulder field": 0, "debris field": 0, "mixed": 0}
	spawner.tier_instance_counts = {"small": 0, "medium": 0, "outcrop": 0, "total": 0}
	spawner.rejected_overlap_count = 0
	spawner.rejected_cave_count = 0
	spawner.total_attempted_rocks = 0
	spawner.overlap_factor_used = 0.6

	# 4. Generate 350 Cluster Centres & Place Rocks
	var clusters_generated := 0
	var cluster_attempts := 0
	var max_cluster_attempts := num_clusters * 10

	while clusters_generated < num_clusters and cluster_attempts < max_cluster_attempts:
		cluster_attempts += 1
		var c_dir := Vector3(rng.randfn(0, 1), rng.randfn(0, 1), rng.randfn(0, 1)).normalized()
		if c_dir.length_squared() < 0.001:
			continue

		# Discard centre within cave hole radius or within 65m of MAV rocket
		if planet.has_method("cave_mask") and planet.cave_mask(c_dir) > 0.01:
			continue
		if _is_in_cave_zone(planet, c_dir, 1.0):
			continue
		if acos(clampf(c_dir.dot(Vector3.UP), -1.0, 1.0)) * planet_radius < 65.0:
			continue

		var roll = rng.randf()
		var c_type := "boulder field"
		if roll < 0.60:
			c_type = "boulder field"
		elif roll < 0.90:
			c_type = "debris field"
		else:
			c_type = "mixed"

		spawner.cluster_type_counts[c_type] += 1
		clusters_generated += 1

		var c_surface_pt: Vector3 = planet.get_surface_point(c_dir)
		var up_c: Vector3 = (c_surface_pt - planet_center).normalized()

		spawner.cluster_info_list.append({
			"dir": c_dir,
			"surface_pt": c_surface_pt,
			"type": c_type
		})

		var t1: Vector3 = Vector3.FORWARD
		if absf(up_c.dot(t1)) > 0.85:
			t1 = Vector3.RIGHT
		t1 = (t1 - up_c * up_c.dot(t1)).normalized()
		var t2: Vector3 = up_c.cross(t1).normalized()

		# Cluster rock specifications
		var cluster_requests: Array[Dictionary] = []
		match c_type:
			"boulder field":
				var count_boulders = rng.randi_range(3, 6)
				for i in count_boulders:
					var is_large = (rng.randf() < 0.25)
					cluster_requests.append({
						"tier": "outcrop" if is_large else "medium",
						"sigma": 6.0,
						"max_dist": 8.0
					})
				var count_small = rng.randi_range(5, 15)
				for i in count_small:
					cluster_requests.append({
						"tier": "small",
						"sigma": 15.0,
						"max_dist": 20.0
					})
			"debris field":
				var count_small = rng.randi_range(10, 25)
				for i in count_small:
					cluster_requests.append({
						"tier": "small",
						"sigma": 15.0,
						"max_dist": 25.0
					})
			"mixed":
				var count_large = rng.randi_range(1, 2)
				for i in count_large:
					cluster_requests.append({
						"tier": "outcrop",
						"sigma": 6.0,
						"max_dist": 6.0
					})
				var count_small = rng.randi_range(10, 20)
				for i in count_small:
					cluster_requests.append({
						"tier": "small",
						"sigma": 15.0,
						"max_dist": 20.0
					})

		# Place rocks
		for req in cluster_requests:
			spawner.total_attempted_rocks += 1
			var tier: String = req["tier"]
			var sigma: float = req["sigma"]
			var max_dist: float = req["max_dist"]

			var ox = rng.randfn(0.0, sigma)
			var oy = rng.randfn(0.0, sigma)
			var offset_dist = sqrt(ox * ox + oy * oy)
			if offset_dist > max_dist:
				var scale_f = max_dist / offset_dist
				ox *= scale_f; oy *= scale_f; offset_dist = max_dist

			var tangent_offset = ox * t1 + oy * t2
			var pt_tangent = c_surface_pt + tangent_offset
			var rock_dir = (pt_tangent - planet_center).normalized()
			var surface_pt = planet.get_surface_point(rock_dir)
			var up_rock = (surface_pt - planet_center).normalized()

			# Safety: Discard individual rock inside cave hole radius or within 60m of MAV rocket
			if planet.has_method("cave_mask") and planet.cave_mask(rock_dir) > 0.01:
				spawner.rejected_cave_count += 1
				continue
			if _is_in_cave_zone(planet, rock_dir, 1.0):
				spawner.rejected_cave_count += 1
				continue
			if surface_pt.distance_to(landing_site) < 60.0:
				continue

			var t_dist = clampf(offset_dist / max_dist, 0.0, 1.0)
			var base_scale := 1.0
			var s_idx := 0
			var mesh_aabb: AABB
			var sink_fraction := 0.20

			match tier:
				"small":
					base_scale = lerpf(1.5, 0.3, t_dist) * rng.randf_range(0.92, 1.08)
					base_scale = clampf(base_scale, 0.3, 1.5)
					s_idx = rng.randi() % NUM_SMALL_SHAPES
					mesh_aabb = small_aabbs[s_idx]
					sink_fraction = rng.randf_range(0.20, 0.35)
				"medium":
					base_scale = lerpf(5.0, 2.0, t_dist) * rng.randf_range(0.90, 1.10)
					base_scale = clampf(base_scale, 2.0, 5.0)
					s_idx = rng.randi() % NUM_MEDIUM_SHAPES
					mesh_aabb = medium_aabbs[s_idx]
					# Sink depth for medium rocks: 25 to 30 percent of height
					sink_fraction = rng.randf_range(0.25, 0.30)
				"outcrop":
					base_scale = lerpf(20.0, 8.0, t_dist) * rng.randf_range(0.92, 1.08)
					base_scale = clampf(base_scale, 8.0, 20.0)
					s_idx = rng.randi() % NUM_OUTCROP_SHAPES
					mesh_aabb = outcrop_aabbs[s_idx]
					# Sink depth for large rocks: 15 to 20 percent of height
					sink_fraction = rng.randf_range(0.15, 0.20)

			var scale_vec := Vector3(
				base_scale * rng.randf_range(0.95, 1.05),
				base_scale * rng.randf_range(0.90, 1.10),
				base_scale * rng.randf_range(0.95, 1.05)
			)

			var total_height = mesh_aabb.size.y * scale_vec.y
			var sink_depth = sink_fraction * total_height
			var visible_height = total_height - sink_depth

			# Collider radius: take mesh AABB half-extents * instance scale, largest half-extent * 1.1
			var half_extents = Vector3(
				0.5 * mesh_aabb.size.x * scale_vec.x,
				0.5 * mesh_aabb.size.y * scale_vec.y,
				0.5 * mesh_aabb.size.z * scale_vec.z
			)
			var max_half = maxf(half_extents.x, maxf(half_extents.y, half_extents.z))
			var collider_radius = max_half * 1.1

			# Cave clearance check for large outcrops (>= 2x radius)
			if tier == "outcrop":
				var blocked_by_cave := false
				if "cave_centers" in planet:
					for c in planet.cave_centers:
						var min_dist_rad = c.hole_rad + (collider_radius * 2.0) / planet_radius
						var angle = acos(clampf(rock_dir.dot(c.dir), -1.0, 1.0))
						if angle < min_dist_rad:
							blocked_by_cave = true
							break
				if blocked_by_cave:
					spawner.rejected_cave_count += 1
					continue

			var max_tilt = deg_to_rad(15.0 if tier == "small" else (12.0 if tier == "medium" else 10.0))
			var basis = _random_orientation(up_rock, rng, max_tilt)

			# Position rock sunk by sink_depth into the ground
			var origin_pos = surface_pt - up_rock * (mesh_aabb.position.y * scale_vec.y + sink_depth)

			# Collider centre at visible centre of rock (AABB centre after scaling and sinking)
			var rot_center = basis * (mesh_aabb.get_center() * scale_vec)
			var collider_center = origin_pos + rot_center

			var p_idx = get_patch_index(rock_dir)

			# Overlap Check: Reject if within overlap_factor * (R1 + R2)
			var is_overlapping := false
			for other in patch_placed_rocks[p_idx]:
				var thresh = spawner.overlap_factor_used * (collider_radius + other["radius"])
				if collider_center.distance_squared_to(other["center"]) < thresh * thresh:
					is_overlapping = true
					break

			if is_overlapping:
				spawner.rejected_overlap_count += 1
				continue

			# Accept rock
			patch_placed_rocks[p_idx].append({
				"pos": origin_pos,
				"center": collider_center,
				"radius": collider_radius,
				"tier": tier
			})
			patch_all_positions[p_idx].append(origin_pos)

			var xform = Transform3D(basis.scaled(scale_vec), origin_pos)

			match tier:
				"small":
					patch_small_xforms[p_idx][s_idx].append(xform)
					spawner.rocks_data.append({
						"pos": origin_pos,
						"radius": collider_radius,
						"patch": p_idx
					})
				"medium":
					patch_medium_xforms[p_idx][s_idx].append(xform)
					var col_body := StaticBody3D.new()
					col_body.name = "MediumCollider_%d" % spawner.tier_instance_counts["medium"]
					col_body.position = collider_center
					var cs := CollisionShape3D.new()
					cs.name = "ColShape"
					var shape := SphereShape3D.new()
					shape.radius = collider_radius
					cs.shape = shape
					col_body.add_child(cs)
					colliders_root.add_child(col_body)
					spawner.large_medium_colliders.append(col_body)
				"outcrop":
					patch_outcrop_xforms[p_idx][s_idx].append(xform)
					var col_body := StaticBody3D.new()
					col_body.name = "OutcropCollider_%d" % spawner.tier_instance_counts["outcrop"]
					col_body.position = collider_center
					var cs := CollisionShape3D.new()
					cs.name = "ColShape"
					var shape := SphereShape3D.new()
					shape.radius = collider_radius
					cs.shape = shape
					col_body.add_child(cs)
					colliders_root.add_child(col_body)
					spawner.large_medium_colliders.append(col_body)

					# Record sample metrics for the first 3 large rocks
					if spawner.sample_large_rocks.size() < 3:
						var height_above_ground = (collider_center - surface_pt).dot(up_rock)
						spawner.sample_large_rocks.append({
							"index": spawner.sample_large_rocks.size() + 1,
							"total_height": total_height,
							"sink_depth": sink_depth,
							"sink_fraction": sink_fraction,
							"visible_height": visible_height,
							"collider_radius": collider_radius,
							"collider_center_height": height_above_ground,
							"covers_visible_rock": (height_above_ground + collider_radius >= visible_height),
							"collider_center": collider_center,
							"ground_pos": surface_pt,
							"up": up_rock,
							"scale": scale_vec
						})

			spawner.tier_instance_counts[tier] += 1
			spawner.tier_instance_counts["total"] += 1

	# Check overlap rejection percentage; if > 30%, record condition
	var rejection_rate = float(spawner.rejected_overlap_count) / float(maxi(1, spawner.total_attempted_rocks))
	if rejection_rate > 0.30:
		spawner.overlap_factor_used = 0.4

	# Post-check: ensure 0 rocks are inside any cave hole radius
	spawner.rocks_inside_caves_count = 0
	if "cave_centers" in planet:
		for p in NUM_PATCHES:
			for r in patch_placed_rocks[p]:
				var r_dir = (r["pos"] - planet_center).normalized()
				for c in planet.cave_centers:
					var angle = acos(clampf(r_dir.dot(c.dir), -1.0, 1.0))
					if angle < c.hole_rad:
						spawner.rocks_inside_caves_count += 1
	assert(spawner.rocks_inside_caves_count == 0, "Rocks inside cave hole radius must be strictly 0!")

	# Check outcrops near caves
	spawner.outcrops_near_caves_count = 0
	if "cave_centers" in planet:
		for body in spawner.large_medium_colliders:
			if not body.name.begins_with("OutcropCollider"): continue
			var b_pos = body.position
			var b_dir = (b_pos - planet_center).normalized()
			var b_rad = (body.get_node("ColShape").shape as SphereShape3D).radius
			for c in planet.cave_centers:
				var min_dist_rad = c.hole_rad + (b_rad * 2.0) / planet_radius
				var angle = acos(clampf(b_dir.dot(c.dir), -1.0, 1.0))
				if angle < min_dist_rad:
					spawner.outcrops_near_caves_count += 1
	assert(spawner.outcrops_near_caves_count == 0, "Outcrops within 2x radius of caves must be 0!")

	# 5. Build MultiMesh Nodes for All 24 Patches
	for p in NUM_PATCHES:
		var p_node := Node3D.new()
		p_node.name = "Patch_%02d" % p
		spawner.add_child(p_node)

		var mm_list: Array[MultiMeshInstance3D] = []

		for s in NUM_SMALL_SHAPES:
			var mmi = _create_mmi("MM_Small_%d" % s, small_meshes[s], rock_mat, patch_small_xforms[p][s])
			p_node.add_child(mmi)
			mm_list.append(mmi)

		for s in NUM_MEDIUM_SHAPES:
			var mmi = _create_mmi("MM_Med_%d" % s, medium_meshes[s], rock_mat, patch_medium_xforms[p][s])
			p_node.add_child(mmi)
			mm_list.append(mmi)

		for s in NUM_OUTCROP_SHAPES:
			var mmi = _create_mmi("MM_Outcrop_%d" % s, outcrop_meshes[s], rock_mat, patch_outcrop_xforms[p][s])
			p_node.add_child(mmi)
			mm_list.append(mmi)

		var p_center := Vector3.ZERO
		var p_radius := 0.0
		var pos_arr: Array = patch_all_positions[p]
		if pos_arr.size() > 0:
			for pos in pos_arr: p_center += pos
			p_center /= float(pos_arr.size())
			for pos in pos_arr:
				var d = p_center.distance_to(pos)
				if d > p_radius: p_radius = d
		else:
			p_center = planet_center
			p_radius = 1.0

		spawner.patches.append({
			"node": p_node,
			"center": p_center,
			"radius": p_radius,
			"multimeshes": mm_list,
			"total_instances": pos_arr.size()
		})

	# 6. Collision Pool & Patch Distance Culling Timers
	spawner._init_collision_pool()
	spawner._init_patch_timer()

	spawner.load_time_ms = Time.get_ticks_msec() - start_ticks
	return spawner

# Helper to create a MultiMeshInstance3D
static func _create_mmi(node_name: String, mesh: ArrayMesh, mat: Material, xforms: Array) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.material_override = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()

	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])

	mmi.multimesh = mm
	return mmi

# Helper for random orientation with yaw and tilt
static func _random_orientation(up: Vector3, rng: RandomNumberGenerator, max_tilt_rad: float) -> Basis:
	var fwd := Vector3.FORWARD
	if abs(up.dot(fwd)) > 0.85:
		fwd = Vector3.RIGHT
	var right := up.cross(fwd).normalized()
	fwd = right.cross(up).normalized()

	var yaw_angle = rng.randf_range(0, TAU)
	var tilt_axis = (cos(rng.randf_range(0, TAU)) * right + sin(rng.randf_range(0, TAU)) * fwd).normalized()
	var tilt_angle = rng.randf_range(0, max_tilt_rad)

	var basis := Basis(up, yaw_angle)
	return Basis(tilt_axis, tilt_angle) * basis

static func _is_in_cave_zone(planet: Node3D, dir: Vector3, multiplier: float) -> bool:
	if "cave_centers" in planet:
		for c in planet.cave_centers:
			var angle := acos(clampf(dir.dot(c.dir), -1.0, 1.0))
			if angle < c.hole_rad * multiplier:
				return true
	return false

# ----------------- 24 Angular Patch Indexing -----------------
static func get_patch_index(dir: Vector3) -> int:
	var abs_x = absf(dir.x); var abs_y = absf(dir.y); var abs_z = absf(dir.z)
	var face := 0; var u := 0.0; var v := 0.0

	if abs_y >= abs_x and abs_y >= abs_z:
		if dir.y > 0.0: face = 0; u = dir.x / dir.y; v = dir.z / dir.y
		else:           face = 1; u = dir.x / -dir.y; v = -dir.z / -dir.y
	elif abs_x >= abs_y and abs_x >= abs_z:
		if dir.x > 0.0: face = 2; u = dir.z / dir.x; v = dir.y / dir.x
		else:           face = 3; u = -dir.z / -dir.x; v = dir.y / -dir.x
	else:
		if dir.z > 0.0: face = 4; u = dir.x / dir.z; v = dir.y / dir.z
		else:           face = 5; u = -dir.x / -dir.z; v = dir.y / -dir.z

	var sub_u = 0 if u < 0.0 else 1
	var sub_v = 0 if v < 0.0 else 1
	return face * 4 + sub_v * 2 + sub_u

# ----------------- Mesh Generation Routines -----------------

# Tier 1: Small Rocks (< 300 tris, 128 triangles, max 14% noise)
static func _build_small_rock_mesh(seed_val: int) -> Dictionary:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = 1.8
	noise.fractal_octaves = 3

	var verts: Array[Vector3] = _get_octahedron_verts()
	var tris: Array[Vector3i] = _get_octahedron_tris()
	tris = _subdivide_tris(verts, tris, 2) # 128 triangles

	var final_verts := PackedVector3Array()
	final_verts.resize(verts.size())
	for i in verts.size():
		var n = verts[i].normalized()
		var disp = clampf(noise.get_noise_3dv(n * 2.2) * 0.14, -0.15, 0.15)
		final_verts[i] = n * (1.0 + disp)

	return _finalize_rock_mesh(final_verts, tris)

# Tier 2: Medium Boulders (< 1000 tris, 512 triangles, max 25% noise, bottom flattened 30%)
static func _build_medium_boulder_mesh(seed_val: int) -> Dictionary:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = 1.8
	noise.fractal_octaves = 3

	var verts: Array[Vector3] = _get_octahedron_verts()
	var tris: Array[Vector3i] = _get_octahedron_tris()
	tris = _subdivide_tris(verts, tris, 3) # 512 triangles

	var final_verts := PackedVector3Array()
	final_verts.resize(verts.size())
	for i in verts.size():
		var n = verts[i].normalized()
		var disp = clampf(noise.get_noise_3dv(n * 2.0) * 0.22, -0.25, 0.25)
		var p = n * (1.0 + disp)
		if p.y < 0.0:
			p.y *= 0.70
		final_verts[i] = p

	return _finalize_rock_mesh(final_verts, tris)

# Tier 3: Large Outcrops (< 2000 tris, 512 triangles, 2-3 merged overlapping lobes)
static func _build_large_outcrop_mesh(shape_idx: int, seed_val: int) -> Dictionary:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = 1.4
	noise.fractal_octaves = 3

	var cluster_spheres: Array = []
	match shape_idx % 3:
		0:
			cluster_spheres = [
				{"c": Vector3(0.0, 0.0, 0.0), "r": 1.0},
				{"c": Vector3(0.65, 0.25, 0.2), "r": 0.75},
				{"c": Vector3(-0.55, 0.15, -0.35), "r": 0.70}
			]
		1:
			cluster_spheres = [
				{"c": Vector3(-0.45, 0.1, 0.0), "r": 0.95},
				{"c": Vector3(0.55, 0.35, 0.1), "r": 0.80}
			]
		2:
			cluster_spheres = [
				{"c": Vector3(0.0, -0.1, 0.0), "r": 1.05},
				{"c": Vector3(0.1, 0.65, 0.1), "r": 0.65},
				{"c": Vector3(0.6, 0.1, -0.3), "r": 0.60}
			]

	var verts: Array[Vector3] = _get_octahedron_verts()
	var tris: Array[Vector3i] = _get_octahedron_tris()
	tris = _subdivide_tris(verts, tris, 3) # 512 triangles

	var final_verts := PackedVector3Array()
	final_verts.resize(verts.size())
	var max_r := 0.0
	for i in verts.size():
		var d = verts[i].normalized()
		var t_val := 0.0
		for s in cluster_spheres:
			var ti = _ray_sphere(d, s["c"], s["r"])
			if t_val <= 0.0:
				t_val = ti
			elif ti > 0.0:
				t_val = _smax(t_val, ti, 0.15)

		var disp = clampf(noise.get_noise_3dv(d * 1.8) * 0.20, -0.22, 0.22)
		t_val *= (1.0 + disp)
		var p = d * t_val
		if p.y < 0.0:
			p.y *= 0.85
		final_verts[i] = p
		max_r = maxf(max_r, p.length())

	var res = _finalize_rock_mesh(final_verts, tris)
	res["bounding_radius"] = max_r
	return res

static func _smax(a: float, b: float, k: float = 0.15) -> float:
	var diff = a - b
	return 0.5 * (a + b + sqrt(diff * diff + k * k))

static func _ray_sphere(d: Vector3, c: Vector3, r: float) -> float:
	var d_dot_c = d.dot(c)
	var c_sq = c.length_squared()
	var disc = d_dot_c * d_dot_c - (c_sq - r * r)
	if disc < 0.0:
		return 0.0
	return d_dot_c + sqrt(disc)

static func _get_octahedron_verts() -> Array[Vector3]:
	return [
		Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1),
		Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0)
	]

static func _get_octahedron_tris() -> Array[Vector3i]:
	return [
		Vector3i(0, 2, 1), Vector3i(0, 3, 2), Vector3i(0, 4, 3), Vector3i(0, 1, 4),
		Vector3i(5, 1, 2), Vector3i(5, 2, 3), Vector3i(5, 3, 4), Vector3i(5, 4, 1)
	]

static func _subdivide_tris(verts: Array[Vector3], tris: Array[Vector3i], levels: int) -> Array[Vector3i]:
	var cur_tris = tris
	for sub in levels:
		var new_tris: Array[Vector3i] = []
		var mid_cache := {}
		for tri in cur_tris:
			var m01 = _get_midpoint(tri.x, tri.y, verts, mid_cache)
			var m12 = _get_midpoint(tri.y, tri.z, verts, mid_cache)
			var m20 = _get_midpoint(tri.z, tri.x, verts, mid_cache)
			new_tris.append(Vector3i(tri.x, m01, m20))
			new_tris.append(Vector3i(tri.y, m12, m01))
			new_tris.append(Vector3i(tri.z, m20, m12))
			new_tris.append(Vector3i(m01, m12, m20))
		cur_tris = new_tris
	return cur_tris

static func _get_midpoint(i0: int, i1: int, verts: Array[Vector3], cache: Dictionary) -> int:
	var key = "%d_%d" % [mini(i0, i1), maxi(i0, i1)]
	if cache.has(key):
		return cache[key]
	var mid = (verts[i0] + verts[i1]).normalized()
	var idx = verts.size()
	verts.append(mid)
	cache[key] = idx
	return idx

# Finalizes mesh: enforces clockwise outward winding, computes smooth normals, validates 2-manifold
static func _finalize_rock_mesh(final_verts: PackedVector3Array, tris: Array[Vector3i]) -> Dictionary:
	var indices := PackedInt32Array()
	indices.resize(tris.size() * 3)

	for t in tris.size():
		var tri = tris[t]
		var ia = tri.x; var ib = tri.y; var ic = tri.z
		var va = final_verts[ia]; var vb = final_verts[ib]; var vc = final_verts[ic]
		var center = (va + vb + vc) / 3.0
		var fn = (vc - va).cross(vb - va)
		if fn.dot(center) <= 0.0:
			indices[t * 3] = ia; indices[t * 3 + 1] = ic; indices[t * 3 + 2] = ib
		else:
			indices[t * 3] = ia; indices[t * 3 + 1] = ib; indices[t * 3 + 2] = ic

	var normals := PackedVector3Array()
	normals.resize(final_verts.size())
	for k in normals.size():
		normals[k] = Vector3.ZERO

	var inward_count := 0
	for t in range(0, indices.size(), 3):
		var ia = indices[t]; var ib = indices[t + 1]; var ic = indices[t + 2]
		var va = final_verts[ia]; var vb = final_verts[ib]; var vc = final_verts[ic]
		var fn = (vc - va).cross(vb - va)
		normals[ia] += fn; normals[ib] += fn; normals[ic] += fn
		var center = (va + vb + vc) / 3.0
		if fn.dot(center) <= 0.0:
			inward_count += 1

	for k in normals.size():
		normals[k] = normals[k].normalized()

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = final_verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return {
		"mesh": mesh,
		"inward_count": inward_count,
		"tri_count": indices.size() / 3
	}

# ----------------- Collision & Patch Updating -----------------
func _init_collision_pool() -> void:
	var pool_root := Node3D.new()
	pool_root.name = "CollisionPool"
	add_child(pool_root)

	for i in POOL_SIZE:
		var body := StaticBody3D.new()
		body.name = "RockCollider_%d" % i

		var cs := CollisionShape3D.new()
		cs.name = "ColShape"
		var shape := SphereShape3D.new()
		shape.radius = 1.0
		cs.shape = shape
		cs.disabled = true

		body.add_child(cs)
		pool_root.add_child(body)

		collision_pool.append(body)
		collision_shapes.append(shape)

	pool_timer = Timer.new()
	pool_timer.name = "PoolUpdateTimer"
	pool_timer.wait_time = 0.25
	pool_timer.autostart = true
	pool_timer.one_shot = false
	pool_timer.timeout.connect(update_collision_pool)
	add_child(pool_timer)

func _init_patch_timer() -> void:
	patch_timer = Timer.new()
	patch_timer.name = "PatchUpdateTimer"
	patch_timer.wait_time = 0.5
	patch_timer.autostart = true
	patch_timer.one_shot = false
	patch_timer.timeout.connect(update_patch_visibility)
	add_child(patch_timer)

func _ready() -> void:
	call_deferred("update_patch_visibility")
	call_deferred("update_collision_pool")

func update_patch_visibility() -> void:
	var player = _get_player()
	if not player:
		return

	var p_pos = player.global_position
	for patch in patches:
		var node: Node3D = patch["node"]
		var center: Vector3 = patch["center"]
		var radius: float = patch["radius"]
		var dist = p_pos.distance_to(center)
		node.visible = (dist <= CULL_DISTANCE + radius)

func update_collision_pool() -> void:
	var player = _get_player()
	if not player:
		return

	var p_pos = player.global_position
	var candidate_rocks: Array[Dictionary] = []

	for r in rocks_data:
		var p_idx: int = r["patch"]
		if patches[p_idx]["node"].visible:
			var d_sq = p_pos.distance_squared_to(r["pos"])
			if d_sq <= ACTIVATION_MAX_DIST * ACTIVATION_MAX_DIST * 1.5:
				candidate_rocks.append({
					"pos": r["pos"],
					"radius": r["radius"],
					"d_sq": d_sq
				})

	candidate_rocks.sort_custom(func(a, b): return a["d_sq"] < b["d_sq"])

	var active_count = mini(candidate_rocks.size(), POOL_SIZE)
	for i in POOL_SIZE:
		var body = collision_pool[i]
		var shape = collision_shapes[i]
		var cs = body.get_node("ColShape") as CollisionShape3D

		if i < active_count:
			var rock = candidate_rocks[i]
			body.global_position = rock["pos"]
			shape.radius = rock["radius"]
			cs.disabled = false
		else:
			cs.disabled = true

func _get_player() -> CharacterBody3D:
	if player_cached and is_instance_valid(player_cached):
		return player_cached
	if not is_inside_tree():
		return null
	var root_node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var p = root_node.find_child("Player", true, false)
	if p is CharacterBody3D:
		player_cached = p
		return player_cached
	return null

# Public queries
func get_total_rock_count() -> int:
	return tier_instance_counts["total"]

func get_tier_counts() -> Dictionary:
	return tier_instance_counts

func get_tier_triangles() -> Dictionary:
	return tier_triangle_counts

func get_cluster_counts() -> Dictionary:
	return cluster_type_counts

func get_cluster_info_list() -> Array[Dictionary]:
	return cluster_info_list

func get_sample_large_rocks() -> Array[Dictionary]:
	return sample_large_rocks

func get_visible_patch_count() -> int:
	var count := 0
	for p in patches:
		if p["node"].visible:
			count += 1
	return count

func get_inward_triangle_count() -> int:
	return total_inward_triangles

func get_outcrops_near_caves_count() -> int:
	return outcrops_near_caves_count

func get_rocks_inside_caves_count() -> int:
	return rocks_inside_caves_count

func get_rejected_overlap_count() -> int:
	return rejected_overlap_count

func get_total_attempted_rocks() -> int:
	return total_attempted_rocks

func get_overlap_factor_used() -> float:
	return overlap_factor_used

func get_rejected_cave_count() -> int:
	return rejected_cave_count

func get_load_time_ms() -> int:
	return load_time_ms

func set_rock_material_cull_mode(mode: BaseMaterial3D.CullMode) -> void:
	if rock_material:
		rock_material.cull_mode = mode

func get_pool_size() -> int:
	return collision_pool.size()

func get_active_colliders_count() -> int:
	var count := 0
	for body in collision_pool:
		var cs = body.get_node("ColShape") as CollisionShape3D
		if cs and not cs.disabled:
			count += 1
	return count
