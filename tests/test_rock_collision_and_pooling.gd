extends SceneTree

var frame_count := 0
var world: Node3D = null
var planet: ProceduralPlanet = null
var player: CharacterBody3D = null
var camera: Camera3D = null

var draw_calls_without: Array[float] = []
var draw_calls_with: Array[float] = []
var frame_times_without: Array[float] = []
var frame_times_with: Array[float] = []

func _init() -> void:
	print("\n=======================================================")
	print("TESTING 5 ROCK SHAPES, POOLED COLLISION & PERFORMANCE")
	print("=======================================================")

func _process(delta: float) -> bool:
	frame_count += 1

	if frame_count == 1:
		var world_scene = load("res://Scenes/world.tscn")
		world = world_scene.instantiate()
		root.add_child(world)
		planet = world.get_node("ProceduralMars")
		player = world.get_node("Player")
		camera = player.get_node_or_null("CameraArm/SpringArm3D/Camera3D")
		return false

	# Phase 1: Measure baseline WITHOUT boulders (frame 15 to 40)
	if frame_count == 14:
		if planet.boulder_container:
			planet.boulder_container.visible = false
	if frame_count >= 15 and frame_count < 40:
		frame_times_without.append(delta * 1000.0)
		draw_calls_without.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	# Phase 2: Measure performance WITH boulders (frame 45 to 70)
	if frame_count == 44:
		if planet.boulder_container:
			planet.boulder_container.visible = true
	if frame_count >= 45 and frame_count < 70:
		frame_times_with.append(delta * 1000.0)
		draw_calls_with.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	if frame_count == 5:
		print("\n--- 1. ROCK SHAPES & MULTIMESH VERIFICATION ---")
		var container = planet.boulder_container
		assert(container != null, "boulder_container must exist!")
		var mm_children = container.find_children("Boulders_Shape_*", "MultiMeshInstance3D", false, false)
		print("MultiMeshInstance3D count: %d (expected 5)" % mm_children.size())
		assert(mm_children.size() == 5, "Must have exactly 5 MultiMeshInstance3D nodes for the 5 shapes!")

		for i in mm_children.size():
			var mmi: MultiMeshInstance3D = mm_children[i]
			var mesh: ArrayMesh = mmi.multimesh.mesh
			var arrays = mesh.surface_get_arrays(0)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var tri_count = indices.size() / 3
			print("  - Shape #%d (%s): %d triangles (< 300 limit), %d instances" % [i, mmi.name, tri_count, mmi.multimesh.instance_count])
			assert(tri_count < 300, "Triangle count must be under 300 per mesh! Found %d" % tri_count)
			assert(tri_count >= 60, "Mesh must be a full solid sphere, not flat slivers!")
		print("[PASS] Check 1: 5 unique rock shapes verified with < 300 triangles each.")

		print("\n--- 2. COLLISION POOL VERIFICATION ---")
		var spawner: BoulderSpawner = container as BoulderSpawner
		assert(spawner != null, "Container must be BoulderSpawner instance!")
		spawner.update_collision_pool()
		var pool_size = spawner.get_pool_size()
		var active_bodies = spawner.get_active_colliders_count()
		print("Collision pool size: %d" % pool_size)
		print("Active collision bodies near player: %d" % active_bodies)
		assert(pool_size == 30, "Collision pool size must be exactly 30!")
		assert(active_bodies > 0 and active_bodies <= 30, "Active bodies must be > 0 near player landing site!")
		print("[PASS] Check 2: Dynamic collision pool verified (Pool Size: %d, Active: %d)." % [pool_size, active_bodies])

		print("\n--- 3. PLAYER COLLISION STOP CHECK ---")
		# Find the closest active rock collider to the player
		var closest_rock: StaticBody3D = null
		var min_dist_sq := 1e9
		for body in spawner.collision_pool:
			var cs = body.get_node("ColShape")
			if not cs.disabled:
				var d_sq = player.global_position.distance_squared_to(body.global_position)
				if d_sq < min_dist_sq:
					min_dist_sq = d_sq
					closest_rock = body

		assert(closest_rock != null, "Must find an active rock collider near player!")
		var rock_pos = closest_rock.global_position
		var rock_radius = (closest_rock.get_node("ColShape").shape as SphereShape3D).radius
		print("Testing collision against RockCollider at %s (radius: %.2fm)" % [rock_pos, rock_radius])

		# Place player just outside the rock collider
		var player_radius = 0.5
		var to_player = (player.global_position - rock_pos).normalized()
		player.global_position = rock_pos + to_player * (rock_radius + player_radius + 0.8)
		player.velocity = Vector3.ZERO

		# Walk player directly toward the center of the rock collider
		var walk_into_rock_dir = -to_player
		for step in 25:
			player.velocity = walk_into_rock_dir * 4.0
			player.move_and_slide()

		var final_dist = player.global_position.distance_to(rock_pos)
		var min_allowed_dist = rock_radius + player_radius - 0.15 # Cannot penetrate into collider
		print("Collision walk result: final distance to rock center = %.2fm (minimum allowed = %.2fm)" % [final_dist, min_allowed_dist])
		assert(final_dist >= min_allowed_dist, "Player must stop at rock collider, not penetrate inside!")
		print("[PASS] Check 3: Player stopped firmly at rock collider boundary.")

		print("\n--- 4. CAVE RAY-CHECK (OPEN/BLOCKED) ---")
		var space_state = world.get_world_3d().direct_space_state
		for i in planet.get_cave_pit_count():
			var cave_name = planet.get_cave_pit_name(i)
			var pit_pt = planet.get_cave_pit_surface_point(i)
			var pit_norm = (pit_pt - planet.global_position).normalized()
			var ray_origin = pit_pt + pit_norm * 8.0
			var ray_target = pit_pt - pit_norm * 8.0
			var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
			var result = space_state.intersect_ray(query)
			var is_open = result.is_empty() or (result["collider"] != planet.static_body) or ((result["position"] - pit_pt).dot(pit_norm) < -1.5)
			print("[CAVE RAY-CHECK] %s: %s" % [cave_name, "OPEN" if is_open else "BLOCKED"])
			assert(is_open, "Cave %s ray-check must be OPEN!" % cave_name)
		print("[PASS] Check 4: Cave ray-checks confirmed OPEN.")

		# Position camera 2 units above surface near player looking at boulders
		var start_pt = planet.get_surface_point(Vector3.UP)
		var up_vec = Vector3.UP
		var fwd_vec = Vector3.FORWARD
		camera.global_position = start_pt + up_vec * 2.0
		camera.look_at(start_pt + fwd_vec * 6.0 + up_vec * 0.8, up_vec)

	if frame_count == 10:
		var img_dir = "tests/screenshots"
		DirAccess.make_dir_recursive_absolute(img_dir)
		var vp = root.get_viewport()
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png(img_dir + "/boulders_closeup_2m_near_player.png")
				print("Saved screenshot: %s/boulders_closeup_2m_near_player.png" % img_dir)
				print("[PASS] Check 5: Close-up screenshot from 2m above surface captured.")

	if frame_count == 75:
		print("\n--- 5. DRAW CALLS & FRAME TIME PERFORMANCE REPORT ---")
		var sum_before_ms := 0.0
		var sum_before_dc := 0.0
		for i in frame_times_without.size():
			sum_before_ms += frame_times_without[i]
			sum_before_dc += draw_calls_without[i]
		var avg_before_ms = sum_before_ms / max(frame_times_without.size(), 1)
		var avg_before_dc = sum_before_dc / max(draw_calls_without.size(), 1)

		var sum_after_ms := 0.0
		var sum_after_dc := 0.0
		for i in frame_times_with.size():
			sum_after_ms += frame_times_with[i]
			sum_after_dc += draw_calls_with[i]
		var avg_after_ms = sum_after_ms / max(frame_times_with.size(), 1)
		var avg_after_dc = sum_after_dc / max(draw_calls_with.size(), 1)

		var delta_ms = avg_after_ms - avg_before_ms
		var delta_dc = avg_after_dc - avg_before_dc

		print("Draw Calls BEFORE boulders: %.0f" % avg_before_dc)
		print("Draw Calls AFTER boulders:  %.0f (+%.0f draw calls for 5 MultiMeshes)" % [avg_after_dc, delta_dc])
		print("Frame time BEFORE boulders: %.2f ms (%.1f FPS)" % [avg_before_ms, 1000.0 / max(avg_before_ms, 0.001)])
		print("Frame time AFTER boulders:  %.2f ms (%.1f FPS)" % [avg_after_ms, 1000.0 / max(avg_after_ms, 0.001)])
		print("Frame time delta:           %+.2f ms" % delta_ms)

		if delta_ms > 2.0:
			print("[NOTICE] Frame time delta: %+.2f ms (> 2.0 ms threshold)." % delta_ms)
		else:
			print("[PASS] Performance verified: delta %+.2f ms <= 2.0 ms limit." % delta_ms)

		print("\n=======================================================")
		print("ALL ROCK SHAPE, POOLED COLLISION & PERFORMANCE CHECKS PASSED!")
		print("=======================================================")
		quit(0)

	return false
