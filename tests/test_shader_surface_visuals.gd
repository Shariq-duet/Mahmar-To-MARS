extends SceneTree

var frame_count := 0
var world: Node3D = null
var planet: ProceduralPlanet = null
var player: CharacterBody3D = null
var camera: Camera3D = null

func _init() -> void:
	print("\n=======================================================")
	print("TESTING TERRAIN SHADER: TRIPLANAR, SLOPE, ALT & VISUALS")
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

	if frame_count == 5:
		print("\n--- 1. CAVE RAY-CHECK (OPEN/BLOCKED) ---")
		var space_state = world.get_world_3d().direct_space_state
		var pit_count = planet.get_cave_pit_count()
		for i in pit_count:
			var cave_name = planet.get_cave_pit_name(i)
			var pit_pt = planet.get_cave_pit_surface_point(i)
			var pit_normal = (pit_pt - planet.global_position).normalized()
			var ray_origin = pit_pt + pit_normal * 8.0
			var ray_target = pit_pt - pit_normal * 8.0
			var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
			var result = space_state.intersect_ray(query)
			
			var is_open = result.is_empty() or (result["collider"] != planet.static_body) or ((result["position"] - pit_pt).dot(pit_normal) < -1.5)
			print("[CAVE RAY-CHECK] %s: %s" % [cave_name, "OPEN" if is_open else "BLOCKED"])
			assert(is_open, "Cave %s must be OPEN!" % cave_name)

		# 2. Position camera 40 units above surface looking down at the terrain
		var spawn_pt = player.global_position
		var radial_up = (spawn_pt - planet.global_position).normalized()
		var tangent_fwd = Vector3.FORWARD
		if abs(radial_up.dot(tangent_fwd)) > 0.8:
			tangent_fwd = Vector3.RIGHT
		tangent_fwd = (tangent_fwd - radial_up * tangent_fwd.dot(radial_up)).normalized()
		
		# Look down at terrain with a 50 degree angle to capture both slope and plains
		camera.global_position = spawn_pt + radial_up * 40.0 + tangent_fwd * 15.0
		camera.look_at(spawn_pt + tangent_fwd * 25.0, radial_up)

	if frame_count == 8:
		var img_dir = "tests/screenshots"
		DirAccess.make_dir_recursive_absolute(img_dir)
		var vp = root.get_viewport()
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png(img_dir + "/terrain_surface_40m_overview.png")
				print("Saved screenshot: %s/terrain_surface_40m_overview.png" % img_dir)
				
				# Analyze color variation across terrain pixels
				var width = img.get_width()
				var height = img.get_height()
				var dark_basalt_pixels = 0
				var bright_dune_pixels = 0
				var mid_regolith_pixels = 0
				for y in range(int(height * 0.3), int(height * 0.8), 4):
					for x in range(int(width * 0.2), int(width * 0.8), 4):
						var col = img.get_pixel(x, y)
						var lum = col.r * 0.5 + col.g * 0.4 + col.b * 0.1
						if lum < 0.25:
							dark_basalt_pixels += 1
						elif lum > 0.55:
							bright_dune_pixels += 1
						else:
							mid_regolith_pixels += 1
				print("Color variation analysis on 40m terrain overview:")
				print("  - Dark basalt/rock pixels: %d" % dark_basalt_pixels)
				print("  - Mid regolith dust pixels: %d" % mid_regolith_pixels)
				print("  - Bright dune/ridge pixels: %d" % bright_dune_pixels)
				assert(dark_basalt_pixels > 0 and mid_regolith_pixels > 0, "Terrain must show distinct color variation (not flat mono-orange)!")

		# Position camera close-up to Noctis Labyrinthus cave entrance
		var noctis_pt = planet.get_cave_pit_surface_point(0)
		var noctis_norm = (noctis_pt - planet.global_position).normalized()
		var noctis_tangent = Vector3.UP.cross(noctis_norm).normalized()
		camera.global_position = noctis_pt + noctis_tangent * 16.0 + noctis_norm * 8.0
		camera.look_at(noctis_pt + noctis_norm * 0.5, noctis_norm)

	if frame_count == 11:
		var img_dir = "tests/screenshots"
		var vp = root.get_viewport()
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png(img_dir + "/cave_entrance_noctis_closeup.png")
				print("Saved screenshot: %s/cave_entrance_noctis_closeup.png" % img_dir)

		# Position camera close-up to Elysium Magma Cavern cave entrance
		var elysium_pt = planet.get_cave_pit_surface_point(1)
		var elysium_norm = (elysium_pt - planet.global_position).normalized()
		var elysium_tangent = Vector3.UP.cross(elysium_norm).normalized()
		camera.global_position = elysium_pt + elysium_tangent * 16.0 + elysium_norm * 8.0
		camera.look_at(elysium_pt + elysium_norm * 0.5, elysium_norm)

	if frame_count == 14:
		var img_dir = "tests/screenshots"
		var vp = root.get_viewport()
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png(img_dir + "/cave_entrance_elysium_closeup.png")
				print("Saved screenshot: %s/cave_entrance_elysium_closeup.png" % img_dir)
		
		print("\n=======================================================")
		print("ALL SURFACE VISUAL & CAVE CHECKS COMPLETED SUCCESSFULLY!")
		print("=======================================================")
		quit(0)

	return false
