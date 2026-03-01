extends Node3D

const root3 = sqrt(3)

# DEBUG FLAG
var debug = true
var debug_F2_tap = false
var debug_F3_tap = false
var debug_F5_tap = false

var cam_prev_y = Vector3.UP
var cam_prev_z = Vector3.BACK
var prev_screenshake_offset = Vector2.ZERO

var start_pos

var screenshake_direction = Vector2.ZERO
var screenshake_magnitude = 0
var screenshake_jitter = 0
const poise_screenshake_mag = 0.05
const screenshake_mag_decay = 0.002
const screenshake_jit_decay = 0.001

func respawn():
	$"..".transform.origin = Vector3.UP
	$"..".transform.basis = Basis.FLIP_Z
	$"..".vel_vec = Vector3.ZERO
	$"..".acc_vec = Vector3.ZERO
	$"..".poise_acc = Vector3.ZERO
	$"..".poise_vel = Vector3.ZERO
	$"..".poise_pos = Vector3.ZERO
	$"..".health = $"..".max_health
	$"..".position = start_pos
	$"..".dash_counter = 0
	$"..".set_inactionable_timer(30)

func _ready() -> void:
	start_pos = $"..".position

func screenshake_set_direction(dir : Vector2):
	screenshake_direction = dir

func screenshake_set_magnitude(mag : float):
	screenshake_magnitude = mag

func screenshake_set_jitter(j : float):
	screenshake_jitter = j

func screenshake_step():
	screenshake_magnitude = max(screenshake_magnitude - screenshake_mag_decay, 0)
	screenshake_jitter = max(screenshake_jitter - screenshake_jit_decay, 0)

func take_damage():
	screenshake_set_jitter(1)

