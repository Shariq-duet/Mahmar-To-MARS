@tool
extends SceneTree

func _init() -> void:
	var pg = load("res://Scripts/planet/planet_generator.gd").new()
	var cave_dir = pg.cave_centers[0]["dir"]
	var fn = Vector3.UP
	var a = Vector3(1, 0, 0)
	var b = Vector3(0, 0, -1)
	var n = pg.resolution
	
	# Project cave_dir onto Face 0 cube
	# c = fn + (2.0 * i / n - 1.0) * a + (2.0 * j / n - 1.0) * b
	# On UP face, c.y = 1.0. So divide by cave_dir.y:
	var c = cave_dir / cave_dir.y
	# c.x = 2.0 * i / n - 1.0 => i = (c.x + 1.0) * 0.5 * n
	# c.z = -(2.0 * j / n - 1.0) => j = (-c.z + 1.0) * 0.5 * n
	var i = (c.x + 1.0) * 0.5 * n
	var j = (-c.z + 1.0) * 0.5 * n
	print("Cave 0 (Noctis) coordinates on Face 0: i = %.2f, j = %.2f" % [i, j])
	print("Patch bounds: i in [26, 42], j in [14, 30]")
	quit()
