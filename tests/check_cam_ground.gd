extends SceneTree

func _process(_delta: float) -> bool:
	var cs = load("res://intro_cutscene.tscn").instantiate()
	root.add_child(cs)
	
	var planet = cs.get_node("ProceduralMars")
	var target_surf = cs.final_surface_pt
	var up_norm = cs.surface_normal
	
	var tangent = up_norm.cross(Vector3.FORWARD).normalized()
	if tangent.length_squared() < 0.01:
		tangent = up_norm.cross(Vector3.RIGHT).normalized()
	var bitangent = tangent.cross(up_norm).normalized()
	tangent = up_norm.cross(bitangent).normalized()

	print("Landing surface point: ", target_surf, " (height: ", target_surf.length(), ")")

	# Check Camera C (12s to 16s)
	print("\n--- Camera C check ---")
	for t_cam in [12.0, 13.0, 14.0, 15.0, 16.0]:
		var alpha = (t_cam - 12.0) / 4.0
		var pos = target_surf + tangent * 16.0 + up_norm * (2.2 + alpha * 0.4) + bitangent * 12.0
		var surf_at_pos = planet.get_surface_point(pos.normalized())
		var altitude_above_ground = pos.length() - surf_at_pos.length()
		print("t = ", t_cam, "s | Cam pos: ", pos, " | Ground: ", surf_at_pos.length(), " | Cam height: ", pos.length(), " | Altitude above ground: ", altitude_above_ground)
		if altitude_above_ground < 0.5:
			print("  WARNING: Camera C is inside or too close to ground! (", altitude_above_ground, ")")

	# Also check Camera Shake!
	print("\n--- Camera Shake check at impact (13s) ---")
	print("At impact, shake_intensity is 2.5!")
	print("Shake adds v_offset = randf_range(-0.4, 0.4) * 2.5 = up to -1.0 offset!")
	print("If cam altitude above ground is 2.2 or less, shake + terrain slope can push camera inside geometry!")

	# Check Camera D (16s to 40s)
	print("\n--- Camera D check ---")
	var keys = [
		[16.0, target_surf + tangent * 18.0 + up_norm * 6.0 + bitangent * 16.0],
		[20.0, (target_surf + tangent * 18.0 + up_norm * 6.0 + bitangent * 16.0).lerp(target_surf - tangent * 24.0 + up_norm * 11.0 + bitangent * 22.0, 0.5)],
		[24.0, target_surf - tangent * 24.0 + up_norm * 11.0 + bitangent * 22.0],
		[32.0, target_surf - tangent * 32.0 + up_norm * 16.0 - bitangent * 18.0],
		[40.0, target_surf + tangent * 38.0 + up_norm * 20.0 - bitangent * 28.0]
	]
	for k in keys:
		var pos = k[1]
		var surf = planet.get_surface_point(pos.normalized())
		var alt = pos.length() - surf.length()
		print("t = ", k[0], "s | Alt above ground: ", alt)
		if alt < 1.0:
			print("  WARNING: Camera D too close or underground! Alt: ", alt)

	# Check camera near plane!
	var cam_c = cs.get_node("Cameras/CameraGround")
	print("\nCamera C near plane: ", cam_c.near)

	quit()
	return true
