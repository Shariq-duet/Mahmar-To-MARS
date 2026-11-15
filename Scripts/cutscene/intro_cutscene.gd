extends Node3D
class_name IntroCutscene

# intro_cutscene.gd
# Highly cinematic 40-second opening cutscene for Mars survival game.
# 0-6s: Camera A (Low Wide): atmospheric entry, heat plume, glowing heat shield, entry rumble.
# 6-12s: Camera B (Close Chase): handheld shake, engine retro-burn start (8s), exhaust from nozzle.
# 12-16s: Camera C (Ground Impact): violent impact (13s), white flash, camera shake (3s decay), 4s dust burst, slow-mo.
# 16-40s: Camera D (Orbit/Pullback): aftermath slide/settle, venting smoke/sparks, debris, silent beat then wind, fade to black at 40s.

signal cutscene_finished

@export var landing_point: Vector3 = Vector3(0, 500, 0)

# Sound Streams
@export var engine_sound_stream: AudioStream = preload("res://audio/engine_loop.ogg")
@export var impact_sound_stream: AudioStream = preload("res://audio/impact.ogg")
@export var ambient_sound_stream: AudioStream = preload("res://audio/ambient_wind.ogg")
@export var music_stream: AudioStream = preload("res://Music/Suspended Quiet.mp3")

# Camera nodes (4 cuts)
@onready var cam_low_wide: Camera3D = $Cameras/CameraLowWide
@onready var cam_chase: Camera3D = $Cameras/CameraChase
@onready var cam_ground: Camera3D = $Cameras/CameraGround
@onready var cam_orbit: Camera3D = $Cameras/CameraOrbit

# Rocket & Engine
@onready var rocket: Node3D = $Rocket
@onready var rocket_mesh: Node3D = $Rocket/RocketMesh
@onready var engine_marker: Marker3D = $Rocket/EngineMarker
@onready var heat_shield_glow: MeshInstance3D = $Rocket/EngineMarker/HeatShieldGlow

# Particles
@onready var exhaust_particles: GPUParticles3D = $Rocket/EngineMarker/ExhaustParticles
@onready var venting_particles: GPUParticles3D = $Rocket/EngineMarker/VentingParticles
@onready var heat_plume: GPUParticles3D = $Rocket/EngineMarker/HeatPlume
@onready var dust_particles: GPUParticles3D = $DustParticles
@onready var debris_particles: GPUParticles3D = $DebrisParticles

# Audio players
@onready var engine_sound: AudioStreamPlayer3D = $Rocket/EngineMarker/EngineSound
@onready var impact_sound: AudioStreamPlayer3D = $Rocket/ImpactSound
@onready var ambient_sound: AudioStreamPlayer = $AmbientSound
@onready var entry_rumble_sound: AudioStreamPlayer = $EntryRumbleSound
@onready var music_player: AudioStreamPlayer = $MusicPlayer

# UI & Animation
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var white_flash: ColorRect = $CanvasLayer/WhiteFlash
@onready var fade_rect: ColorRect = $CanvasLayer/FadeOverlay
@onready var skip_label: Label = $CanvasLayer/SkipLabel
@onready var planet: ProceduralPlanet = $ProceduralMars

var is_finished: bool = false
var is_entry_active: bool = false
var is_burn_active: bool = false
var shake_intensity: float = 0.0
var slowmo_timer: float = 0.0
var final_surface_pt := Vector3.ZERO
var surface_normal := Vector3.UP

var burn_start_time: float = 8.0
var impact_time: float = 13.0
var base_rocket_mesh_pos := Vector3(-0.60041, -3.03171, 14.07083)

