extends Node3D

const root3 = sqrt(3)
const two_over_root3 = 2 / root3
const cam_path = "root/Main/Camera3D"

# DEBUG FLAG
var debug = true
var debug_F2_tap = false
var debug_F3_tap = false
var debug_F4_tap = false
var debug_F5_tap = false

var start_pos

const haptic_strength = 0.2

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
	var p = get_parent()
	p.transform.origin = Vector3.UP
	p.transform.basis = Basis.FLIP_Z
	p.vel_vec = Vector3.ZERO
	p.acc_vec = Vector3.ZERO
	p.poise_acc = Vector3.ZERO
	p.poise_vel = Vector3.ZERO
	p.poise_pos = Vector3.ZERO
	p.health = p.max_health
	p.position = start_pos
	p.dash_counter = 0
	p.set_inactionable_timer(30)

func _ready() -> void:
	await get_parent().ready
	
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

func take_damage(damage : int):
	get_parent().take_damage(damage)
	# TODO yuck wtf
	$"../../Camera3D".screenshake_set_jitter(0.4)

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

func _physics_process(delta: float) -> void:
	var vel_vec = get_parent().vel_vec
	var weak_haptic = 0
	var strong_haptic = 0
	
	# Move actor and collide
	var collision = get_parent().move_and_collide(vel_vec * delta)
	if collision:
		var collision_normal = collision.get_normal()
		var vel_dot_normal = vel_vec.normalized().dot(collision_normal)
		if vel_dot_normal < 0:
			# Inflict crash damage based on angle of impact
			var crash_damage = floor(-4 * vel_dot_normal * vel_vec.project(collision_normal).length())
			if crash_damage > 0:
				$"../sfx_dmg_crash".playing = true
				take_damage(crash_damage)
				#strong_haptic = haptic_strength
			get_parent().vel_vec = vel_vec.slide(collision_normal)
			if get_parent().vel_vec != Vector3.ZERO:
				transform.basis = Basis.looking_at(lerp(-transform.basis.z,
					-transform.basis.z.slide(collision_normal), 0.05), transform.basis.y)
				# Why is this necessary?
				transform.basis.x *= -1
	
	# Update camera
	# TODO How do I do this cleanly
	var cam = $"../../Camera3D"
	cam.set_tracking_transform(get_parent().transform)
	cam.set_tracking_velocity(vel_vec)
	
	# Slideslip haptic vibration
	if vel_vec != Vector3.ZERO:
		var sideslip_vector_dot = 1 - abs(vel_vec.normalized().dot(get_parent().transform.basis.z))
		weak_haptic = haptic_strength * pow(sideslip_vector_dot, 2)
	
	if weak_haptic > 0 or strong_haptic > 0:
		pass#Input.start_joy_vibration(0, weak_haptic, strong_haptic, delta)
