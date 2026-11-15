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

var test_rock: Dictionary = {}
var side_test_done := false
var drop_test_done := false

func _init() -> void:
	print("\n==================================================================")
	print("VERIFICATION: ROCK DENSITY & LARGE/MEDIUM COLLIDERS")
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

	# Frame 5: Check Density, Rejections, Sample Rocks Colliders, and Cave Raycasts
	if frame_count == 5:
		print("\n--- 1. INSTANCE COUNTS & REJECTIONS (350 CLUSTERS) ---")
		assert(spawner != null, "BoulderSpawner must exist!")

		var t_counts = spawner.get_tier_counts()
		var c_counts = spawner.get_cluster_counts()
		var total_attempted = spawner.total_attempted_rocks
		var rejected_caves = spawner.get_rejected_cave_count()
		var rejected_overlaps = spawner.get_rejected_overlap_count()
		var overlap_pct = (float(rejected_overlaps) / float(maxi(total_attempted, 1))) * 100.0

		print("Clusters by Type (350 Total):")
		print("  - Boulder Fields (60%% target): %d (%.1f%%)" % [c_counts["boulder field"], (c_counts["boulder field"] / 350.0) * 100.0])
		print("  - Debris Fields  (30%% target): %d (%.1f%%)" % [c_counts["debris field"], (c_counts["debris field"] / 350.0) * 100.0])
		print("  - Mixed Fields   (10%% target): %d (%.1f%%)" % [c_counts["mixed"], (c_counts["mixed"] / 350.0) * 100.0])

		print("\nTotal Instances per Tier across Mars:")
		print("  - Tier 1: Small Rocks:     %d instances (target ~5000)" % t_counts["small"])
		print("  - Tier 2: Medium Boulders: %d instances" % t_counts["medium"])
		print("  - Tier 3: Large Outcrops:  %d instances" % t_counts["outcrop"])
		print("  - Med + Large Total:       %d instances (target >= 1000 or near)" % [t_counts["medium"] + t_counts["outcrop"]])
		print("  - TOTAL INSTANCES:         %d instances" % t_counts["total"])

		print("\nRejections:")
		print("  - Total attempted:          %d" % total_attempted)
		print("  - Rejected by cave-hole:    %d" % rejected_caves)
		print("  - Rejected by overlap:      %d (%.2f%%)" % [rejected_overlaps, overlap_pct])
		print("  - Overlap factor used:      %.2f" % spawner.overlap_factor_used)

		assert(spawner.get_rocks_inside_caves_count() == 0, "No rocks inside cave hole radius!")
		print("[PASS] Cave hole clearance verified (0 rocks in caves).")

		print("\n--- 2. SAMPLE LARGE ROCKS COLLIDER METRICS ---")
		var samples = spawner.get_sample_large_rocks()
		assert(samples.size() >= 3, "Must have at least 3 sample large rocks!")
		for i in range(min(3, samples.size())):
			var s = samples[i]
			print("Sample Large Rock #%d:" % (i + 1))
			print("  - Scale:                   (%.2f, %.2f, %.2f)" % [s["scale"].x, s["scale"].y, s["scale"].z])
			print("  - Scaled Total Height:     %.2f m" % s["total_height"])
			print("  - Sink Depth:              %.2f m (%.1f%% of height)" % [s["sink_depth"], s["sink_fraction"] * 100.0])
			print("  - Visible Height:          %.2f m" % s["visible_height"])
			print("  - Collider Radius:         %.2f m" % s["collider_radius"])
			print("  - Collider Center H above: %.2f m" % s["collider_center_height"])
			var top_reach = s["collider_center_height"] + s["collider_radius"]
			var covers: bool = s["covers_visible_rock"]
			print("  - Collider Top Reach:      %.2f m vs Visible Height %.2f m -> COVERS: %s" % [top_reach, s["visible_height"], str(covers)])
			assert(covers, "Collider must cover visible rock!")

		test_rock = samples[0]

		print("\n--- 3. CAVE RAY-CHECK (OPEN/BLOCKED) ---")
		var space_state = world.get_world_3d().direct_space_state
		for i in planet.get_cave_pit_count():
			var cave_name = planet.get_cave_pit_name(i)
			var pit_pt = planet.get_cave_pit_surface_point(i)
			var pit_norm = (pit_pt - planet.global_position).normalized()
			var ray_origin = pit_pt + pit_norm * 10.0
			var ray_target = pit_pt - pit_norm * 10.0
			var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
			query.collision_mask = 1
			var hit = space_state.intersect_ray(query)
			if hit.is_empty():
				print("  - Cave [%s]: Raycast penetrates unobstructed -> OPEN" % cave_name)
			else:
				var hit_dist = ray_origin.distance_to(hit.position)
				if hit_dist >= 10.5:
					print("  - Cave [%s]: Raycast reached cave floor at %.1fm -> OPEN" % [cave_name, hit_dist - 10.0])
				else:
					print("  - Cave [%s]: BLOCKED by obstacle at distance %.2fm" % [cave_name, hit_dist])
					assert(false, "Cave entrance is blocked!")
		print("[PASS] Cave entrances verified OPEN.")
		return false

	# Frames 10-25: Measure Steady-State Spawn Frame Times
	if frame_count >= 10 and frame_count < 25:
		frame_times_spawn.append(delta * 1000.0)
		return false

	# Frame 25: Setup Side-Walk Collision Test against test_rock
	if frame_count == 25:
		print("\n--- 4. COLLISION TEST: WALKING INTO LARGE ROCK FROM THE SIDE ---")
		var rock_up: Vector3 = test_rock["up"]
		var tangent = rock_up.cross(Vector3.UP).normalized()
		if tangent.length_squared() < 0.1:
			tangent = rock_up.cross(Vector3.RIGHT).normalized()

		# Position player on surface 3m outside collider radius
		var start_dist = test_rock["collider_radius"] + 3.0
		var player_ground = test_rock["ground_pos"] + tangent * start_dist
		player_ground = planet.get_surface_point((player_ground - planet.global_position).normalized())
		var p_up = (player_ground - planet.global_position).normalized()
		player.global_position = player_ground + p_up * 1.0
		player.velocity = Vector3.ZERO
		print("Starting side walk towards rock center from distance %.2f m..." % start_dist)
		return false

	# Frames 26-35: Walk towards rock center and verify player collision stops penetration
	if frame_count >= 26 and frame_count <= 35:
		var dir_to_rock = (test_rock["collider_center"] - player.global_position).normalized()
		# Walk at 8 m/s towards rock
		player.velocity = dir_to_rock * 8.0
		player.move_and_slide()
		return false

	if frame_count == 36:
		var cur_dist = player.global_position.distance_to(test_rock["collider_center"])
		print("Player final distance to collider center: %.2f m (Collider Radius: %.2f m)" % [cur_dist, test_rock["collider_radius"]])
		# Player radius is 0.4m, so distance to center should be >= collider_radius - 0.3 margin
		assert(cur_dist >= test_rock["collider_radius"] - 0.3, "Player penetrated into rock collider!")
		print("[PASS] Player stopped firmly at visible surface from side walk without penetration.")
		return false

	# Frame 38: Setup Drop-from-Above Collision Test onto test_rock
	if frame_count == 38:
		print("\n--- 5. COLLISION TEST: DROPPING ONTO LARGE ROCK FROM ABOVE ---")
		var rock_up: Vector3 = test_rock["up"]
		# Place player 4m above top of collider
		var top_pos = test_rock["collider_center"] + rock_up * (test_rock["collider_radius"] + 4.0)
		player.global_position = top_pos
		player.velocity = Vector3.ZERO
		print("Dropping player onto rock from height 4.0m above collider top...")
		return false

	# Frames 39-50: Drop player onto rock
	if frame_count >= 39 and frame_count <= 50:
		var gravity_dir = (planet.global_position - player.global_position).normalized()
		player.velocity += gravity_dir * 18.0 * delta
		player.move_and_slide()
		return false

	if frame_count == 51:
		var cur_dist = player.global_position.distance_to(test_rock["collider_center"])
		var rock_up: Vector3 = test_rock["up"]
		var height_above_center = (player.global_position - test_rock["collider_center"]).dot(rock_up)
		print("Player landed on rock. Distance to center: %.2f m, Height above center: %.2f m (Radius: %.2f m)" % [cur_dist, height_above_center, test_rock["collider_radius"]])
		assert(cur_dist >= test_rock["collider_radius"] - 0.3, "Player sank into rock!")
		assert(height_above_center >= test_rock["collider_radius"] - 0.3, "Player must be resting on top of rock!")
		print("[PASS] Player landed and stopped on top of rock without sinking into it.")
		return false

	# Frame 53: Capture Close-up Screenshot (2 units above ground next to large rock)
	if frame_count == 53:
		print("\n--- 6. CAPTURING CLOSE-UP SCREENSHOT (2m ABOVE GROUND) ---")
		var rock_ground: Vector3 = test_rock["ground_pos"]
		var rock_up: Vector3 = test_rock["up"]
		var tangent = rock_up.cross(Vector3.UP).normalized()
		if tangent.length_squared() < 0.1:
			tangent = rock_up.cross(Vector3.RIGHT).normalized()

		# Camera placed 2 units above ground, offset horizontally to view rock and ground intersection
		var cam_dist = test_rock["collider_radius"] + 3.0
		var cam_ground = rock_ground + tangent * cam_dist
		cam_ground = planet.get_surface_point((cam_ground - planet.global_position).normalized())
		var c_up = (cam_ground - planet.global_position).normalized()
		var cam_pos = cam_ground + c_up * 2.0
		var look_target = rock_ground + rock_up * (test_rock["visible_height"] * 0.4)

		player.global_position = cam_pos
		camera.global_position = cam_pos
		camera.look_at(look_target, c_up)
		spawner.update_patch_visibility()
		return false

	if frame_count == 55:
		var tex = root.get_viewport().get_texture()
		if tex:
			var img_rock = tex.get_image()
			if img_rock:
				img_rock.save_png("res://tests/large_rock_2m_closeup.png")
				print("Captured close-up screenshot: tests/large_rock_2m_closeup.png")
		return false

	# Frame 58: Position Camera 60 units above Boulder Field
	if frame_count == 58:
		print("\n--- 7. CAPTURING TOP-DOWN SCREENSHOT (60m ABOVE BOULDER FIELD) ---")
		var bf_center := Vector3.ZERO
		for c in spawner.get_cluster_info_list():
			if c["type"] == "boulder field":
				bf_center = c["surface_pt"]
				break

		var c_up = (bf_center - planet.global_position).normalized()
		var cam_pos = bf_center + c_up * 60.0
		var tangent = c_up.cross(Vector3.FORWARD).normalized()
		if tangent.length_squared() < 0.1:
			tangent = c_up.cross(Vector3.RIGHT).normalized()

		player.global_position = bf_center + c_up * 1.5
		camera.global_position = cam_pos
		camera.look_at(bf_center, tangent)
		spawner.update_patch_visibility()
		return false

	if frame_count == 60:
		var tex = root.get_viewport().get_texture()
		if tex:
			var img_bf = tex.get_image()
			if img_bf:
				img_bf.save_png("res://tests/boulder_field_topdown_60m.png")
				print("Captured top-down screenshot: tests/boulder_field_topdown_60m.png")
		return false

	# Frame 63: Move player and camera ~300m away on Mars for flight performance measurement
	if frame_count == 63:
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

	# Frames 65-80: Measure steady state flight frame times
	if frame_count >= 65 and frame_count < 80:
		frame_times_flying.append(delta * 1000.0)
		var offset_dir = (distant_up + Vector3(0.01 * (frame_count - 65), 0, 0)).normalized()
		player.global_position = planet.get_surface_point(offset_dir) + offset_dir * 1.5
		return false

	# Frame 85: Report performance measurements and conclude
	if frame_count == 85:
		print("\n--- 8. PERFORMANCE MEASUREMENTS ---")
		var avg_spawn := 0.0
		for t in frame_times_spawn: avg_spawn += t
		avg_spawn /= float(frame_times_spawn.size())

		var avg_flying := 0.0
		for t in frame_times_flying: avg_flying += t
		avg_flying /= float(frame_times_flying.size())

		var delta_ft = avg_flying - avg_spawn
		print("Average frame time at spawn point: %.2f ms (%.1f FPS)" % [avg_spawn, 1000.0 / avg_spawn])
		print("Average frame time while flying:   %.2f ms (%.1f FPS)" % [avg_flying, 1000.0 / avg_flying])
		print("Frame time delta during flight:    %+.2f ms" % delta_ft)

		print("\n==================================================================")
		print("ALL ROCK DENSITY AND COLLIDER VERIFICATIONS COMPLETED!")
		print("==================================================================")
		quit()
		return true

	return false
