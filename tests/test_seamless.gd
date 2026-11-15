@tool
extends SceneTree

func _init() -> void:
	print("--- TESTING SEAMLESS TRANSITION STITCHING ---")
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
	
	var get_vert = func(c: Vector3) -> int:
		var key = Vector3i(roundi(c.x * n * K), roundi(c.y * n * K), roundi(c.z * n * K))
		if key_to_idx.has(key):
			return key_to_idx[key]
		var new_idx = dirs.size()
		key_to_idx[key] = new_idx
		dirs.append(pg._cube_to_sphere(c).normalized())
		return new_idx
	
	for face_idx in pg.FACE_NORMALS.size():
		var fn: Vector3 = pg.FACE_NORMALS[face_idx]
		var a: Vector3 = Vector3(fn.y, fn.z, fn.x)
		var b: Vector3 = fn.cross(a)
		var is_up_face = (fn == Vector3.UP)
		
		for j in n:
			for i in n:
				var in_patch = is_up_face and (i >= patch_i_min and i <= patch_i_max and j >= patch_j_min and j <= patch_j_max)
				var is_transition = is_up_face and not in_patch and (i >= patch_i_min - 1 and i <= patch_i_max + 1 and j >= patch_j_min - 1 and j <= patch_j_max + 1)
				
				if in_patch:
					# Fully subdivided KxK
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
				elif is_transition:
					# Border transition quad: fan from outer corners/center to subdivided inner points
					var c00 = fn + (2.0 * i / n - 1.0) * a + (2.0 * j / n - 1.0) * b
					var c10 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * j / n - 1.0) * b
					var c01 = fn + (2.0 * i / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
					var c11 = fn + (2.0 * (i + 1) / n - 1.0) * a + (2.0 * (j + 1) / n - 1.0) * b
					
					var v_center = get_vert.call((c00 + c10 + c01 + c11) * 0.25)
					
					# Build edge sub-points: if adjacent to patch, divide by K; otherwise 1 segment
					var has_north = (j + 1 >= patch_j_min and j + 1 <= patch_j_max and i >= patch_i_min and i <= patch_i_max)
					var has_south = (j - 1 >= patch_j_min and j - 1 <= patch_j_max and i >= patch_i_min and i <= patch_i_max)
					var has_east  = (i + 1 >= patch_i_min and i + 1 <= patch_i_max and j >= patch_j_min and j <= patch_j_max)
					var has_west  = (i - 1 >= patch_i_min and i - 1 <= patch_i_max and j >= patch_j_min and j <= patch_j_max)
					
					# South edge (c00 to c10)
					var s_pts = []
					var k_s = K if has_south else 1
					for s in range(k_s + 1):
						var u = float(s) / float(k_s)
						s_pts.append(get_vert.call(c00.lerp(c10, u)))
					for s in range(k_s):
						pg._add_tri(idx, dirs, s_pts[s], s_pts[s + 1], v_center)
					
					# North edge (c01 to c11)
					var n_pts = []
					var k_n = K if has_north else 1
					for s in range(k_n + 1):
						var u = float(s) / float(k_n)
						n_pts.append(get_vert.call(c01.lerp(c11, u)))
					for s in range(k_n):
						pg._add_tri(idx, dirs, n_pts[s + 1], n_pts[s], v_center)
					
					# West edge (c00 to c01)
					var w_pts = []
					var k_w = K if has_west else 1
					for s in range(k_w + 1):
						var v = float(s) / float(k_w)
						w_pts.append(get_vert.call(c00.lerp(c01, v)))
					for s in range(k_w):
						pg._add_tri(idx, dirs, w_pts[s + 1], w_pts[s], v_center)
					
					# East edge (c10 to c11)
					var e_pts = []
					var k_e = K if has_east else 1
					for s in range(k_e + 1):
						var v = float(s) / float(k_e)
						e_pts.append(get_vert.call(c10.lerp(c11, v)))
					for s in range(k_e):
						pg._add_tri(idx, dirs, e_pts[s], e_pts[s + 1], v_center)
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
	
	print("Seamless mesh generation completed!")
	print("Dirs size: ", dirs.size())
	print("Idx size: ", idx.size())
	quit()
