@tool
extends SceneTree

func _init() -> void:
	var pg = load("res://Scripts/planet/planet_generator.gd").new()
	pg._setup_noise()
	pg._build_craters()
	
	var water_dir: Vector3 = pg.water_deposit_dir
	var rad: float = pg.radius
	var n: int = pg.resolution
	
	var patch_quads = 0
	
	for face_n in pg.FACE_NORMALS:
		var fn: Vector3 = face_n
		var a: Vector3 = Vector3(fn.y, fn.z, fn.x)
		var b: Vector3 = fn.cross(a)
		for j in n:
			for i in n:
				var c00: Vector3 = fn + (2.0 * i / n - 1.0) * a + (2.0 * j / n - 1.0) * b
				var c10: Vector3 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * j / n - 1.0) * b
				var c01: Vector3 = fn + (2.0 * i / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
				var c11: Vector3 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
				var mid: Vector3 = pg._cube_to_sphere((c00 + c10 + c01 + c11) * 0.25).normalized()
				var d_mtn: float = acos(clampf(mid.dot(water_dir), -1.0, 1.0)) * rad
				if d_mtn <= 92.0:
					patch_quads += 1
	
	print("Patch quads within 92m: ", patch_quads)
	var K = 6
	var sub_quads = patch_quads * K * K
	print("With K=%d: sub-quads = %d" % [K, sub_quads])
	quit()
