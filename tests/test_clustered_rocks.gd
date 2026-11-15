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

var boulder_field_center := Vector3.ZERO
var debris_field_center := Vector3.ZERO

func _init() -> void:
	print("\n==================================================================")
	print("TESTING CLUSTERED ROCK GROUPS: BOULDER FIELDS, DEBRIS & MIXED")
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

	# Frame 5: Validate Clusters, Tier Instances, Cave Clearance, Overlaps & Raycasts
	if frame_count == 5:
		print("\n--- 1. CLUSTER COUNTS BY TYPE & TIERS ---")
		assert(spawner != null, "BoulderSpawner must exist!")

		var c_counts = spawner.get_cluster_counts()
		var t_counts = spawner.get_tier_counts()
		var t_tris = spawner.get_tier_triangles()
		var load_time = spawner.get_load_time_ms()

		print("Load Time for Clustered Placement: %d ms" % load_time)
		print("Clusters by Type (120 Total):")
		print("  - Boulder Fields (60%% target): %d (%.1f%%)" % [c_counts["boulder field"], (c_counts["boulder field"] / 120.0) * 100.0])
		print("  - Debris Fields  (30%% target): %d (%.1f%%)" % [c_counts["debris field"], (c_counts["debris field"] / 120.0) * 100.0])
		print("  - Mixed Fields   (10%% target): %d (%.1f%%)" % [c_counts["mixed"], (c_counts["mixed"] / 120.0) * 100.0])

		print("\nTotal Instances per Tier across Mars:")
		print("  - Tier 1: Small Rocks:     %d instances (%s tris each)" % [t_counts["small"], str(t_tris["small"])])
		print("  - Tier 2: Medium Boulders: %d instances (%s tris each)" % [t_counts["medium"], str(t_tris["medium"])])
		print("  - Tier 3: Large Outcrops:  %d instances (%s tris each)" % [t_counts["outcrop"], str(t_tris["outcrop"])])
		print("  - TOTAL INSTANCES:         %d instances" % t_counts["total"])

		assert(c_counts["boulder field"] > 50, "Boulder fields should be ~60% of 120!")
		assert(c_counts["debris field"] > 25, "Debris fields should be ~30% of 120!")
		assert(c_counts["mixed"] >= 5, "Mixed fields should be ~10% of 120!")
		assert(t_counts["total"] > 1000, "Should have clustered rocks across Mars!")
		print("[PASS] 1: Cluster distribution and tier instance budgets verified.")

		print("\n--- 2. SAFETY: CAVE PROXIMITY & OVERLAP REJECTION ---")
		var rocks_in_caves = spawner.get_rocks_inside_caves_count()
		var rejected_overlaps = spawner.get_rejected_overlap_count()
		var rejected_caves = spawner.get_rejected_cave_count()

		print("Rocks inside cave hole radius: %d" % rocks_in_caves)
		print("Candidates rejected by cave proximity: %d" % rejected_caves)
		print("Candidates rejected by 0.6*(R1+R2) overlap check: %d" % rejected_overlaps)

		assert(rocks_in_caves == 0, "Rocks inside cave hole radius must be strictly 0!")
		assert(rejected_overlaps > 0, "Overlap rejection check must actively prevent clipping!")
		print("[PASS] 2: Zero rocks inside caves; overlap protection verified.")

		print("\n--- 3. CAVE RAY-CHECK (OPEN/BLOCKED) ---")
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
		print("[PASS] 3: Cave entrances verified OPEN.")
		return false

	# Frames 12-30: Measure steady state frame times at Spawn
	if frame_count >= 12 and frame_count < 30:
		frame_times_spawn.append(delta * 1000.0)

	# Frame 35: Locate Boulder Field and position Camera 60 units directly above it
	if frame_count == 35:
		for c in spawner.get_cluster_info_list():
			if c["type"] == "boulder field":
				boulder_field_center = c["surface_pt"]
				break

		var c_up = (boulder_field_center - planet.global_position).normalized()
		var cam_pos = boulder_field_center + c_up * 60.0
		var tangent = c_up.cross(Vector3.FORWARD).normalized()
		if tangent.length_squared() < 0.1:
			tangent = c_up.cross(Vector3.RIGHT).normalized()

		camera.global_position = cam_pos
		camera.look_at(boulder_field_center, tangent)
		player.global_position = boulder_field_center + c_up * 1.5
		spawner.update_patch_visibility()
		print("\nPositioned camera 60 units above Boulder Field at %s" % boulder_field_center)
		return false

	# Frame 40: Capture top-down screenshot of Boulder Field
	if frame_count == 40:
		var img_bf = root.get_viewport().get_texture().get_image()
		img_bf.save_png("res://tests/boulder_field_topdown_60m.png")
		print("Captured top-down screenshot: boulder_field_topdown_60m.png")
		return false

	# Frame 45: Locate Debris Field and position Camera 60 units directly above it
	if frame_count == 45:
		for c in spawner.get_cluster_info_list():
			if c["type"] == "debris field":
				debris_field_center = c["surface_pt"]
				break

		var c_up = (debris_field_center - planet.global_position).normalized()
		var cam_pos = debris_field_center + c_up * 60.0
		var tangent = c_up.cross(Vector3.FORWARD).normalized()
		if tangent.length_squared() < 0.1:
			tangent = c_up.cross(Vector3.RIGHT).normalized()

		camera.global_position = cam_pos
		camera.look_at(debris_field_center, tangent)
		player.global_position = debris_field_center + c_up * 1.5
		spawner.update_patch_visibility()
		print("Positioned camera 60 units above Debris Field at %s" % debris_field_center)
		return false

	# Frame 50: Capture top-down screenshot of Debris Field
	if frame_count == 50:
		var img_df = root.get_viewport().get_texture().get_image()
		img_df.save_png("res://tests/debris_field_topdown_60m.png")
		print("Captured top-down screenshot: debris_field_topdown_60m.png")
		return false

	# Frame 55: Move player and camera ~300m away on Mars for flight performance measurement
	if frame_count == 55:
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

	# Frames 60-80: Measure steady state flight frame times
	if frame_count >= 60 and frame_count < 80:
		frame_times_flying.append(delta * 1000.0)
		var offset_dir = (distant_up + Vector3(0.01 * (frame_count - 60), 0, 0)).normalized()
		player.global_position = planet.get_surface_point(offset_dir) + offset_dir * 1.5

	# Frame 85: Report performance measurements and conclude
	if frame_count == 85:
		print("\n--- 4. PERFORMANCE MEASUREMENTS ---")
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
		assert(delta_ft <= 2.0, "Frame time increase must be <= 2.0 ms! Got %+.2f ms" % delta_ft)
		print("[PASS] 4: Performance within strict budget (< 2ms delta).")

		print("\n==================================================================")
		print("ALL CLUSTERED ROCK GROUP CHECKS PASSED SUCCESSFULLY!")
		print("==================================================================")
		quit()
		return true

	return false