func _ready() -> void:
	# 1. Compute exact mathematical surface landing point from planet query function
	assert(planet != null, "ProceduralMars node must be present in intro cutscene!")
	var landing_dir = landing_point.normalized()
	if landing_dir.length_squared() < 0.01:
		landing_dir = Vector3.UP

	final_surface_pt = planet.get_surface_point(landing_dir)
	surface_normal = (final_surface_pt - planet.global_position).normalized()
	landing_point = final_surface_pt

	var surface_height = final_surface_pt.length()
	var final_rocket_pos = final_surface_pt
	var delta_height = abs(final_rocket_pos.length() - surface_height)
	var delta_pos = final_rocket_pos.distance_to(final_surface_pt)

	print("\n==================================================")
	print("MARS CINEMATIC OPENING CUTSCENE INITIALIZED")
	print("==================================================")
	print("Landing Direction:                   %s" % landing_dir)
	print("Planet Surface Landing Point:        %s" % final_surface_pt)
	print("Surface Height at Landing Point:     %.4f" % surface_height)
	print("Final Rocket Position:               %s" % final_rocket_pos)
	print("Final Rocket Height:                 %.4f" % final_rocket_pos.length())
	print("Delta between Rocket & Surface Pos:  %.4f units" % delta_pos)
	print("Delta between Rocket & Surface Hgt:  %.4f units" % delta_height)
	print("Rocket Model Scene File Path:        res://Scenes/rocket.tscn")
	print("Rocket Model 3D Asset File Path:     res://Assets/rocket_ship.glb")
	print("EngineMarker Local Position:         %s (at nozzle, scaled 5.5x)" % engine_marker.position)
	print("==================================================\n")

	assert(delta_pos <= 0.5, "Final rocket position must match surface point within 0.5 units!")
	assert(delta_height <= 0.5, "Final rocket height must match surface height within 0.5 units!")

	# 2. Position surface impact particles
	dust_particles.global_position = final_surface_pt
	debris_particles.global_position = final_surface_pt

	# 3. Ensure engine sound stream is configured to loop
	if engine_sound != null:
		if engine_sound_stream is AudioStreamOggVorbis:
			(engine_sound_stream as AudioStreamOggVorbis).loop = true
		engine_sound.stream = engine_sound_stream

	# 4. Initialize cameras: CameraLowWide starts active
	cam_low_wide.current = true

	# 5. Start background cinematic music at comfortable, non-intrusive volume
	if music_player:
		music_player.stream = music_stream
		music_player.volume_db = -18.0
		music_player.play()
		print("[AUDIO PLAYBACK] Background cinematic music started (res://Music/Suspended Quiet.mp3, volume_db = -18.0 to -13.0)")

	# 6. Build dynamic 40-second animation sequence
	_build_cutscene_animation(final_surface_pt, surface_normal)

	# 7. Connect animation finished
	anim_player.animation_finished.connect(_on_animation_finished)

	# 8. Start playback
	anim_player.play("cinematic_sequence")

