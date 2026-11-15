extends CharacterBody3D
class_name PlayerController

# PlayerController.gd
# Smooth Outer Wilds-style spherical movement with responsive animations.

signal fuel_changed(current: float, max_fuel: float)
signal grounded_changed(is_grounded: bool)

# Movement speeds
@export_group("Locomotion")
@export var walk_speed: float = 4.8
@export var run_speed: float = 9.2
@export var acceleration: float = 24.0
@export var ground_friction: float = 20.0
@export var air_friction: float = 3.0
@export var alignment_speed: float = 12.0

# Jetpack & Gravity
@export_group("Jump & Jetpack")
@export var jump_force: float = 7.5
@export var jetpack_force: float = 14.0
@export var max_fuel: float = 100.0
@export var fuel_burn_rate: float = 28.0
@export var fuel_recharge_rate: float = 40.0
@export var default_gravity: float = 5.8 # Mars low-gravity

# State
var current_fuel: float = 100.0
var current_gravity_dir: Vector3 = Vector3.DOWN
var current_planet: Node3D = null
var is_thrusting: bool = false
var in_ship: bool = false

# Jump & Ground debouncing (eliminates walk stutter and jump delay)
var air_timer: float = 0.0
var is_jumping: bool = false

# Node references
@onready var camera_arm: Node3D = $CameraArm
@onready var visual_mesh: Node3D = $VisualMesh
@onready var jetpack_particles: GPUParticles3D = $VisualMesh/JetpackParticles
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
var anim_player: AnimationPlayer = null

func _ready() -> void:
	if GameManager:
		GameManager.player = self
	
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(65.0)
	current_fuel = max_fuel
	
	# Locate AnimationPlayer within visual mesh
	var players = visual_mesh.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		anim_player = players[0] as AnimationPlayer
		_play_anim("idle")

func _physics_process(delta: float) -> void:
	if in_ship:
		return
	
	_update_gravity_and_orientation(delta)
	_handle_movement_and_jetpack(delta)

func _update_gravity_and_orientation(delta: float) -> void:
	# Locate nearest planet
	if GameManager:
		current_planet = GameManager.get_nearest_planet(global_position)
	
	if current_planet:
		current_gravity_dir = (current_planet.global_position - global_position).normalized()
	else:
		current_gravity_dir = Vector3.DOWN
	
	var surface_normal = -current_gravity_dir
	var current_up = global_basis.y
	
	# Smoothly tilt character body so feet face planet center
	var angle_diff = current_up.angle_to(surface_normal)
	if angle_diff > 0.0005:
		var q = Quaternion(current_up, surface_normal)
		var target_basis = Basis(q) * global_basis
		global_basis = global_basis.slerp(target_basis, clamp(alignment_speed * delta, 0.0, 1.0)).orthonormalized()

func _handle_movement_and_jetpack(delta: float) -> void:
	var surface_normal = -current_gravity_dir
	
	# Deconstruct velocity into vertical and tangent components
	var v_vertical_speed = velocity.dot(surface_normal)
	var v_tangent = velocity - surface_normal * v_vertical_speed
	
	# Input reading
	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var is_running = Input.is_action_pressed("run")
	var target_speed = run_speed if is_running else walk_speed
	
	# Camera tangent projection
	var forward_tangent = camera_arm.get_camera_forward_projected(surface_normal) if camera_arm else -global_basis.z
	var right_tangent = forward_tangent.cross(surface_normal).normalized()
	
	var move_dir = (forward_tangent * -input_vec.y + right_tangent * input_vec.x)
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()
	
	# Accelerate / Decelerate
	if move_dir.length_squared() > 0.01:
		v_tangent = v_tangent.move_toward(move_dir * target_speed, acceleration * delta)
		
		# Smooth mesh rotation to face travel direction without popping
		if visual_mesh:
			var target_t = visual_mesh.global_transform.looking_at(visual_mesh.global_position + move_dir, surface_normal)
			visual_mesh.global_transform = visual_mesh.global_transform.interpolate_with(target_t, clamp(18.0 * delta, 0.0, 1.0)).orthonormalized()
	else:
		var friction = ground_friction if is_on_floor() else air_friction
		v_tangent = v_tangent.move_toward(Vector3.ZERO, friction * delta)
	
	# Check floor and handle ground state debouncing
	var on_floor = is_on_floor()
	if on_floor:
		if not is_jumping:
			air_timer = 0.0
			floor_snap_length = 0.8
		else:
			# Landed after jump
			if v_vertical_speed <= 0.1:
				is_jumping = false
				air_timer = 0.0
				floor_snap_length = 0.8
	else:
		air_timer += delta
	
	# Jump handling: INSTANT response
	is_thrusting = false
	if Input.is_action_just_pressed("jump") and on_floor:
		v_vertical_speed = jump_force
		is_jumping = true
		air_timer = 0.15 # immediately treated as airborne
		floor_snap_length = 0.0 # release floor snap immediately
		_play_anim("jump", 0.08) # zero-latency jump animation
	elif on_floor and not is_jumping:
		# Ground physics
		if v_vertical_speed < 0.0:
			v_vertical_speed = 0.0
		# Recharge fuel on surface
		if current_fuel < max_fuel:
			current_fuel = min(max_fuel, current_fuel + fuel_recharge_rate * delta)
			fuel_changed.emit(current_fuel, max_fuel)
	else:
		# Airborne: apply Mars gravity
		var gravity_accel = default_gravity
		if current_planet and "gravity_strength" in current_planet:
			gravity_accel = current_planet.gravity_strength
		v_vertical_speed -= gravity_accel * delta
		
		# Jetpack in mid-air
		if Input.is_action_pressed("jump") and current_fuel > 0.0:
			v_vertical_speed += jetpack_force * delta
			current_fuel = max(0.0, current_fuel - fuel_burn_rate * delta)
			fuel_changed.emit(current_fuel, max_fuel)
			is_thrusting = true
	
	if jetpack_particles:
		jetpack_particles.emitting = is_thrusting
	
	# Reconstruct velocity & move
	velocity = v_tangent + surface_normal * v_vertical_speed
	up_direction = surface_normal
	move_and_slide()
	
	# Update animations
	_update_animation_state(v_tangent.length(), is_running)
	
	grounded_changed.emit(is_on_floor())

func _update_animation_state(horiz_speed: float, sprinting: bool) -> void:
	if not anim_player:
		return
	
	var in_air = is_jumping or air_timer > 0.12 or is_thrusting
	
	if in_air:
		_play_anim("jump", 0.1)
		anim_player.speed_scale = 1.0
	elif horiz_speed > 0.35:
		if sprinting:
			_play_anim("run", 0.15)
			anim_player.speed_scale = clamp(horiz_speed / run_speed, 0.85, 1.3)
		else:
			_play_anim("walk", 0.15)
			anim_player.speed_scale = clamp(horiz_speed / walk_speed, 0.85, 1.3)
	else:
		_play_anim("idle", 0.25)
		anim_player.speed_scale = 1.0

func _play_anim(anim_name: String, blend_time: float = 0.15) -> void:
	if anim_player and anim_player.current_animation != anim_name:
		anim_player.play(anim_name, blend_time)
