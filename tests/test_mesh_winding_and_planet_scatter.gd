extends SceneTree

var frame_count := 0
var world: Node3D = null
var planet: ProceduralPlanet = null
var spawner: BoulderSpawner = null
var player: CharacterBody3D = null
var camera: Camera3D = null

var frame_times_spawn: Array[float] = []
var frame_times_flying: Array[float] = []
var initial_pos: Vector3 = Vector3.ZERO
var distant_pos: Vector3 = Vector3.ZERO
var distant_up: Vector3 = Vector3.UP

func _init() -> void:
	print("\n==================================================================")
	print("TESTING ROCK MESH SOLIDITY, WINDING & PLANET-WIDE 6,000 SCATTER")
	print("==================================================================")

func _process(delta: float) -> bool:
	frame_count += 1

	if frame_count == 1:
		var world_scene = load("res://Scenes/world.tscn")
		world = world_scene.instantiate()
		root.add_child(world)
		planet = world.get_node("ProceduralMars")
		player = world.get_node("Player")
		camera = player.get_node_or_null("CameraArm/SpringArm3D/Camera3D")
		spawner = planet.boulder_container as BoulderSpawner
		initial_pos = player.global_position
		return false

	# Frame 5: Verify Mesh Topology, Winding & Inward Normals
	if frame_count == 5:
		print("\n--- 1. MESH SOLIDITY, WINDING & 2-MANIFOLD CHECK ---")
		assert(spawner != null, "BoulderSpawner must exist!")
		var inward_tris = spawner.get_inward_triangle_count()
		var total_rocks = spawner.get_total_rock_count()
		print("Total procedural rocks placed: %d (requested 6000)" % total_rocks)
		assert(total_rocks >= 5950, "Total rock count must be ~6000!")

		print("Inward-pointing triangles across all 5 meshes: %d" % inward_tris)
		assert(inward_tris == 0, "Inward triangles must be strictly 0!")

		# Check 2-manifold property on the 5 meshes
		for p in spawner.patches:
			for mmi in p["multimeshes"]:
				var mesh: ArrayMesh = mmi.multimesh.mesh
				var arr = mesh.surface_get_arrays(0)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var edge_counts := {}
				for t in range(0, idx.size(), 3):
					var ia = idx[t]
					var ib = idx[t+1]
					var ic = idx[t+2]
					var e1 = Vector2i(mini(ia, ib), maxi(ia, ib))
					var e2 = Vector2i(mini(ib, ic), maxi(ib, ic))
					var e3 = Vector2i(mini(ic, ia), maxi(ic, ia))
					edge_counts[e1] = edge_counts.get(e1, 0) + 1
					edge_counts[e2] = edge_counts.get(e2, 0) + 1
					edge_counts[e3] = edge_counts.get(e3, 0) + 1
				for e in edge_counts.keys():
					assert(edge_counts[e] == 2, "Every edge must be shared by exactly 2 triangles!")
			break
		print("[PASS] 1: All 5 rock shapes are closed 2-manifold solids with CW winding and 0 inward normals.")

		print("\n--- 2. 24 PATCHES & DISTANCE CULLING (150M) ---")
		var total_patches = spawner.patches.size()
		print("Total patches on sphere: %d" % total_patches)
		assert(total_patches == 24, "Sphere must be partitioned into exactly 24 patches!")
		spawner.update_patch_visibility()
		var visible_patches = spawner.get_visible_patch_count()
		print("Visible patches at spawn (within 150m): %d / 24" % visible_patches)
		assert(visible_patches >= 1 and visible_patches <= 6, "Only nearby patches (1-6) should be visible near spawn!")
		print("[PASS] 2: 24 patches verified; distant patches culled (visible = false).")

		print("\n--- 3. COLLISION POOL VERIFICATION ---")
		spawner.update_collision_pool()
		var pool_size = spawner.get_pool_size()
		var active_bodies = spawner.get_active_colliders_count()
		print("Collision pool size: %d" % pool_size)
		print("Active rock colliders near player: %d" % active_bodies)
		assert(pool_size == 30, "Collision pool size must be 30!")
		assert(active_bodies > 0 and active_bodies <= 30, "Active bodies must be > 0 near player!")
		print("[PASS] 3: 30-body dynamic collision pool following rocks active.")

		print("\n--- 4. CAVE RAY-CHECK (OPEN/BLOCKED) ---")
		var space_state = world.get_world_3d().direct_space_state
		for i in planet.get_cave_pit_count():
			var cave_name = planet.get_cave_pit_name(i)
			var pit_pt = planet.get_cave_pit_surface_point(i)
			var pit_norm = (pit_pt - planet.global_position).normalized()
			var ray_origin = pit_pt + pit_norm * 8.0
			var ray_target = pit_pt - pit_norm * 8.0
			var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
			query.collision_mask = 1
			var hit = space_state.intersect_ray(query)
			if hit.is_empty():
				print("  - Cave [%s]: Raycast penetrates unobstructed -> OPEN" % cave_name)
			else:
				var hit_dist = ray_origin.distance_to(hit.position)
				if hit_dist >= 8.5:
					print("  - Cave [%s]: Raycast passed terrain hole to subterranean floor (%.1fm deep) -> OPEN" % [cave_name, hit_dist - 8.0])
				else:
					print("  - Cave [%s]: BLOCKED by obstacle at distance %.2fm" % [cave_name, hit_dist])
					assert(false, "Cave entrance is blocked!")
		print("[PASS] 4: Cave entrances verified OPEN.")
		return false

	# Frames 10-35: Steady state baseline frame times at spawn
	if frame_count >= 10 and frame_count < 35:
		frame_times_spawn.append(delta * 1000.0)

	# Frame 35: Test cull_mode = Disabled screenshot
	if frame_count == 35:
		spawner.set_rock_material_cull_mode(BaseMaterial3D.CULL_DISABLED)
		return false

	if frame_count == 40:
		# Capture cull_mode = Disabled screenshot
		var img_disabled = root.get_viewport().get_texture().get_image()
		img_disabled.save_png("res://tests/rocks_cull_disabled_test.png")
		print("Captured test screenshot with rock cull_mode = CULL_DISABLED.")
		# Restore cull_mode = Back
		spawner.set_rock_material_cull_mode(BaseMaterial3D.CULL_BACK)
		print("Restored rock cull_mode = CULL_BACK (solid rendering).")
		return false

	# Frame 45: Position camera 2 units above ground at spawn looking down at rocks
	if frame_count == 45:
		var spawn_up = (initial_pos - planet.global_position).normalized()
		var cam_pos = initial_pos + spawn_up * 2.0
		camera.global_position = cam_pos
		camera.look_at(cam_pos - spawn_up * 1.5 + Vector3(0.5, 0, 0.5), spawn_up)
		return false

	if frame_count == 50:
		var img_spawn = root.get_viewport().get_texture().get_image()
		img_spawn.save_png("res://tests/rocks_spawn_2m_closeup.png")
		print("Captured screenshot 2 units above ground at start point: rocks_spawn_2m_closeup.png")
		return false

	# Frame 55: Move player and camera ~300 units away on Mars surface
	if frame_count == 55:
		# 300 units on a 500 unit radius sphere is angle = 300 / 500 = 0.6 rad (~34 deg)
		var spawn_up = (initial_pos - planet.global_position).normalized()
		var tangent = Vector3.RIGHT
		if abs(spawn_up.dot(tangent)) > 0.85:
			tangent = Vector3.FORWARD
		tangent = (tangent - spawn_up * tangent.dot(spawn_up)).normalized()
		var distant_dir = (cos(0.6) * spawn_up + sin(0.6) * tangent).normalized()
		distant_pos = planet.get_surface_point(distant_dir)
		distant_up = (distant_pos - planet.global_position).normalized()

		player.global_position = distant_pos + distant_up * 1.5
		spawner.update_patch_visibility()
		spawner.update_collision_pool()

		var cam_pos = distant_pos + distant_up * 2.0
		camera.global_position = cam_pos
		camera.look_at(cam_pos - distant_up * 1.5 + Vector3(0.5, 0, 0.5), distant_up)
		print("\nMoved to distant location ~300m away on Mars.")
		print("Visible patches at distant point: %d / 24" % spawner.get_visible_patch_count())
		return false

	# Frames 60-85: Measure frame times while flying / at distant point
	if frame_count >= 60 and frame_count < 85:
		frame_times_flying.append(delta * 1000.0)
		# Simulate flying: rotate player position slightly along sphere
		var offset_dir = (distant_up + Vector3(0.01 * (frame_count - 60), 0, 0)).normalized()
		player.global_position = planet.get_surface_point(offset_dir) + offset_dir * 1.5

	# Frame 85: Capture screenshot 2 units above ground at ~300 units away
	if frame_count == 85:
		var cur_up = (player.global_position - planet.global_position).normalized()
		var cam_pos = player.global_position + cur_up * 0.5
		camera.global_position = cam_pos
		camera.look_at(cam_pos - cur_up * 1.5 + Vector3(0.5, 0, 0.5), cur_up)
		return false

	if frame_count == 90:
		var img_distant = root.get_viewport().get_texture().get_image()
		img_distant.save_png("res://tests/rocks_300m_distant_closeup.png")
		print("Captured screenshot 2 units above ground at ~300 units away: rocks_300m_distant_closeup.png")

		print("\n--- 5. PERFORMANCE MEASUREMENTS ---")
		var avg_spawn := 0.0
		for t in frame_times_spawn:
			avg_spawn += t
		avg_spawn /= float(frame_times_spawn.size())

		var avg_flying := 0.0
		for t in frame_times_flying:
			avg_flying += t
		avg_flying /= float(frame_times_flying.size())

		var delta_ft = avg_flying - avg_spawn
		print("Average frame time at spawn point: %.2f ms (%.1f FPS)" % [avg_spawn, 1000.0 / avg_spawn])
		print("Average frame time while flying:   %.2f ms (%.1f FPS)" % [avg_flying, 1000.0 / avg_flying])
		print("Frame time increase during flight: %.2f ms" % delta_ft)
		assert(delta_ft <= 2.0, "Frame time increase must be <= 2.0 ms! Got %.2f ms" % delta_ft)
		print("[PASS] 5: Performance within strict budget (< 2ms delta).")

		print("\n==================================================================")
		print("ALL CHECKS PASSED: ROCKS ARE SOLID, SCATTERED & DISTANCE-CULLED!")
		print("==================================================================")
		quit()
		return true

	return false
