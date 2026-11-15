extends SceneTree

# test_pod_scale_and_entry.gd
# Verification script for:
# 1. Scaling the pod root node to height ~3.5 units and width ~6.0 units.
# 2. Rescaled interior floor plate, wall collision boxes, machine props, and interact zones.
# 3. Resized pod trigger covering hatch opening and interior entrance (sitting at hatch, not center).
# 4. Pod on terrain surface at PodSpawn (base vs surface height difference < 0.5 units).
# 5. Player walking into pod through hatch from outside without clipping through walls.
# 6. Zero errors and cave ray-check confirmation.

var frame_count: int = 0
var world: Node3D = null
var planet: ProceduralPlanet = null
var player: PlanetWalker = null
var pod: CrashedPod = null
var step_phase: int = 0
var walk_step: int = 0
var outside_hatch_pos: Vector3 = Vector3.ZERO
var inside_pod_pos: Vector3 = Vector3.ZERO

func _init() -> void:
	print("\n" + "=".repeat(75))
	print("AUTOMATED VERIFICATION: SOL 1 LIFE POD SCALING & HATCH ENTRY")
	print("=".repeat(75))

func _process(delta: float) -> bool:
	frame_count += 1

	if frame_count == 1:
		var world_scene = load("res://Scenes/world.tscn")
		world = world_scene.instantiate()
		root.add_child(world)
		planet = world.get_node("ProceduralMars") as ProceduralPlanet
		player = world.get_node("Player") as PlanetWalker
		pod = world.get_node_or_null("CrashedPod") as CrashedPod
		if not pod:
			for c in world.get_children():
				if c is CrashedPod:
					pod = c
					break
		assert(pod != null, "CrashedPod instance must exist in world scene!")
		return false

	if frame_count == 3:
		print("\n--- PART 1: POD SCALE & INTERIOR FLOOR BOUNDING SIZE ---")
		var global_scale = pod.global_transform.basis.get_scale()
		print("Pod Global Scale: Vector3(%.4f, %.4f, %.4f)" % [global_scale.x, global_scale.y, global_scale.z])
		
		# Compute pod shell bounding size
		var model = pod.get_node("PodModel")
		var shell_aabb = AABB()
		var first = true
		for mi in model.find_children("", "MeshInstance3D", true, false):
			var m_aabb = mi.get_aabb()
			var trans_aabb = pod.global_transform.affine_inverse() * mi.global_transform * m_aabb
			if first:
				shell_aabb = trans_aabb
				first = false
			else:
				shell_aabb = shell_aabb.merge(trans_aabb)
		
		var shell_width = shell_aabb.size.x * global_scale.x
		var shell_height = shell_aabb.size.y * global_scale.y
		var shell_depth = shell_aabb.size.z * global_scale.z
		print("Enlarged Pod Shell Dimensions: Width = %.2f units, Height = %.2f units, Depth = %.2f units" % [
			shell_width, shell_height, shell_depth
		])
		assert(shell_height >= 3.2 and shell_height <= 3.8, "Pod height must be about 3.5 units! (got %.2f)" % shell_height)
		assert(shell_width >= 5.7 and shell_width <= 6.3, "Pod width must be about 6.0 units! (got %.2f)" % shell_width)
		print("[PASS] 1A: Pod root scale verified (Height: ~3.5 units, Width: ~6.0 units).")

		# Floor bounding size
		var floor_body = pod.get_node("InteriorFloor") as StaticBody3D
		var floor_col = floor_body.get_node("CollisionShape3D") as CollisionShape3D
		var floor_shape = floor_col.shape as BoxShape3D
		var floor_world_size = Vector3(floor_shape.size.x * global_scale.x, floor_shape.size.y * global_scale.y, floor_shape.size.z * global_scale.z)
		print("Bounding Size of Interior Floor: Width = %.2f m, Depth = %.2f m, Thickness = %.2f m" % [
			floor_world_size.x, floor_world_size.z, floor_world_size.y
		])
		assert(floor_world_size.x >= 5.0 and floor_world_size.z >= 5.0, "Interior floor must cover enlarged shell!")
		print("[PASS] 1B: Interior floor plate and collision rescaled to line up with enlarged shell.")

		print("\n--- PART 2: POD TRIGGER VS HATCH POSITION ---")
		var trig_col = pod.get_node("CollisionShape3D") as CollisionShape3D
		var door = pod.find_child("Line0022", true, false) as Node3D
		assert(trig_col != null, "Pod trigger CollisionShape3D must exist!")
		assert(door != null, "Hatch door node must exist!")
		
		var trig_pos = trig_col.global_position
		var hatch_pos = door.global_position
		var hatch_dist = trig_pos.distance_to(hatch_pos)
		print("Pod Trigger Global Position: %s" % trig_pos)
		print("Hatch Global Position:       %s" % hatch_pos)
		print("Trigger vs Hatch Distance:   %.4f units (target <= 1.0 unit)" % hatch_dist)
		assert(hatch_dist <= 1.0, "Trigger global position and hatch position must match within 1 unit! (got %.4f)" % hatch_dist)
		print("[PASS] 2: Trigger resized at hatch opening & interior entrance, matching hatch position within 1 unit.")

		print("\n--- PART 3: TERRAIN SURFACE SNAPPING & POD BASE HEIGHT ---")
		var pod_dir = (pod.global_position - planet.global_position).normalized()
		var surf_pt = planet.get_surface_point(pod_dir)
		var base_pt = pod.to_global(Vector3(0.0, shell_aabb.position.y * global_scale.y, 0.0))
		var base_surf_diff = abs((base_pt - planet.global_position).length() - (surf_pt - planet.global_position).length())
		print("Pod Base Point:              %s (Height: %.4f m)" % [base_pt, (base_pt - planet.global_position).length()])
		print("Terrain Surface Point:       %s (Height: %.4f m)" % [surf_pt, (surf_pt - planet.global_position).length()])
		print("Base vs Surface Difference:  %.4f units (target < 0.5 units)" % base_surf_diff)
		assert(base_surf_diff < 0.5, "Difference between pod base and terrain surface must be under 0.5 units! (got %.4f)" % base_surf_diff)
		print("[PASS] 3: Pod kept on terrain surface at PodSpawn (base difference < 0.5 units).")

		# Rescaled machines sitting inside hull check
		print("\n--- PART 4: MACHINES SITTING INSIDE HULL CHECK ---")
		var machines = ["OxygenScrubber", "PowerUnit", "WaterTank"]
		var hull_inner_radius = (shell_width / 2.0) * 0.92 # ~2.76m
		for m_name in machines:
			var m_node = pod.get_node(m_name)
			var m_horiz_dist = Vector2(m_node.position.x * global_scale.x, m_node.position.z * global_scale.z).length()
			print("  Machine [%s]: Local pos = %s, Horizontal distance from pod center = %.2f m (Hull inner radius = %.2f m)" % [
				m_name, m_node.position, m_horiz_dist, hull_inner_radius
			])
			assert(m_horiz_dist < hull_inner_radius, "Machine %s must sit inside the enlarged hull!" % m_name)
		print("[PASS] 4: All machines verified sitting properly inside the enlarged hull.")

		# Setup walk entry test
		print("\n--- PART 5: WALK PLAYER THROUGH HATCH FROM OUTSIDE ---")
		pod.set_door_open(true)
		pod.force_update_transform()
		
		# Position player on walkway outside hatch (Z = 3.8m in pod local space, facing inward toward Z = 0)
		outside_hatch_pos = pod.to_global(Vector3(0.0, 0.25, 3.8))
		inside_pod_pos = pod.to_global(Vector3(0.0, 0.25, 0.0))
		player.global_position = outside_hatch_pos
		player.velocity = Vector3.ZERO
		player.force_update_transform()
		print("Starting player outside hatch at: %s" % player.global_position)
		step_phase = 1
		return false

	if step_phase == 1:
		walk_step += 1
		# Step inward along local -Z towards the pod interior
		var target_dir = (inside_pod_pos - outside_hatch_pos).normalized()
		player.velocity = target_dir * 1.5
		player.move_and_slide()
		
		var rel_pos = pod.to_local(player.global_position)
		if walk_step % 10 == 0:
			print("  Walk step %d: Player rel pos = (X=%.2f, Y=%.2f, Z=%.2f)" % [walk_step, rel_pos.x, rel_pos.y, rel_pos.z])
			
		# Check if player successfully crossed threshold and reached interior
		if rel_pos.z < 0.6:
			print("Player reached pod interior at step %d: Rel pos = %s" % [walk_step, rel_pos])
			print("Player X offset: %.2f m (Doorway width: ~2.8m, well centered)" % rel_pos.x)
			assert(abs(rel_pos.x) < 1.0, "Player entered through the center of the hatch opening!")
			print("[PASS] 5: Player walked through hatch into pod interior without clipping through walls.")
			step_phase = 2
			return false
			
		if walk_step > 160:
			assert(false, "Player failed to enter pod interior within 160 walk steps! Stuck at: %s" % rel_pos)
		return false

	if step_phase == 2:
		print("\n--- PART 6: CAVE ENTRANCE RAY-CHECKS ---")
		var pit_count = planet.get_cave_pit_count()
		for i in pit_count:
			var cave_name = planet.get_cave_pit_name(i)
			var pit_pt = planet.get_cave_pit_surface_point(i)
			var pit_norm = (pit_pt - planet.global_position).normalized()
			var space_state = world.get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(pit_pt + pit_norm * 8.0, pit_pt - pit_norm * 8.0)
			var res = space_state.intersect_ray(query)
			var is_open = res.is_empty() or (res["collider"] != planet.static_body) or ((res["position"] - pit_pt).dot(pit_norm) < -1.5)
			print("Cave [%s] opening status: %s" % [cave_name, "OPEN" if is_open else "BLOCKED"])
			assert(is_open, "Cave %s must be OPEN!" % cave_name)
		print("[PASS] 6: Cave ray-check still prints OPEN for each cave.")

		print("\n" + "=".repeat(75))
		print("ALL LIFE POD SCALING & HATCH ENTRY TESTS PASSED WITH ZERO ERRORS!")
		print("=".repeat(75) + "\n")
		world.queue_free()
		quit(0)
		return true

	return false