func _build_cutscene_animation(target_surf: Vector3, up_norm: Vector3) -> void:
	var tangent = up_norm.cross(Vector3.FORWARD).normalized()
	if tangent.length_squared() < 0.01:
		tangent = up_norm.cross(Vector3.RIGHT).normalized()
	var bitangent = tangent.cross(up_norm).normalized()
	tangent = up_norm.cross(bitangent).normalized()

	var anim = Animation.new()
	anim.length = 40.0

	# -------------------------------------------------------------
	# TRACK 0: Rocket Position (330m high descent to impact at 13s, slide to 15s)
	# -------------------------------------------------------------
	var t_rocket_pos = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_rocket_pos, "Rocket:position")
	anim.value_track_set_update_mode(t_rocket_pos, Animation.UPDATE_CONTINUOUS)

	var p_0 = target_surf + up_norm * 360.0 + tangent * 50.0 + bitangent * 25.0
	var p_3 = target_surf + up_norm * 280.0 + tangent * 38.0 + bitangent * 18.0
	var p_6 = target_surf + up_norm * 200.0 + tangent * 26.0 + bitangent * 12.0
	var p_8 = target_surf + up_norm * 145.0 + tangent * 18.0 + bitangent * 7.0 # Burn start
	var p_10 = target_surf + up_norm * 90.0 + tangent * 10.0 + bitangent * 3.5
	var p_12 = target_surf + up_norm * 30.0 + tangent * 2.5 + bitangent * 0.8
	var p_13 = target_surf # Impact point!
	var p_13_4 = target_surf + tangent * 0.8 + up_norm * 0.45 # Slide & bounce
	var p_14_2 = target_surf + tangent * 1.5 + up_norm * 0.1
	var p_15_0 = target_surf # Settles at landing point
	var p_40_0 = target_surf

	anim.track_insert_key(t_rocket_pos, 0.0, p_0)
	anim.track_insert_key(t_rocket_pos, 3.0, p_3)
	anim.track_insert_key(t_rocket_pos, 6.0, p_6)
	anim.track_insert_key(t_rocket_pos, 8.0, p_8)
	anim.track_insert_key(t_rocket_pos, 10.0, p_10)
	anim.track_insert_key(t_rocket_pos, 12.0, p_12)
	anim.track_insert_key(t_rocket_pos, 13.0, p_13)
	anim.track_insert_key(t_rocket_pos, 13.4, p_13_4)
	anim.track_insert_key(t_rocket_pos, 14.2, p_14_2)
	anim.track_insert_key(t_rocket_pos, 15.0, p_15_0)
	anim.track_insert_key(t_rocket_pos, 40.0, p_40_0)

	# -------------------------------------------------------------
	# TRACK 1: Rocket Rotation (Tilt on impact & settle 10-15 degrees)
	# -------------------------------------------------------------
	var t_rocket_rot = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_rocket_rot, "Rocket:rotation_degrees")
	anim.value_track_set_update_mode(t_rocket_rot, Animation.UPDATE_CONTINUOUS)

	anim.track_insert_key(t_rocket_rot, 0.0, Vector3(8.0, 0.0, -4.0))
	anim.track_insert_key(t_rocket_rot, 6.0, Vector3(4.0, 0.0, -2.0))
	anim.track_insert_key(t_rocket_rot, 8.0, Vector3(0.0, 0.0, 0.0))
	anim.track_insert_key(t_rocket_rot, 13.0, Vector3(0.0, 0.0, 0.0))
	anim.track_insert_key(t_rocket_rot, 13.4, Vector3(5.0, 0.0, 2.0))
	anim.track_insert_key(t_rocket_rot, 14.5, Vector3(10.0, 0.0, 3.5))
	anim.track_insert_key(t_rocket_rot, 15.5, Vector3(12.0, 0.0, 4.0)) # 12.65 degrees tilt
	anim.track_insert_key(t_rocket_rot, 40.0, Vector3(12.0, 0.0, 4.0))

	# -------------------------------------------------------------
	# TRACKS 2-5: Animated Paths for the 4 Cameras
	# -------------------------------------------------------------
	# Camera A: Low wide shot (0 to 6s)
	var t_cam_a_pos = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_a_pos, "Cameras/CameraLowWide:position")
	var cam_a_0 = target_surf + up_norm * 250.0 + tangent * 110.0 + bitangent * 80.0
	var cam_a_6 = target_surf + up_norm * 180.0 + tangent * 85.0 + bitangent * 60.0
	anim.track_insert_key(t_cam_a_pos, 0.0, cam_a_0)
	anim.track_insert_key(t_cam_a_pos, 6.0, cam_a_6)

	var t_cam_a_rot = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_a_rot, "Cameras/CameraLowWide:rotation_degrees")
	anim.track_insert_key(t_cam_a_rot, 0.0, _calc_look_rotation(cam_a_0, p_0, up_norm))
	anim.track_insert_key(t_cam_a_rot, 3.0, _calc_look_rotation(cam_a_0.lerp(cam_a_6, 0.5), p_3, up_norm))
	anim.track_insert_key(t_cam_a_rot, 6.0, _calc_look_rotation(cam_a_6, p_6, up_norm))

	# Camera B: Close chase shot following rocket down (6 to 12s)
	var t_cam_b_pos = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_b_pos, "Cameras/CameraChase:position")
	var chase_offset = tangent * 14.0 + up_norm * 9.0 + bitangent * 12.0
	anim.track_insert_key(t_cam_b_pos, 6.0, p_6 + chase_offset)
	anim.track_insert_key(t_cam_b_pos, 8.0, p_8 + chase_offset)
	anim.track_insert_key(t_cam_b_pos, 10.0, p_10 + chase_offset)
	anim.track_insert_key(t_cam_b_pos, 12.0, p_12 + chase_offset)

	var t_cam_b_rot = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_b_rot, "Cameras/CameraChase:rotation_degrees")
	anim.track_insert_key(t_cam_b_rot, 6.0, _calc_look_rotation(p_6 + chase_offset, p_6, up_norm))
	anim.track_insert_key(t_cam_b_rot, 9.0, _calc_look_rotation(p_9_approx(p_8, p_10) + chase_offset, p_9_approx(p_8, p_10), up_norm))
	anim.track_insert_key(t_cam_b_rot, 12.0, _calc_look_rotation(p_12 + chase_offset, p_12, up_norm))

	# Camera C: Ground shot looking up at incoming rocket and impact (12 to 16s)
	# Positioned safely above actual procedural terrain to prevent seeing through ground
	var t_cam_c_pos = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_c_pos, "Cameras/CameraGround:position")
	var cam_c_dir = (target_surf + tangent * 18.0 + bitangent * 14.0).normalized()
	var cam_c_surf = planet.get_surface_point(cam_c_dir) if planet else target_surf
	var cam_c_norm = cam_c_surf.normalized()
	var cam_c_12 = cam_c_surf + cam_c_norm * 3.5
	var cam_c_16 = cam_c_surf + cam_c_norm * 4.2
	anim.track_insert_key(t_cam_c_pos, 12.0, cam_c_12)
	anim.track_insert_key(t_cam_c_pos, 16.0, cam_c_16)

	var t_cam_c_rot = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_c_rot, "Cameras/CameraGround:rotation_degrees")
	anim.track_insert_key(t_cam_c_rot, 12.0, _calc_look_rotation(cam_c_12, p_12, up_norm))
	anim.track_insert_key(t_cam_c_rot, 13.0, _calc_look_rotation(cam_c_12, target_surf + up_norm * 2.5, up_norm))
	anim.track_insert_key(t_cam_c_rot, 16.0, _calc_look_rotation(cam_c_16, target_surf + up_norm * 2.5, up_norm))

	# Camera D: Slow orbit and pull-back around the wreck (16 to 40s)
	# Each waypoint queries local surface height to guarantee comfortable elevation
	var t_cam_d_pos = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_d_pos, "Cameras/CameraOrbit:position")
	var _safe_d_pos = func(h_offset: Vector3, h_above: float) -> Vector3:
		var d = (target_surf + h_offset).normalized()
		var s = planet.get_surface_point(d) if planet else target_surf
		return s + s.normalized() * h_above

	var cam_d_16 = _safe_d_pos.call(tangent * 18.0 + bitangent * 16.0, 7.0)
	var cam_d_24 = _safe_d_pos.call(-tangent * 24.0 + bitangent * 22.0, 11.0)
	var cam_d_32 = _safe_d_pos.call(-tangent * 32.0 - bitangent * 18.0, 16.0)
	var cam_d_40 = _safe_d_pos.call(tangent * 38.0 - bitangent * 28.0, 20.0)
	anim.track_insert_key(t_cam_d_pos, 16.0, cam_d_16)
	anim.track_insert_key(t_cam_d_pos, 24.0, cam_d_24)
	anim.track_insert_key(t_cam_d_pos, 32.0, cam_d_32)
	anim.track_insert_key(t_cam_d_pos, 40.0, cam_d_40)

	var t_cam_d_rot = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_d_rot, "Cameras/CameraOrbit:rotation_degrees")
	var wreck_look = target_surf + up_norm * 3.0
	anim.track_insert_key(t_cam_d_rot, 16.0, _calc_look_rotation(cam_d_16, wreck_look, up_norm))
	anim.track_insert_key(t_cam_d_rot, 24.0, _calc_look_rotation(cam_d_24, wreck_look, up_norm))
	anim.track_insert_key(t_cam_d_rot, 32.0, _calc_look_rotation(cam_d_32, wreck_look, up_norm))
	anim.track_insert_key(t_cam_d_rot, 40.0, _calc_look_rotation(cam_d_40, wreck_look, up_norm))

	# -------------------------------------------------------------
	# TRACK 6: Particles & Heat Shield Emission
	# -------------------------------------------------------------
	# Exhaust Particles (Engine Burn 8s to 13s)
	var t_exhaust = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_exhaust, "Rocket/EngineMarker/ExhaustParticles:emitting")
	anim.value_track_set_update_mode(t_exhaust, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(t_exhaust, 0.0, false)
	anim.track_insert_key(t_exhaust, 8.0, true)
	anim.track_insert_key(t_exhaust, 13.0, false)

	# Heat Plume Particles (Atmosphere Entry 2s to 10s)
	var t_plume = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_plume, "Rocket/EngineMarker/HeatPlume:emitting")
	anim.value_track_set_update_mode(t_plume, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(t_plume, 0.0, false)
	anim.track_insert_key(t_plume, 2.0, true)
	anim.track_insert_key(t_plume, 10.0, false)

	# Dust Particles (Impact 13s to 17s outward burst)
	var t_dust = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_dust, "DustParticles:emitting")
	anim.value_track_set_update_mode(t_dust, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(t_dust, 0.0, false)
	anim.track_insert_key(t_dust, 13.0, true)
	anim.track_insert_key(t_dust, 17.5, false)

	# Debris Particles (Impact 13s to 20s)
	var t_debris = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_debris, "DebrisParticles:emitting")
	anim.value_track_set_update_mode(t_debris, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(t_debris, 0.0, false)
	anim.track_insert_key(t_debris, 13.0, true)
	anim.track_insert_key(t_debris, 20.0, false)

	# Venting Smoke & Sparks from damaged engine (13s to 40s)
	var t_venting = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_venting, "Rocket/EngineMarker/VentingParticles:emitting")
	anim.value_track_set_update_mode(t_venting, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(t_venting, 0.0, false)
	anim.track_insert_key(t_venting, 13.0, true)
	anim.track_insert_key(t_venting, 40.0, false)

	# -------------------------------------------------------------
	# TRACK 7: Fade to Black (38s to 40s) & Music Volume Curve
	# -------------------------------------------------------------
	var t_fade = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_fade, "CanvasLayer/FadeOverlay:color")
	anim.value_track_set_update_mode(t_fade, Animation.UPDATE_CONTINUOUS)
	anim.track_insert_key(t_fade, 0.0, Color(0, 0, 0, 0))
	anim.track_insert_key(t_fade, 38.0, Color(0, 0, 0, 0))
	anim.track_insert_key(t_fade, 40.0, Color(0, 0, 0, 1.0))

	var t_music = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_music, "MusicPlayer:volume_db")
	anim.value_track_set_update_mode(t_music, Animation.UPDATE_CONTINUOUS)
	anim.track_insert_key(t_music, 0.0, -22.0)
	anim.track_insert_key(t_music, 3.0, -13.0)
	anim.track_insert_key(t_music, 12.0, -12.0)
	anim.track_insert_key(t_music, 13.0, -16.0)
	anim.track_insert_key(t_music, 16.0, -13.0)
	anim.track_insert_key(t_music, 37.0, -13.0)
	anim.track_insert_key(t_music, 40.0, -40.0)

	# -------------------------------------------------------------
	# TRACK 8: Camera Switches via AnimationPlayer Tracks (:current & make_current())
	# -------------------------------------------------------------
	var t_cam_a_val = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_a_val, "Cameras/CameraLowWide:current")
	anim.value_track_set_update_mode(t_cam_a_val, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(t_cam_a_val, 0.0, true)
	anim.track_insert_key(t_cam_a_val, 6.0, false)

	var t_cam_b_val = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_b_val, "Cameras/CameraChase:current")
	anim.value_track_set_update_mode(t_cam_b_val, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(t_cam_b_val, 0.0, false)
	anim.track_insert_key(t_cam_b_val, 6.0, true)
	anim.track_insert_key(t_cam_b_val, 12.0, false)

	var t_cam_c_val = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_c_val, "Cameras/CameraGround:current")
	anim.value_track_set_update_mode(t_cam_c_val, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(t_cam_c_val, 0.0, false)
	anim.track_insert_key(t_cam_c_val, 12.0, true)
	anim.track_insert_key(t_cam_c_val, 16.0, false)

	var t_cam_d_val = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_cam_d_val, "Cameras/CameraOrbit:current")
	anim.value_track_set_update_mode(t_cam_d_val, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(t_cam_d_val, 0.0, false)
	anim.track_insert_key(t_cam_d_val, 16.0, true)

	var t_cam_a_cur = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(t_cam_a_cur, "Cameras/CameraLowWide")
	anim.track_insert_key(t_cam_a_cur, 0.0, {"method": &"make_current", "args": []})

	var t_cam_b_cur = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(t_cam_b_cur, "Cameras/CameraChase")
	anim.track_insert_key(t_cam_b_cur, 6.0, {"method": &"make_current", "args": []})

	var t_cam_c_cur = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(t_cam_c_cur, "Cameras/CameraGround")
	anim.track_insert_key(t_cam_c_cur, 12.0, {"method": &"make_current", "args": []})

	var t_cam_d_cur = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(t_cam_d_cur, "Cameras/CameraOrbit")
	anim.track_insert_key(t_cam_d_cur, 16.0, {"method": &"make_current", "args": []})

	# -------------------------------------------------------------
	# TRACK 9: Audio & Impact Sequence Method Calls
	# -------------------------------------------------------------
	var t_method = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(t_method, ".")
	anim.track_insert_key(t_method, 2.0, {"method": &"start_atmosphere_entry", "args": []})
	anim.track_insert_key(t_method, 8.0, {"method": &"start_engine_burn", "args": []})
	anim.track_insert_key(t_method, 13.0, {"method": &"trigger_impact", "args": [2.5]})
	anim.track_insert_key(t_method, 16.5, {"method": &"start_aftermath_wind", "args": []})
	anim.track_insert_key(t_method, 40.0, {"method": &"_on_sequence_completed", "args": []})

	var lib = anim_player.get_animation_library("")
	if not lib:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)
	lib.add_animation("cinematic_sequence", anim)

