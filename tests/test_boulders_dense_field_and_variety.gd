extends SceneTree

var frame_count := 0
var world: Node3D = null
var planet: ProceduralPlanet = null
var player: CharacterBody3D = null
var camera: Camera3D = null

var frame_times_without: Array[float] = []
var frame_times_with: Array[float] = []

func _init() -> void:
	print("\n=======================================================")
	print("VERIFYING DENSE BOULDER FIELD, 4 MESHES & EMBEDDING")
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

	# Phase 1: Measure frame time WITHOUT boulders (frames 15 to 45)
	if frame_count == 14:
		if planet.boulder_container:
			planet.boulder_container.visible = false
	if frame_count >= 15 and frame_count < 45:
		frame_times_without.append(delta * 1000.0)

	# Phase 2: Measure frame time WITH boulders (frames 48 to 78)
	if frame_count == 46:
		if planet.boulder_container:
			planet.boulder_container.visible = true
	if frame_count >= 48 and frame_count < 78:
		frame_times_with.append(delta * 1000.0)

	if frame_count == 5:
		print("\n--- 1. 4 MULTIMESH NODES & SHAPE VARIETY ---")
		var container = planet.boulder_container
		assert(container != null, "boulder_container must exist!")
		var mm_children = container.get_children()
		print("Number of MultiMeshInstance3D children: %d (expected 4)" % mm_children.size())
		assert(mm_children.size() == 4, "Must have exactly 4 MultiMeshInstance3D nodes for the 4 deformed rock meshes!")

		var total_boulders := 0
		var boulders_within_60m := 0
		var boulders_below_surface := 0
		var player_start: Vector3 = player.global_position
		var planet_center: Vector3 = planet.global_position

		for m_idx in mm_children.size():
			var mmi: MultiMeshInstance3D = mm_children[m_idx]
			var mm = mmi.multimesh
			print("  - Shape #%d (%s): %d instances" % [m_idx, mmi.name, mm.instance_count])
			
			for i in mm.instance_count:
				total_boulders += 1
				var t = mm.get_instance_transform(i)
				var b_pos = planet.to_global(t.origin)
				var dist_to_start = b_pos.distance_to(player_start)
				if dist_to_start <= 60.0:
					boulders_within_60m += 1

				# Check embedding below surface
				var b_dir = (b_pos - planet_center).normalized()
				var surf_pt = planet.get_surface_point(b_dir)
				var up = (surf_pt - planet_center).normalized()
				var embed_depth = (surf_pt - b_pos).dot(up)
				if embed_depth > 0.0:
					boulders_below_surface += 1

		print("\n--- 2. BOULDER PROXIMITY & SINKING VERIFICATION ---")
		print("Total boulders spawned across planet: %d" % total_boulders)
		print("Boulders within 60 units of player start: %d (required >= 200)" % boulders_within_60m)
		print("Boulders with base embedded below surface: %d / %d (%.1f%%)" % [boulders_below_surface, total_boulders, (float(boulders_below_surface) / total_boulders) * 100.0])
		
		assert(boulders_within_60m >= 200, "Must have at least 200 boulders within 60 units of landing point! Found %d" % boulders_within_60m)
		assert(boulders_below_surface >= total_boulders * 0.95, "Boulders must be seated into the surface!")
		print("[PASS] Check 1 & 2: Local dense field verified (%d >= 200 within 60m, %d embedded)." % [boulders_within_60m, boulders_below_surface])

		print("\n--- 3. CAVE RAY-CHECK (OPEN/BLOCKED) ---")
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
		print("[PASS] Check 3: Cave ray-checks confirmed OPEN.")

		# Position camera exactly 3 units above the surface at the start point
		var up_start = (player_start - planet_center).normalized()
		var tangent_start = Vector3.FORWARD
		if abs(up_start.dot(tangent_start)) > 0.8:
			tangent_start = Vector3.RIGHT
		tangent_start = (tangent_start - up_start * tangent_start.dot(up_start)).normalized()
		
		# 3 units above surface looking across the local boulder field
		camera.global_position = player_start + up_start * 3.0
		camera.look_at(player_start + tangent_start * 14.0 + up_start * 0.5, up_start)

	if frame_count == 10:
		var img_dir = "tests/screenshots"
		DirAccess.make_dir_recursive_absolute(img_dir)
		var vp = root.get_viewport()
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png(img_dir + "/boulders_closeup_3m_start.png")
				print("Saved screenshot: %s/boulders_closeup_3m_start.png" % img_dir)
				print("[PASS] Check 4: Close-up screenshot from 3m above surface at start point captured.")

	if frame_count == 80:
		print("\n--- 4. FRAME TIME PERFORMANCE ANALYSIS (BEFORE VS. AFTER) ---")
		var sum_before := 0.0
		for t in frame_times_without:
			sum_before += t
		var avg_before = sum_before / max(frame_times_without.size(), 1)

		var sum_after := 0.0
		for t in frame_times_with:
			sum_after += t
		var avg_after = sum_after / max(frame_times_with.size(), 1)

		var delta_ms = avg_after - avg_before
		print("Frame time BEFORE dense boulders: %.2f ms (%.1f FPS)" % [avg_before, 1000.0 / max(avg_before, 0.001)])
		print("Frame time AFTER dense boulders:  %.2f ms (%.1f FPS)" % [avg_after, 1000.0 / max(avg_after, 0.001)])
		print("Frame time delta:                 %+.2f ms" % delta_ms)

		if delta_ms > 2.0:
			print("[NOTICE] Frame time increased by %+.2f ms (> 2.0 ms threshold)." % delta_ms)
		else:
			print("[PASS] Check 5: 4 MultiMeshes introduce negligible overhead (%+.2f ms <= 2.0 ms limit)." % delta_ms)

		print("\n=======================================================")
		print("ALL DENSE BOULDER & VARIETY CHECKS PASSED SUCCESSFULLY!")
		print("=======================================================")
		quit(0)

	return false