func _process(delta: float) -> void:
	if debug == true:
		# reset orientation
		if Input.is_key_pressed(KEY_F1):
			respawn()
		# change engine level
		if Input.is_key_pressed(KEY_F2) and debug_F2_tap == false:
			debug_F2_tap = true
			if Input.is_key_pressed(KEY_SHIFT):
				if $"..".clutch_lvl > 0:
					$"..".clutch_lvl -= 1
			else:
				if $"..".clutch_lvl < $"..".clutch_max_lvl:
					$"..".clutch_lvl += 1
			$"..".compute_handling_stats()
			
			# Update max display values for lateral and vertical velocity gauges
			$"../../Camera3D/GUI".lat_vel_gauge.set_max_value(int($"..".max_spd * 1.25))
			$"../../Camera3D/GUI".vrt_vel_gauge.set_max_value(int($"..".max_spd * 1.25))
		if !Input.is_key_pressed(KEY_F2):
			debug_F2_tap = false
		# change poiser level
		if Input.is_key_pressed(KEY_F3) and debug_F3_tap == false:
			debug_F3_tap = true
			if Input.is_key_label_pressed(KEY_SHIFT):
				if $"..".poiser_lvl > 0:
					$"..".poiser_lvl -= 1
			else:
				if $"..".poiser_lvl < $"..".poiser_max_lvl:
					$"..".poiser_lvl += 1
			$"..".compute_handling_stats()
		if !Input.is_key_pressed(KEY_F3):
			debug_F3_tap = false
		# change armor level
		if Input.is_key_pressed(KEY_F5) and debug_F5_tap == false:
			debug_F5_tap = true
			if Input.is_key_label_pressed(KEY_SHIFT):
				if $"..".deflector_lvl > 0:
					$"..".deflector_lvl -= 1
			else:
				if $"..".deflector_lvl < $"..".deflector_max_lvl:
					$"..".deflector_lvl += 1
			$"..".compute_handling_stats()
			$"..".health = $"..".max_health
		if !Input.is_key_pressed(KEY_F5):
			debug_F5_tap = false
	
	# Longitudinal thrust
	if Input.is_action_pressed("thrust_forward"):
		$"..".demand_lon(Input.get_action_strength("thrust_forward"))
	if Input.is_action_pressed("thrust_backward"):
		$"..".demand_lon(-Input.get_action_strength("thrust_backward"))
		
	# Strafing
	if Input.is_action_pressed("strafe_up"):
		$"..".demand_vrt(Input.get_action_strength("strafe_up"))
	if Input.is_action_pressed("strafe_down"):
		$"..".demand_vrt(-Input.get_action_strength("strafe_down"))
	if Input.is_action_pressed("strafe_left"):
		$"..".demand_lat(-Input.get_action_strength("strafe_left"))
	if Input.is_action_pressed("strafe_right"):
		$"..".demand_lat(Input.get_action_strength("strafe_right"))
		
	# Rotation
	if Input.is_action_pressed("pitch_up"):
		$"..".demand_pitch(Input.get_action_strength("pitch_up"))
	if Input.is_action_pressed("pitch_down"):
		$"..".demand_pitch(-Input.get_action_strength("pitch_down"))
	if Input.is_action_pressed("roll_cw"):
		$"..".demand_roll(Input.get_action_strength("roll_cw"))
	if Input.is_action_pressed("roll_ccw"):
		$"..".demand_roll(-Input.get_action_strength("roll_ccw"))
	if Input.is_action_pressed("yaw_right"):
		$"..".demand_yaw(Input.get_action_strength("yaw_right"))
	if Input.is_action_pressed("yaw_left"):
		$"..".demand_yaw(-Input.get_action_strength("yaw_left"))
	
	# Dash
	if Input.is_action_just_pressed("dash"):
		$"..".dash()
		#get_node("../..").set_slomo(0.2, [10, 30, 30])
		
	## Assign camera position
	var cam = get_node("../../Camera3D")
	if cam != null:
		# Camera vector interpolation
		var cam_y_vec = cam_prev_y.lerp($"..".transform.basis.y, 0.1)
		var cam_z_vec = cam_prev_z.lerp(Vector3.BACK if abs($"..".transform.basis.z.dot(Vector3.UP)) == 1 else lerp(-$"..".vel_vec, $"..".transform.basis.z, 0.99), 0.1)
		cam_prev_z = cam_z_vec
		cam_prev_y = cam_y_vec
		
		# Set camera position
		cam_z_vec = 6 * cam_z_vec.normalized()
		cam.transform.origin = $"..".transform.origin + cam_z_vec + cam_y_vec
		
		# Add screenshake
		var screenshake_offset = randf_range(0, screenshake_magnitude) * screenshake_direction + screenshake_jitter * Vector2.RIGHT.rotated(randf_range(0, TAU))
		screenshake_offset = lerp(prev_screenshake_offset, screenshake_offset, 0.2)
		prev_screenshake_offset = screenshake_offset
		cam.transform.origin += cam.transform.basis.x * screenshake_offset.x + cam.transform.basis.y * screenshake_offset.y
		
		# Define camera basis
		#if abs(transform.basis.z.dot(Vector3.UP)) < 0.86:
		cam.transform.basis.z = cam.transform.origin - $"..".transform.origin#(-($"..".transform.origin - cam.transform.origin)).normalized()
		cam.transform.basis.x = cam.transform.basis.z.cross(Vector3.UP)
		cam.transform.basis.y = cam.transform.basis.x.cross(cam.transform.basis.z)
		
		var poise_pos = $"..".poise_pos
		var screenshake_dir = Vector2(poise_pos.project(cam.transform.basis.x).length(), poise_pos.project(cam.transform.basis.y).length()).normalized()
		var screenshake_mag = poise_screenshake_mag * poise_pos.length() / root3
		if screenshake_mag < 0.1 * poise_screenshake_mag:
			screenshake_mag = 0
		screenshake_set_direction(screenshake_dir)
		screenshake_set_magnitude(screenshake_mag)
		screenshake_step()

func _physics_process(delta: float) -> void:
	# Move actor and collide
	var collision = $"..".move_and_collide($"..".vel_vec * delta)
	if collision:
		var collision_normal = collision.get_normal()
		var vel_dot_normal = $"..".vel_vec.normalized().dot(collision_normal)
		if vel_dot_normal < 0:
			# Inflict crash damage based on angle of impact
			var crash_damage = floor(-4 * vel_dot_normal * $"..".vel_vec.project(collision_normal).length())
			if crash_damage > 0:
				$"../sfx_dmg_crash".playing = true
				$"..".take_damage(crash_damage)
				screenshake_set_jitter(0.04)
			$"..".vel_vec = $"..".vel_vec.slide(collision_normal)
			if $"..".vel_vec != Vector3.ZERO:
				transform.basis = Basis.looking_at(lerp(-transform.basis.z,
					-transform.basis.z.slide(collision_normal), 0.05), transform.basis.y)
				# Why is this necessary?
				transform.basis.x *= -1
