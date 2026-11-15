@tool
extends SceneTree

func _init() -> void:
	var pg = load("res://Scripts/planet/planet_generator.gd").new()
	var water_dir: Vector3 = pg.water_deposit_dir
	var rad: float = pg.radius
	var n: int = pg.resolution
	
	for face_idx in pg.FACE_NORMALS.size():
		var fn: Vector3 = pg.FACE_NORMALS[face_idx]
		var a: Vector3 = Vector3(fn.y, fn.z, fn.x)
		var b: Vector3 = fn.cross(a)
		var count = 0
		for j in n:
			for i in n:
				var c00: Vector3 = fn + (2.0 * i / n - 1.0) * a + (2.0 * j / n - 1.0) * b
				var c10: Vector3 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * j / n - 1.0) * b
				var c01: Vector3 = fn + (2.0 * i / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
				var c11: Vector3 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
				var mid: Vector3 = pg._cube_to_sphere((c00 + c10 + c01 + c11) * 0.25).normalized()
				var d_mtn: float = acos(clampf(mid.dot(water_dir), -1.0, 1.0)) * rad
				if d_mtn <= 92.0:
					count += 1
		print("Face %d (%s): %d quads" % [face_idx, fn, count])
	quit()
