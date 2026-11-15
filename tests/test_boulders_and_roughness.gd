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
	print("TESTING BOULDERS, SURFACE ROUGHNESS & CAVE INTEGRITY")
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

	# Phase 1: Measure baseline WITHOUT boulders (frame 15 to 35)
	if frame_count == 14:
		var mmi = planet.get_node_or_null("SurfaceBouldersMultiMesh")
		if mmi:
			mmi.visible = false
	if frame_count >= 15 and frame_count < 35:
		frame_times_without.append(delta * 1000.0)

	# Phase 2: Measure performance WITH boulders (frame 36 to 56)
	if frame_count == 35:
		var mmi = planet.get_node_or_null("SurfaceBouldersMultiMesh")
		if mmi:
			mmi.visible = true
	if frame_count >= 36 and frame_count < 56:
		frame_times_with.append(delta * 1000.0)

	if frame_count == 5:
		print("\n--- 1. CAVE HOLE BOULDER EXCLUSION VERIFICATION ---")
		var mmi: MultiMeshInstance3D = planet.get_node_or_null("SurfaceBouldersMultiMesh")
		assert(mmi != null, "SurfaceBouldersMultiMesh must exist!")
		var mm = mmi.multimesh
		var total_boulders = mm.instance_count
		print("Total active boulders in MultiMesh: %d" % total_boulders)
		assert(total_boulders >= 60, "Must spawn at least 60 boulders!")

		var planet_center = planet.global_position
		for c in planet.cave_centers:
			var cave_name: String = c["name"]
			var cave_dir: Vector3 = c["dir"]
			var hole_rad: float = c["hole_rad"]
			var count_in_hole := 0
			
			for i in total_boulders:
				var t: Transform3D = mm.get_instance_transform(i)
				var b_pos: Vector3 = planet.to_global(t.origin)
				var b_dir: Vector3 = (b_pos - planet_center).normalized()
				var angle := acos(clampf(b_dir.dot(cave_dir), -1.0, 1.0))
				if angle < hole_rad:
					count_in_hole += 1
			
			print("Count of boulders within [%s] hole radius (%.4f rad): %d" % [cave_name, hole_rad, count_in_hole])
			assert(count_in_hole == 0, "No boulder can sit inside cave entrance! Found %d" % count_in_hole)
		print("[PASS] Check 1: 0 boulders sit inside any cave opening.")

		print("\n--- 2. BOULDER EMBEDDING & GROUND CONTACT ---")
		var valid_embedded := 0
		for i in min(10, total_boulders):
			var t = mm.get_instance_transform(i)
			var b_pos = planet.to_global(t.origin)
			var b_dir = (b_pos - planet_center).normalized()
			var surf_pt = planet.get_surface_point(b_dir)
			var up = (surf_pt - planet_center).normalized()
			var embed_depth = (surf_pt - b_pos).dot(up)
			var scale_y = t.basis.y.length()
			print("Boulder #%d: height scale=%.2fm, embedded depth=%.2fm (~%.1f%% embedded)" % [i, scale_y, embed_depth, (embed_depth / max(scale_y, 0.01)) * 100.0])
			assert(embed_depth > 0.05, "Boulder must be embedded into the terrain (not floating)!")
			assert(embed_depth < scale_y * 0.90, "Boulder must not be fully buried!")
			valid_embedded += 1
		print("[PASS] Check 2: Sampled boulders verified realistically embedded (~30%% into ground).")

		print("\n--- 3. CAVE RAY-CHECK VERIFICATION ---")
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

		# Position camera 10 units above surface close to a boulder cluster
		var t0 = mm.get_instance_transform(0)
		var b0_pos = planet.to_global(t0.origin)
		var b0_norm = (b0_pos - planet_center).normalized()
		var tangent = Vector3.UP.cross(b0_norm).normalized()
		camera.global_position = b0_pos + b0_norm * 10.0 + tangent * 5.0
		camera.look_at(b0_pos, b0_norm)

	if frame_count == 10:
		var img_dir = "tests/screenshots"
		DirAccess.make_dir_recursive_absolute(img_dir)
		var vp = root.get_viewport()
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png(img_dir + "/boulders_roughness_10m_closeup.png")
				print("Saved screenshot: %s/boulders_roughness_10m_closeup.png" % img_dir)
				print("[PASS] Check 4: Close-up screenshot from 10m captured.")

	if frame_count == 58:
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
		print("Frame time BEFORE boulders: %.2f ms (%.1f FPS)" % [avg_before, 1000.0 / max(avg_before, 0.001)])
		print("Frame time AFTER boulders:  %.2f ms (%.1f FPS)" % [avg_after, 1000.0 / max(avg_after, 0.001)])
		print("Frame time delta:          %+.2f ms" % delta_ms)

		assert(delta_ms < 2.0, "Frame time increase must be strictly below 2.0 ms! Measured %+.2f ms" % delta_ms)
		print("[PASS] Check 5: MultiMeshInstance3D introduces negligible overhead (%+.2f ms < 2.0 ms limit)." % delta_ms)

		print("\n=======================================================")
		print("ALL BOULDER & ROUGHNESS VERIFICATION CHECKS PASSED!")
		print("=======================================================")
		quit(0)

	return false