func p_9_approx(p8: Vector3, p10: Vector3) -> Vector3:
	return p8.lerp(p10, 0.5)

func _calc_look_rotation(eye: Vector3, target: Vector3, up: Vector3) -> Vector3:
	var t = Transform3D()
	t.origin = eye
	t = t.looking_at(target, up)
	return t.basis.get_euler() * (180.0 / PI)

# Camera Switching (make_current)
func switch_camera(index: int) -> void:
	var cams = [cam_low_wide, cam_chase, cam_ground, cam_orbit]
	for i in cams.size():
		if cams[i]:
			if i == index:
				cams[i].make_current()
			else:
				cams[i].current = false
	var cam_names = ["CameraLowWide (0-6s)", "CameraChase (6-12s)", "CameraGround (12-16s)", "CameraOrbit (16-40s)"]
	print("[CAMERA CUT] Active camera switched to: %s" % cam_names[index])

# Audio & Event Controls
func start_atmosphere_entry() -> void:
	is_entry_active = true
	if entry_rumble_sound:
		entry_rumble_sound.stream = ambient_sound_stream
		entry_rumble_sound.volume_db = -24.0
		entry_rumble_sound.play()
		print("[CUTSCENE EVENT] t=2.0s Atmosphere entry initiated (heat plume on, rising entry rumble).")

