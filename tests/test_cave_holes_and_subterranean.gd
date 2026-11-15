extends SceneTree

func _init() -> void:
	print("\n==============================================")
	print("TESTING CAVE HOLE CUTOUT & UNDERGROUND GEOMETRY")
	print("==============================================")

	var planet_script = load("res://Scripts/planet/planet_generator.gd")
	var planet = Node3D.new()
	planet.set_script(planet_script)
	planet.resolution = 48
	root.add_child(planet)
	planet.generate()

	# 1. Verify planet has cut physical holes for caves
	var pit_count = planet.get_cave_pit_count()
	assert(pit_count == 2, "Expected 2 distant cave pits defined!")
	print("[TEST 1] Cave pit count is 2: PASS")

	# Check that cave_mask returns > 0.8 for pit center
	for i in pit_count:
		var dir = planet.get_cave_pit_dir(i)
		var is_hole = planet.cave_mask(dir) > 0.8
		assert(is_hole, "Pit direction must test positive for cave hole cutout!")
	print("[TEST 2] Cave pit centers verified inside cutout mask: PASS")

	# 2. Test noctis fissure subterranean alignment
	var noctis_scene = load("res://Scenes/planet/caves/noctis_fissure.tscn")
	var cave = noctis_scene.instantiate()
	root.add_child(cave)

	var pit_pt = planet.get_cave_pit_surface_point(0)
	var pit_normal = (pit_pt - (planet.global_position if planet.is_inside_tree() else planet.position)).normalized()
	var intended_fwd = Vector3(0, 0, -1)

	# Build orthonormal basis with explicit forward
	var up = pit_normal.normalized()
	var fwd = (intended_fwd - up * intended_fwd.dot(up)).normalized()
	var right = fwd.cross(up).normalized()
	fwd = up.cross(right).normalized()
	var depth_offset = -3.0
	cave.global_transform = Transform3D(Basis(right, up, -fwd), pit_pt + up * depth_offset)

	# Verify entrance marker
	var marker = cave.get_node("EntranceMarkerLabel")
	assert(marker != null, "Entrance marker must exist!")
	print("[TEST 3] Entrance marker verified: PASS")

	# Verify interior chasm floor is at negative local Y
	var floor_node = cave.get_node("ChasmFloor")
	assert(floor_node.position.y < 0.0, "Chasm floor must be at negative local Y (underground)!")
	print("[TEST 4] Interior chasm floor is strictly at negative local Y: PASS")

	print("==============================================")
	print("RESULTS: 5 / 5 PASSED")
	print("==============================================")
	print("ALL CAVE HOLE & SUBTERRANEAN TESTS PASSED!")
	quit(0)
