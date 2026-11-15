@tool
extends SceneTree

func _init() -> void:
	print("--- TESTING HIGH-RESOLUTION PATCH MESH GENERATION ---")
	var pg = load("res://Scripts/planet/planet_generator.gd").new()
	pg._setup_noise()
	pg._build_craters()
	
	var n: int = pg.resolution
	var K: int = 6
	var dirs := PackedVector3Array()
	var idx := PackedInt32Array()
	var key_to_idx := {}
	
	var patch_i_min = 26
	var patch_i_max = 42
	var patch_j_min = 14
	var patch_j_max = 30
	
	# Helper to get/create vertex index
	var get_vert = func(c: Vector3) -> int:
		var key = Vector3i(roundi(c.x * n * K), roundi(c.y * n * K), roundi(c.z * n * K))
		if key_to_idx.has(key):
			return key_to_idx[key]
		var new_idx = dirs.size()
		key_to_idx[key] = new_idx
		dirs.append(pg._cube_to_sphere(c).normalized())
		return new_idx
	
	var patch_vert_count = 0
	var total_quads = 0
	
	for face_idx in pg.FACE_NORMALS.size():
		var fn: Vector3 = pg.FACE_NORMALS[face_idx]
		var a: Vector3 = Vector3(fn.y, fn.z, fn.x)
		var b: Vector3 = fn.cross(a)
		var is_up_face = (fn == Vector3.UP)
		
		for j in n:
			for i in n:
				total_quads += 1
				var in_patch = is_up_face and (i >= patch_i_min and i <= patch_i_max and j >= patch_j_min and j <= patch_j_max)
				
				if in_patch:
					# Subdivided quad
					for sj in K:
						for si in K:
							var gi0 = i * K + si
							var gi1 = gi0 + 1
							var gj0 = j * K + sj
							var gj1 = gj0 + 1
							
							var c00 = fn + (2.0 * gi0 / (n * K) - 1.0) * a + (2.0 * gj0 / (n * K) - 1.0) * b
							var c10 = fn + (2.0 * gi1 / (n * K) - 1.0) * a + (2.0 * gj0 / (n * K) - 1.0) * b
							var c01 = fn + (2.0 * gi0 / (n * K) - 1.0) * a + (2.0 * gj1 / (n * K) - 1.0) * b
							var c11 = fn + (2.0 * gi1 / (n * K) - 1.0) * a + (2.0 * gj1 / (n * K) - 1.0) * b
							
							var v00 = get_vert.call(c00)
							var v10 = get_vert.call(c10)
							var v01 = get_vert.call(c01)
							var v11 = get_vert.call(c11)
							
							pg._add_tri(idx, dirs, v00, v10, v11)
							pg._add_tri(idx, dirs, v00, v11, v01)
				else:
					# Standard quad
					var c00 = fn + (2.0 * i / n - 1.0) * a + (2.0 * j / n - 1.0) * b
					var c10 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * j / n - 1.0) * b
					var c01 = fn + (2.0 * i / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
					var c11 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
					
					var v00 = get_vert.call(c00)
					var v10 = get_vert.call(c10)
					var v01 = get_vert.call(c01)
					var v11 = get_vert.call(c11)
					
					pg._add_tri(idx, dirs, v00, v10, v11)
					pg._add_tri(idx, dirs, v00, v11, v01)

	# Count vertices in patch
	for k in dirs.size():
		var d = dirs[k]
		var d_mtn = acos(clampf(d.dot(pg.water_deposit_dir), -1.0, 1.0)) * pg.radius
		if d_mtn <= 90.0:
			patch_vert_count += 1
	
	print("Total mesh vertices: ", dirs.size())
	print("Total mesh triangles: ", idx.size() / 3)
	print("Patch vertices within 90m: ", patch_vert_count)
	
	# Verify building ArrayMesh
	var pos := PackedVector3Array()
	pos.resize(dirs.size())
	for k in dirs.size():
		pos[k] = dirs[k] * (pg.radius + pg._height(dirs[k]))
	
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_INDEX] = idx
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shape = mesh.create_trimesh_shape()
	print("Trimesh shape successfully created! Faces: ", shape.get_faces().size() / 3)
	quit()