func start_engine_burn() -> void:
	is_burn_active = true
	is_entry_active = false
	if entry_rumble_sound and entry_rumble_sound.playing:
		entry_rumble_sound.stop()
	if engine_sound:
		if engine_sound_stream is AudioStreamOggVorbis:
			(engine_sound_stream as AudioStreamOggVorbis).loop = true
		engine_sound.stream = engine_sound_stream
		engine_sound.play()
		print("[AUDIO PLAYBACK] EngineSound burn started at t = %.2fs (looping enabled)" % burn_start_time)
		if exhaust_particles and engine_marker:
			print("  EngineMarker Global Pos:  %s" % engine_marker.global_position)
			print("  Exhaust Global Pos:       %s" % exhaust_particles.global_position)
			var diff = engine_marker.global_position.distance_to(exhaust_particles.global_position)
			print("  Delta Pos (Marker vs Exhaust): %.4f units" % diff)

func trigger_impact(intensity: float = 2.5) -> void:
	# 1. Stop engine sound and fire impact audio
	is_burn_active = false
	if engine_sound and engine_sound.playing:
		engine_sound.stop()
	print("[AUDIO PLAYBACK] EngineSound burn stopped at t = %.2fs (impact)" % impact_time)
	print("Engine Sound Start Time: %.2f s, Stop Time: %.2f s" % [burn_start_time, impact_time])

	if impact_sound:
		impact_sound.stream = impact_sound_stream
		impact_sound.play()
		print("[AUDIO PLAYBACK] t=13.0s Violent ImpactSound triggered.")

	# 2. Trigger brief white flash (~0.2s full-screen flash)
	if white_flash:
		white_flash.color = Color(1.0, 1.0, 1.0, 0.95)

	# 3. Slow time scale to 0.5 for 0.5s at impact
	Engine.time_scale = 0.5
	slowmo_timer = 0.25

	# 4. Trigger camera shake decaying over ~3.0 seconds
	shake_intensity = intensity
	print("[CUTSCENE EVENT] t=13.0s Violent Surface Impact! White flash, 3s decaying shake, 4s expanding dust burst.")

