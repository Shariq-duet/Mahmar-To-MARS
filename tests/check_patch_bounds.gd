@tool
extends SceneTree

func _init() -> void:
	var pg = load("res://Scripts/planet/planet_generator.gd").new()
	var water_dir: Vector3 = pg.water_deposit_dir
	var rad: float = pg.radius
	var n: int = pg.resolution
	
	var fn = Vector3.UP
	var a = Vector3(1, 0, 0)
	var b = Vector3(0, 0, -1)
	
	var min_i = 999
	var max_i = -1
	var min_j = 999
	var max_j = -1
	
	for j in n:
		for i in n:
			var c00: Vector3 = fn + (2.0 * i / n - 1.0) * a + (2.0 * j / n - 1.0) * b
			var c10: Vector3 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * j / n - 1.0) * b
			var c01: Vector3 = fn + (2.0 * i / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
			var c11: Vector3 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
			var mid: Vector3 = pg._cube_to_sphere((c00 + c10 + c01 + c11) * 0.25).normalized()
			var d_mtn: float = acos(clampf(mid.dot(water_dir), -1.0, 1.0)) * rad
			if d_mtn <= 92.0:
				min_i = mini(min_i, i)
				max_i = maxi(max_i, i)
				min_j = mini(min_j, j)
				max_j = maxi(max_j, j)
	
	print("Patch bounding box on Face 0: i in [%d, %d], j in [%d, %d] (size %dx%d)" % [
		min_i, max_i, min_j, max_j, max_i - min_i + 1, max_j - min_j + 1
	])
	quit()
