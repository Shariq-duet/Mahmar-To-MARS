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

var target_medium_pos: Vector3 = Vector3.ZERO
var target_outcrop_body: StaticBody3D = null

func _init() -> void:
	print("\n==================================================================")
	print("TESTING 3 TIERS OF ROCKS: SMALL, MEDIUM BOULDERS & LARGE OUTCROPS")
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

	# Frame 5: Validate Tiers, Topology, Winding, Cave Clearances & Collision Setup
	if frame_count == 5:
		print("\n--- 1. INSTANCE COUNTS & TRIANGLE COUNTS PER TIER ---")
		assert(spawner != null, "BoulderSpawner must exist!")

		var counts = spawner.get_tier_counts()
		var tris = spawner.get_tier_triangles()

		print("Tier 1 - Small Rocks:     %d instances, tris per mesh: %s" % [counts["small"], str(tris["small"])])
		print("Tier 2 - Medium Boulders: %d instances, tris per mesh: %s" % [counts["medium"], str(tris["medium"])])
		print("Tier 3 - Large Outcrops:  %d instances, tris per mesh: %s" % [counts["outcrop"], str(tris["outcrop"])])
		print("Total Rocks across Mars:  %d instances" % counts["total"])

		assert(counts["small"] >= 5900, "Small rocks count should be ~6000!")
		assert(counts["medium"] >= 750, "Medium boulders count should be ~800!")
		assert(counts["outcrop"] >= 90, "Large outcrops count should be ~100!")

		for t in tris["small"]:
			assert(t < 300, "Small rock mesh must be < 300 triangles!")
		for t in tris["medium"]:
			assert(t < 1000, "Medium boulder mesh must be < 1000 triangles!")
		for t in tris["outcrop"]:
			assert(t < 2000, "Large outcrop mesh must be < 2000 triangles!")

		print("[PASS] 1: Instance and triangle count budgets verified for all 3 tiers.")

		print("\n--- 2. MESH INTEGRITY & CLOSED SOLID VERIFICATION ---")
		var inward_tris = spawner.get_inward_triangle_count()
		print("Inward-pointing triangles across all 11 meshes: %d" % inward_tris)
		assert(inward_tris == 0, "Inward normals must be strictly 0!")

		# Check 2-manifold closed property on each mesh in patch 0
		var p0 = spawner.patches[0]
		for mmi in p0["multimeshes"]:
			var mesh: ArrayMesh = mmi.multimesh.mesh
			var arr = mesh.surface_get_arrays(0)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var edge_counts := {}
			for t in range(0, idx.size(), 3):
				var ia = idx[t]; var ib = idx[t+1]; var ic = idx[t+2]
				var e1 = Vector2i(mini(ia, ib), maxi(ia, ib))
				var e2 = Vector2i(mini(ib, ic), maxi(ib, ic))
				var e3 = Vector2i(mini(ic, ia), maxi(ic, ia))
				edge_counts[e1] = edge_counts.get(e1, 0) + 1
				edge_counts[e2] = edge_counts.get(e2, 0) + 1
				edge_counts[e3] = edge_counts.get(e3, 0) + 1
			for e in edge_counts.keys():
				assert(edge_counts[e] == 2, "Mesh must be closed 2-manifold (every edge shared by 2 triangles)!")
		print("[PASS] 2: All meshes are closed 2-manifold solids with no see-through faces under CULL_BACK.")

		print("\n--- 3. CAVE PROXIMITY & OUT-CROP CLEARANCE CHECK ---")
		var outcrops_near_caves = spawner.get_outcrops_near_caves_count()
		print("Number of outcrops within 2x radius of any cave entrance: %d" % outcrops_near_caves)
		assert(outcrops_near_caves == 0, "Outcrops within 2x radius of cave entrance must be 0!")
		print("[PASS] 3: Zero outcrops near cave entrances verified.")

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

	# Frames 12-32: Steady state baseline frame times at spawn
	if frame_count >= 12 and frame_count < 32:
		frame_times_spawn.append(delta * 1000.0)

	# Frame 35: Move to ~300m away on Mars (flight trajectory)
	if frame_count == 35:
		var spawn_up = (initial_pos - planet.global_position).normalized()
		var tangent = Vector3.RIGHT
		if abs(spawn_up.dot(tangent)) > 0.85:
			tangent = Vector3.FORWARD
		tangent = (tangent - spawn_up * tangent.dot(spawn_up)).normalized()
		var distant_dir = (cos(0.6) * spawn_up + sin(0.6) * tangent).normalized()
		distant_pos = planet.get_surface_point(distant_dir)
		distant_up = (distant_pos - planet.global_position).normalized()

		player.global_position = distant_pos + distant_up * 1.5
		camera.global_position = distant_pos + distant_up * 2.0
		camera.look_at(distant_pos - distant_up * 1.5 + Vector3(0.5, 0, 0.5), distant_up)
		spawner.update_patch_visibility()
		spawner.update_collision_pool()
		return false

	# Frames 40-60: Measure steady state flight frame times
	if frame_count >= 40 and frame_count < 60:
		frame_times_flying.append(delta * 1000.0)
		var offset_dir = (distant_up + Vector3(0.01 * (frame_count - 40), 0, 0)).normalized()
		player.global_position = planet.get_surface_point(offset_dir) + offset_dir * 1.5

	# Frame 65: Move camera to Medium Boulder (2 units above ground)
	if frame_count == 65:
		var min_dist := 1e9
		for p in spawner.patches:
			for mmi in p["multimeshes"]:
				if mmi.name.begins_with("MM_Med_"):
					var mm: MultiMesh = mmi.multimesh
					for i in mm.instance_count:
						var xf = mm.get_instance_transform(i)
						var d = initial_pos.distance_to(xf.origin)
						if d < min_dist:
							min_dist = d
							target_medium_pos = xf.origin

		print("\nFound nearest Medium Boulder at %s (dist from spawn: %.1fm)" % [target_medium_pos, min_dist])
		var boulder_up = (target_medium_pos - planet.global_position).normalized()
		var cam_pos = target_medium_pos + boulder_up * 2.0 - boulder_up.cross(Vector3.UP).normalized() * 3.0
		camera.global_position = cam_pos
		camera.look_at(target_medium_pos + boulder_up * 0.4, boulder_up)
		player.global_position = target_medium_pos + boulder_up * 2.0
		spawner.update_patch_visibility()
		return false

	# Frame 70: Capture screenshot near medium boulder
	if frame_count == 70:
		var img_med = root.get_viewport().get_texture().get_image()
		img_med.save_png("res://tests/medium_boulder_2m_closeup.png")
		print("Captured screenshot 2 units above ground near medium boulder: medium_boulder_2m_closeup.png")
		return false

	# Frame 75: Move camera to Large Outcrop (10 units away)
	if frame_count == 75:
		var min_dist := 1e9
		for body in spawner.outcrop_colliders:
			var d = initial_pos.distance_to(body.global_position)
			if d < min_dist:
				min_dist = d
				target_outcrop_body = body

		var outcrop_pos = target_outcrop_body.global_position
		var outcrop_up = (outcrop_pos - planet.global_position).normalized()
		var shape = target_outcrop_body.get_node("ColShape").shape as SphereShape3D
		var radius = shape.radius
		print("Found nearest Large Outcrop at %s (radius: %.1fm, dist from spawn: %.1fm)" % [outcrop_pos, radius, min_dist])

		var tangent = outcrop_up.cross(Vector3.FORWARD).normalized()
		if tangent.length_squared() < 0.1:
			tangent = outcrop_up.cross(Vector3.RIGHT).normalized()
		var cam_pos = outcrop_pos + tangent * (radius + 10.0) + outcrop_up * 4.0
		camera.global_position = cam_pos
		camera.look_at(outcrop_pos + outcrop_up * 2.0, outcrop_up)
		player.global_position = cam_pos
		spawner.update_patch_visibility()
		return false

	# Frame 80: Capture screenshot 10 units away from outcrop
	if frame_count == 80:
		var img_outcrop = root.get_viewport().get_texture().get_image()
		img_outcrop.save_png("res://tests/large_outcrop_10m_closeup.png")
		print("Captured screenshot 10 units away from large outcrop: large_outcrop_10m_closeup.png")
		return false

	# Frame 85: Test Outcrop Collision (walk player into outcrop)
	if frame_count == 85:
		print("\n--- 5. PLAYER WALKING INTO OUTCROP COLLISION TEST ---")
		var outcrop_pos = target_outcrop_body.global_position
		var shape = target_outcrop_body.get_node("ColShape").shape as SphereShape3D
		var outcrop_radius = shape.radius
		var player_radius = 0.5

		var to_player = (player.global_position - outcrop_pos).normalized()
		var start_walk_pos = outcrop_pos + to_player * (outcrop_radius + player_radius + 1.2)
		player.global_position = start_walk_pos
		player.velocity = Vector3.ZERO

		var walk_dir = -to_player
		for step in 30:
			player.velocity = walk_dir * 5.0
			player.move_and_slide()

		var final_dist = player.global_position.distance_to(outcrop_pos)
		var min_allowed_dist = outcrop_radius + player_radius - 0.20
		print("Collision walk result: final distance to outcrop center = %.2fm (outcrop radius: %.2fm, minimum allowed: %.2fm)" % [
			final_dist, outcrop_radius, min_allowed_dist
		])
		assert(final_dist >= min_allowed_dist, "Player must be firmly stopped by outcrop collider boundary!")
		print("[PASS] 5: Outcrop collider stopped player movement firmly.")
		return false

	# Frame 90: Performance Summary & Final Check
	if frame_count == 90:
		print("\n--- 6. PERFORMANCE MEASUREMENTS ---")
		var avg_spawn := 0.0
		for t in frame_times_spawn: avg_spawn += t
		avg_spawn /= float(frame_times_spawn.size())

		var avg_flying := 0.0
		for t in frame_times_flying: avg_flying += t
		avg_flying /= float(frame_times_flying.size())

		var delta_ft = avg_flying - avg_spawn
		print("Average frame time at spawn point: %.2f ms (%.1f FPS)" % [avg_spawn, 1000.0 / avg_spawn])
		print("Average frame time while flying:   %.2f ms (%.1f FPS)" % [avg_flying, 1000.0 / avg_flying])
		print("Frame time increase during flight: %.2f ms" % delta_ft)
		assert(delta_ft <= 2.0, "Frame time increase must be <= 2.0 ms! Got %.2f ms" % delta_ft)
		print("[PASS] 6: Performance within strict budget (< 2ms delta).")

		print("\n==================================================================")
		print("ALL 3 TIERS OF ROCKS FULLY VERIFIED AND OPERATIONAL!")
		print("==================================================================")
		quit()
		return true

	return false