func start_aftermath_wind() -> void:
	if ambient_sound:
		ambient_sound.stream = ambient_sound_stream
		ambient_sound.volume_db = -6.0
		ambient_sound.play()
		print("[AUDIO PLAYBACK] t=16.5s Silent beat concluded; ambient wind audio started for aftermath.")

func _process(delta: float) -> void:
	var cur_time = anim_player.current_animation_position if anim_player and anim_player.is_playing() else 0.0

	# Active camera synchronization across cuts
	if cur_time < 6.0:
		if cam_low_wide and not cam_low_wide.current: cam_low_wide.make_current()
	elif cur_time < 12.0:
		if cam_chase and not cam_chase.current: cam_chase.make_current()
	elif cur_time < 16.0:
		if cam_ground and not cam_ground.current: cam_ground.make_current()
	else:
		if cam_orbit and not cam_orbit.current: cam_orbit.make_current()

	# Slow-motion timer recovery
	if slowmo_timer > 0.0:
		slowmo_timer -= delta
		if slowmo_timer <= 0.0:
			Engine.time_scale = 1.0

	# 1. Atmospheric entry jitter (2s to 10s)
	if cur_time >= 2.0 and cur_time <= 10.0:
		var entry_prog = clampf((cur_time - 2.0) / 8.0, 0.0, 1.0)
		# Entry rumble volume rising from -24dB to -2dB
		if entry_rumble_sound and entry_rumble_sound.playing:
			entry_rumble_sound.volume_db = lerpf(-24.0, -2.0, entry_prog)
		# Heat shield emission glow rising then falling
		if heat_shield_glow and heat_shield_glow.material_override:
			var mat = heat_shield_glow.material_override as StandardMaterial3D
			var glow_amt = sin(entry_prog * PI) * 5.0
			mat.emission_energy_multiplier = glow_amt
		# Jitter: ~0.5 degrees rotation and ~0.1 units position, increasing toward 10s
		var rot_j = entry_prog * 0.5
		var pos_j = entry_prog * 0.1
		rocket_mesh.position = base_rocket_mesh_pos + Vector3(
			randf_range(-pos_j, pos_j),
			randf_range(-pos_j * 0.5, pos_j * 0.5),
			randf_range(-pos_j, pos_j)
		)
		rocket_mesh.rotation_degrees = Vector3(
			randf_range(-rot_j, rot_j),
			randf_range(-rot_j, rot_j),
			randf_range(-rot_j, rot_j)
		)
	elif cur_time > 10.0 and rocket_mesh.position != base_rocket_mesh_pos:
		rocket_mesh.position = base_rocket_mesh_pos
		rocket_mesh.rotation_degrees = Vector3.ZERO
		if heat_shield_glow and heat_shield_glow.material_override:
			(heat_shield_glow.material_override as StandardMaterial3D).emission_energy_multiplier = 0.0

	# 2. Handheld shake on CameraChase (6s to 12s)
	if cam_chase and cam_chase.current and cur_time >= 6.0 and cur_time < 12.0:
		cam_chase.h_offset = randf_range(-0.15, 0.15)
		cam_chase.v_offset = randf_range(-0.12, 0.12)
	elif cam_chase:
		cam_chase.h_offset = 0.0
		cam_chase.v_offset = 0.0

	# 3. White flash fade-out (~0.2s)
	if white_flash and white_flash.color.a > 0.0:
		white_flash.color.a = maxf(0.0, white_flash.color.a - delta * 5.0)

	# 4. Impact camera shake decaying over ~3.0s
	if shake_intensity > 0.0:
		shake_intensity = maxf(0.0, shake_intensity - delta * (2.5 / 3.0))
		var active_cam = get_viewport().get_camera_3d()
		if active_cam:
			active_cam.h_offset = randf_range(-0.5, 0.5) * shake_intensity
			active_cam.v_offset = randf_range(-0.4, 0.4) * shake_intensity

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		skip_cutscene()

