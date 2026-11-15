@tool
extends SceneTree

func _init() -> void:
	var pg = load("res://Scripts/planet/planet_generator.gd").new()
	pg._setup_noise()
	pg._build_craters()
	
	# Current height at water_deposit_dir
	var h_current = pg._height(pg.water_deposit_dir)
	print("Current peak height at water_deposit_dir: ", h_current)
	
	# Raw mountain noise at water_deposit_dir
	var n_raw = pg._mountain_noise.get_noise_3dv(pg.water_deposit_dir * 5.0)
	var ridged = pow(1.0 - absf(n_raw), 2.0)
	print("Raw mountain noise: ", n_raw, " ridged factor: ", ridged)
	quit()
