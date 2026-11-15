extends SceneTree

func _init() -> void:
	print("--- TESTING MESH AABB & SCALED BOUNDS ---")

	var spawner_script = load("res://Scripts/planet/boulder_spawner.gd")

	# Check the 3 Medium meshes
	for m in 3:
		var res = spawner_script._build_medium_boulder_mesh(10000 + m * 2333)
		var mesh: ArrayMesh = res["mesh"]
		var aabb = mesh.get_aabb()
		print("Medium Mesh #%d: AABB pos=%s, size=%s, center=%s" % [m, aabb.position, aabb.size, aabb.get_center()])

	# Check the 3 Large Outcrop meshes
	for m in 3:
		var res = spawner_script._build_large_outcrop_mesh(m, 20000 + m * 3777)
		var mesh: ArrayMesh = res["mesh"]
		var aabb = mesh.get_aabb()
		print("Large Outcrop Mesh #%d: AABB pos=%s, size=%s, center=%s" % [m, aabb.position, aabb.size, aabb.get_center()])

	quit()