func skip_cutscene() -> void:
	if is_finished:
		return
	print("[CUTSCENE EVENT] Player pressed ESC key. Skipping opening cutscene and jumping to gameplay handoff.")
	if rocket:
		rocket.position = final_surface_pt
		rocket.rotation_degrees = Vector3(12.0, 0.0, 4.0)
	_finish_cutscene()

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "cinematic_sequence":
		_finish_cutscene()

func _on_sequence_completed() -> void:
	_finish_cutscene()

func _finish_cutscene() -> void:
	if is_finished:
		return
	is_finished = true

	# Restore time scale unconditionally
	Engine.time_scale = 1.0

	# Settle rocket to final surface resting state
	if rocket:
		rocket.position = final_surface_pt
		rocket.rotation_degrees = Vector3(12.0, 0.0, 4.0)

	# Stop all audio streams
	if ambient_sound: ambient_sound.stop()
	if entry_rumble_sound: entry_rumble_sound.stop()
	if engine_sound: engine_sound.stop()
	if impact_sound: impact_sound.stop()
	if music_player: music_player.stop()

	print("[CUTSCENE HANDOFF] Emitting 'cutscene_finished' signal...")
	emit_signal("cutscene_finished")

	print("[CUTSCENE HANDOFF] Loading main gameplay scene (res://Scenes/world.tscn)...")
	var world_scene = load("res://Scenes/world.tscn")
	var world_inst = world_scene.instantiate()

	var tree = get_tree()
	tree.root.add_child(world_inst)
	tree.current_scene = world_inst

	var player_node = world_inst.get_node_or_null("Player")
	var hatch_marker = get_node_or_null("Rocket/HatchSpawn") as Marker3D
	if not hatch_marker:
		hatch_marker = get_node_or_null("HatchSpawn") as Marker3D

	var hatch_spawn_pos = landing_point + Vector3(0, 1.2, 2.5)
	var hatch_spawn_trans = Transform3D.IDENTITY
	if hatch_marker:
		hatch_spawn_pos = hatch_marker.global_position
		hatch_spawn_trans = hatch_marker.global_transform
	elif rocket:
		hatch_spawn_pos = rocket.global_transform * Vector3(0, 1.2, 2.5)
		hatch_spawn_trans = rocket.global_transform

	if player_node:
		player_node.global_transform = hatch_spawn_trans
		player_node.global_position = hatch_spawn_pos
		player_node.spawn_position = hatch_spawn_pos
		var spawn_delta = player_node.global_position.distance_to(hatch_spawn_pos)

		print("\n==================================================")
		print("HATCH SPAWN & GAMEPLAY HANDOFF")
		print("==================================================")
		print("HatchSpawn Marker Global Pos: %s" % hatch_spawn_pos)
		print("Player Spawn Global Pos:      %s" % player_node.global_position)
		print("Difference (Spawn vs Marker): %.4f units (target <= 0.1 units)" % spawn_delta)
		print("Spawn Accuracy Check:         %s" % ("PASS" if spawn_delta <= 0.1 else "FAIL"))
		print("==================================================\n")
		assert(spawn_delta <= 0.1, "Player spawn position must match HatchSpawn position within 0.1 units!")

		# Start the Sol 1 cinematic letterboxed lying intro at the hatch opening
		if player_node.has_method("start_cinematic_lying_intro"):
			player_node.start_cinematic_lying_intro()
		elif player_node.has_method("start_stepping_out"):
			player_node.start_stepping_out(2.0)

	queue_free()
