extends Node3D

const root3 = sqrt(3)

# DEBUG FLAG
var debug = true
var debug_F2_tap = false
var debug_F3_tap = false
var debug_F4_tap = false
var debug_F5_tap = false

var cam_prev_y = Vector3.UP
var cam_prev_z = Vector3.BACK
var prev_screenshake_offset = Vector2.ZERO

var start_pos

var screenshake_direction = Vector2.ZERO
var screenshake_magnitude = 0
var screenshake_jitter = 0
var shake_position = 0
const poise_screenshake_mag = 0.05
const screenshake_mag_decay = 0.002
const screenshake_jit_decay = 0.001

const dash_tap_spacing = 30
var dash_tap_manager
const dash_input_vector_map = {"thrust_forward" : Vector3.FORWARD, "thrust_backward" : Vector3.BACK,
	"strafe_left" : Vector3.LEFT, "strafe_right" : Vector3.RIGHT, "strafe_up" : Vector3.UP,
	"strafe_down" : Vector3.DOWN}

class tap_manager:
	var input
	var prev_val = 0
	
	func _init(input_name : String):
		input = input_name
	
	func get_input_name():
		return input
	
	func step():
		var ret_val = false
		if Input.get_action_strength(input) > 0.5 and prev_val < 0.5:
			ret_val = true
		prev_val = Input.get_action_strength(input)
		return ret_val

class master_tap_manager:
	var manager_list = Array()
	var tap_input = -1
	var tap_spacing_timer = 0
	var tap_spacing
	
	func _init(spacing):
		tap_spacing = spacing
	
	func add_manager(input_name : String):
		manager_list.append(tap_manager.new(input_name))
	
	func step():
		var i = 0
		tap_spacing_timer -= 1
		if tap_spacing_timer == 0:
			tap_input = -1
		var next_tap_input = -1
		for m in manager_list:
			if m.step() == true:
				next_tap_input = i
				tap_spacing_timer = tap_spacing
				break
			i += 1
		if next_tap_input > -1:
			if tap_input == -1:
				tap_input = next_tap_input
			elif next_tap_input == tap_input:
				tap_input = -1
				return manager_list[next_tap_input].get_input_name()
		return null

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
	await get_parent().ready
	await $"../../Camera3D/GUI".ready
	
	start_pos = $"..".position
	$"../../Camera3D/GUI".set_max_spd(int($"..".max_spd * 2))
	$"../../Camera3D/GUI".set_max_energy(int($"..".max_energy))
	$"../../Camera3D/GUI".set_max_health(int($"..".max_health))
	
	dash_tap_manager = master_tap_manager.new(dash_tap_spacing)
	dash_tap_manager.add_manager("thrust_forward")
	dash_tap_manager.add_manager("thrust_backward")
	dash_tap_manager.add_manager("strafe_right")
	dash_tap_manager.add_manager("strafe_left")
	dash_tap_manager.add_manager("strafe_up")
	dash_tap_manager.add_manager("strafe_down")

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
			$"../../Camera3D/GUI".set_max_spd(int($"..".max_spd * 2))
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
		# change drive level
		if Input.is_key_pressed(KEY_F4) and debug_F4_tap == false:
			debug_F4_tap = true
			if Input.is_key_label_pressed(KEY_SHIFT):
				if $"..".drive_lvl > 0:
					$"..".drive_lvl -= 1
			else:
				if $"..".drive_lvl < $"..".drive_max_lvl:
					$"..".drive_lvl += 1
			$"..".compute_handling_stats()
			$"../../Camera3D/GUI".set_max_energy($"..".max_energy)
			$"..".energy = $"..".max_energy
		if !Input.is_key_pressed(KEY_F4):
			debug_F4_tap = false
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
			$"../../Camera3D/GUI".set_max_health($"..".max_health)
			$"..".health = $"..".max_health
		if !Input.is_key_pressed(KEY_F5):
			debug_F5_tap = false
	
	# Longitudinal thrust
	$"..".demand_lon(Input.get_axis("thrust_backward", "thrust_forward"))	
	# Strafing
	$"..".demand_vrt(Input.get_axis("strafe_down", "strafe_up"))
	$"..".demand_lat(Input.get_axis("strafe_left", "strafe_right"))
	# Rotation
	$"..".demand_pitch(Input.get_axis("pitch_down", "pitch_up"))
	$"..".demand_roll(Input.get_axis("roll_ccw", "roll_cw"))
	$"..".demand_yaw(Input.get_axis("yaw_left", "yaw_right"))
	
	var dash_input = dash_tap_manager.step()
	if dash_input != null:
		$"..".dash(dash_input_vector_map[dash_input])
	
	## Assign camera position
	var cam = get_node("../../Camera3D")
	if cam != null:
		# Camera vector interpolation
		var cam_y_vec = cam_prev_y.lerp($"..".transform.basis.y, 0.1)
		var cam_z_vec = cam_prev_z.lerp(Vector3.BACK if abs($"..".transform.basis.z.dot(Vector3.UP)) == 1 else lerp(-$"..".vel_vec, $"..".transform.basis.z, 1), 0.1)
		cam_prev_z = cam_z_vec
		cam_prev_y = cam_y_vec
		
		# Set camera position
		cam_z_vec = 6 * cam_z_vec.normalized()
		cam.transform.origin = $"..".transform.origin + cam_z_vec + cam_y_vec
		
		# Add screenshake
		var screenshake_offset = sin(shake_position) * screenshake_magnitude * screenshake_direction + screenshake_jitter * Vector2.RIGHT.rotated(randf_range(0, TAU))
		shake_position += delta
		shake_position = fmod(shake_position, TAU)
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
