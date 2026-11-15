@tool
extends SceneTree

func _init() -> void:
	print("Testing watertight transition stitching...")
	var K = 6
	# Outer edge from (0,0) to (1,0). Inner edge at y=1 with K segments.
	var outer_0 = Vector2(0, 0)
	var outer_1 = Vector2(1, 0)
	var inner_pts = []
	for s in range(K + 1):
		inner_pts.append(Vector2(float(s) / float(K), 1.0))
	
	var tris = []
	var mid_k = K / 2
	for s in range(mid_k):
		tris.append([outer_0, inner_pts[s], inner_pts[s + 1]])
	tris.append([outer_0, inner_pts[mid_k], outer_1])
	for s in range(mid_k, K):
		tris.append([outer_1, inner_pts[s], inner_pts[s + 1]])
	
	print("Generated %d transition triangles for K=%d" % [tris.size(), K])
	# Verify area matches quad area (1.0)
	var total_area = 0.0
	for t in tris:
		var v0 = t[0]
		var v1 = t[1]
		var v2 = t[2]
		var area = 0.5 * absf((v1.x - v0.x) * (v2.y - v0.y) - (v2.x - v0.x) * (v1.y - v0.y))
		total_area += area
	print("Total area: %.4f (expected 1.0000)" % total_area)
	assert(absf(total_area - 1.0) < 0.0001, "Area must equal 1.0!")
	print("Watertight transition test: PASS")
	quit()
