extends CharacterBody3D

@export var texture : Texture3D

enum ax {
	lat,
	vrt,
	lon
}

enum th {
	main_lt,
	main_rt,
	vrt_fr_lt,
	vrt_fr_rt,
	vrt_rr_lt,
	vrt_rr_rt,
	lat_fr_up,
	lat_fr_lw,
	lat_rr_up,
	lat_rr_lw
}

class thruster:
	var thrust_vec : Vector3
	var toward_vec : Vector3
	var varying_axis : int

var thruster_array = null

# Axis demand
var lon_demand = 0
var vrt_demand = 0
var lat_demand = 0
var pitch_demand = 0
var roll_demand = 0
var yaw_demand = 0

# Physics scalars
var max_spd = 36
var grip_main_static = 2
var grip_vrt_static = 0.4
var grip_lat_static = 0.4
var sliding_grip_coef = 0.7

# Physics vectors
var vel_vec = Vector3.ZERO
var thr_vel_vec = Vector3.ZERO
var rel_spd = Vector3.ZERO
var acc_vec = Vector3.ZERO

# Thrust values
var main_thrust = 0.3
var vrt_thrust = 0.1
var lat_thrust = 0.1
var thrust_pitch = 0.08
var thrust_roll = 0.08
var thrust_yaw = 0.08

# Drag values
var drag_airframe = 0.1
var max_drag_decel = 10

# Poise scalars
var poise_spring_const = 1
var poise_damping = 0

# Poise vectors
var poise_pos = Vector3.ZERO
var poise_vel = Vector3.ZERO
var poise_acc = Vector3.ZERO

# Camera previous vectors
var cam_prev_y = Vector3.UP
var cam_prev_z = Vector3.BACK

# DEBUG FLAG
var debug = true

func init_thruster(th_vec, tow_vec, axis):
	var thr = thruster.new()
	thr.thrust_vec = th_vec
	thr.toward_vec = tow_vec
	thr.varying_axis = axis
	return thr

func _ready() -> void:
	var th_arr = Array()
	
	var th_vec_arr = [Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0)]
	var tow_vec_arr = [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, -1), Vector3(0, -1, -1), Vector3(0, 1, 1), Vector3(0, -1, 1)]
	
	# Main thrusters
	for i in 2:
		th_arr.append(init_thruster(th_vec_arr[i].normalized(), tow_vec_arr[i].normalized(), ax.lon))
	# Vertical thrusters
	for i in range(2, 6):
		th_arr.append(init_thruster(th_vec_arr[i].normalized(), tow_vec_arr[i].normalized(), ax.vrt))
	# Lateral thrusters
	for i in range(6, 10):
		th_arr.append(init_thruster(th_vec_arr[i].normalized(), tow_vec_arr[i].normalized(), ax.lat))
	
	thruster_array = th_arr
	
	transform.basis = Basis.FLIP_Z

# Movement demand accessors
func demand_lon(x : float):
	lon_demand = x
func demand_vrt(x : float):
	vrt_demand = x
func demand_lat(x : float):
	lat_demand = x
func demand_pitch(x : float):
	pitch_demand = x
func demand_roll(x : float):
	roll_demand = x
func demand_yaw(x : float):
	yaw_demand = x

func calc_pve_thrust():
	# Main thruster demand
	var main_lt = lon_demand
	var main_rt = clamp(lon_demand + yaw_demand, -1, 1)
	# Vertical thruster demand
	var vrt_fr_lt = clamp(vrt_demand + pitch_demand + roll_demand, -1, 1)
	var vrt_fr_rt = clamp(vrt_demand + pitch_demand, -1, 1)
	var vrt_rr_lt = clamp(vrt_demand + roll_demand, -1, 1)
	var vrt_rr_rt = vrt_demand
	# Lateral thruster demand
	var lat_fr_up = clamp(lat_demand + roll_demand, -1, 1)
	var lat_fr_lw = lat_demand
	var lat_rr_up = clamp(lat_demand + roll_demand + yaw_demand, -1, 1)
	var lat_rr_lw = clamp(lat_demand + yaw_demand, -1, 1)
	
	return [main_lt, main_rt, vrt_fr_lt, vrt_fr_rt, vrt_rr_lt, vrt_rr_rt, lat_fr_up, lat_fr_lw, lat_rr_up, lat_rr_lw]
	
func calc_nve_thrust():
	# Main thruster demand
	var main_lt = yaw_demand
	var main_rt = 0
	# Vertical thruster demand
	var vrt_fr_lt = 0
	var vrt_fr_rt = roll_demand
	var vrt_rr_lt = pitch_demand
	var vrt_rr_rt = clamp(pitch_demand + roll_demand, -1, 1)
	# Lateral thruster demand
	var lat_fr_up = yaw_demand
	var lat_fr_lw = clamp(roll_demand + yaw_demand, -1, 1)
	var lat_rr_up = 0
	var lat_rr_lw = roll_demand
	
	return [main_lt, main_rt, vrt_fr_lt, vrt_fr_rt, vrt_rr_lt, vrt_rr_rt, lat_fr_up, lat_fr_lw, lat_rr_up, lat_rr_lw]
	
func calc_applied_thrust():
	var pve = calc_pve_thrust()
	var nve = calc_nve_thrust()
	var arr = Array()
	
	for i in 10:
		arr.append(pve[i] - nve[i])
	
	return arr
	
func calc_actual_thrust(arr : Array):
	var ret_arr = Array()
	
	# TODO: get rid of magic numbers in here
	# Main thruster thrust
	for i in 2:
		ret_arr.append(sign(arr[i]) * min(abs(main_thrust * arr[i]), grip_main_static * ((1 + thruster_array[i].toward_vec.dot(poise_pos)) * thruster_array[i].thrust_vec)))
	# Vertical thruster thrust
	for i in range(2, 6):
		ret_arr.append(sign(arr[i]) * min(abs(vrt_thrust * arr[i]), grip_main_static * ((1 + thruster_array[i].toward_vec.dot(poise_pos)) * thruster_array[i].thrust_vec)))
	# Lateral thruster thrust
	for i in range(6, 10):
		ret_arr.append(sign(arr[i]) * min(abs(lat_thrust * arr[i]), grip_main_static * ((1 + thruster_array[i].toward_vec.dot(poise_pos)) * thruster_array[i].thrust_vec)))

	return ret_arr

func sum_thrust(thrust : Array, th1 : th, th2 : th):
	return thrust[th1].dot(thruster_array[th1].thrust_vec) + thrust[th2].dot(thruster_array[th2].thrust_vec)
	
func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_F1) and debug == true:
		transform.origin = Vector3.UP
		transform.basis = Basis.FLIP_Z

func _physics_process(_delta: float) -> void:
	# Calculate thrust from each
	var thrust_demand = calc_applied_thrust()
	var thrust = calc_actual_thrust(thrust_demand)
	
	# Calculate linear acceleration
	acc_vec = Vector3.ZERO
	for i in 10:
		acc_vec += thrust[i]
	
	# Factor drag into linear acceleration
	#var lat_drag = sign(vel_vec.x) * min(abs(vel_vec.x * drag_airframe), max_drag_decel, abs(vel_vec.x))
	#var vrt_drag = sign(vel_vec.y) * min(abs(vel_vec.y * drag_airframe), max_drag_decel, abs(vel_vec.y))
	#var lon_drag = sign(vel_vec.z) * min(abs(vel_vec.z * drag_airframe), max_drag_decel, abs(vel_vec.z))
	#acc_vec = acc_vec + Vector3(lat_drag, vrt_drag, lon_drag)

	# Yaw
	var yaw_amount_main = thrust[th.main_lt].dot(thruster_array[th.main_lt].thrust_vec) - thrust[th.main_rt].dot(thruster_array[th.main_rt].thrust_vec)
	var yaw_amount_lat = sum_thrust(thrust, th.lat_fr_up, th.lat_fr_lw) - sum_thrust(thrust, th.lat_rr_up, th.lat_rr_lw)
	rotate_object_local(Vector3.UP, thrust_yaw * (yaw_amount_main + yaw_amount_lat))
	# Pitch
	var pitch_amount_fr = sum_thrust(thrust, th.vrt_fr_lt, th.vrt_fr_rt)
	var pitch_amount_rr = sum_thrust(thrust, th.vrt_rr_lt, th.vrt_rr_rt)
	rotate_object_local(Vector3.RIGHT, -thrust_pitch * (pitch_amount_rr - pitch_amount_fr))
	# Roll
	var roll_amount_vrt = sum_thrust(thrust, th.vrt_fr_lt, th.vrt_rr_lt) - sum_thrust(thrust, th.vrt_fr_rt, th.vrt_rr_rt)
	var roll_amount_lat = sum_thrust(thrust, th.lat_fr_up, th.lat_rr_up) - sum_thrust(thrust, th.lat_fr_lw, th.lat_rr_lw)
	rotate_object_local(Vector3.FORWARD, thrust_roll * (roll_amount_vrt + roll_amount_lat))

	transform = transform.orthonormalized()

	var prev_thr_vel_vec = thr_vel_vec
	thr_vel_vec += acc_vec
	# Clamp linear thruster velocity
	thr_vel_vec.x = clamp(thr_vel_vec.x, -max_spd, max_spd)
	thr_vel_vec.y = clamp(thr_vel_vec.y, -max_spd, max_spd)
	thr_vel_vec.z = clamp(thr_vel_vec.z, -max_spd, max_spd)
	if (vel_vec - transform.basis * thr_vel_vec).length() < grip_main_static or sign(vel_vec - thr_vel_vec) != sign(vel_vec - prev_thr_vel_vec):
		vel_vec = transform.basis * thr_vel_vec
	else:
		vel_vec += grip_main_static * sliding_grip_coef * (transform.basis * acc_vec)
	# Clamp linear velocity
	vel_vec.x = clamp(vel_vec.x, -max_spd, max_spd)
	vel_vec.y = clamp(vel_vec.y, -max_spd, max_spd)
	vel_vec.z = clamp(vel_vec.z, -max_spd, max_spd)
	
	if lat_demand == 0 and vrt_demand == 0 and lon_demand == 0:
		vel_vec = vel_vec.lerp(Vector3.ZERO, 0.05)
	
	# Assign camera position
	var cam = get_node("../Camera3D")
	if cam != null:
		# Camera vector interpolation
		var cam_y_vec = cam_prev_y.lerp(transform.basis.y, 0.1)
		var cam_z_vec = cam_prev_z.lerp(Vector3.BACK if abs(transform.basis.z.dot(Vector3.UP)) == 1 else lerp(-vel_vec, transform.basis.z, 0.99), 0.1)
		cam_prev_y = cam_y_vec
		cam_prev_z = cam_z_vec
		
		# Set camera position
		cam_z_vec = 6 * cam_z_vec.normalized()
		cam.transform.origin = transform.origin + cam_z_vec + cam_y_vec
		
		# Define camera basis
		cam.transform.basis.z = (-(transform.origin - cam.transform.origin)).normalized()
		#if abs(transform.basis.z.dot(Vector3.UP)) > 0.86:
			#var alpha = 0.5 * sqrt(pow(cam.transform.basis.z.x, 2) + pow(cam.transform.basis.z.z, 2))
			#cam.transform.basis.z = Vector3(cam.transform.basis.z.x * alpha, -sign(cam.transform.basis.z.y) * sqrt(3)/2, cam.transform.basis.z.z)
		cam.transform.basis.x = cam.transform.basis.z.cross(Vector3.UP)
		cam.transform.basis.y = cam.transform.basis.x.cross(cam.transform.basis.z)
	
	# Calculate poise
	#poise_acc = acc_vec - poise_damping * poise_vel - poise_spring_const * poise_pos
	#poise_vel += poise_acc
	#poise_pos += poise_vel
	#poise_pos = poise_pos.normalized()

	# Move actor
	velocity = vel_vec
	move_and_slide()

	# Clear demand values
	lon_demand = 0
	vrt_demand = 0
	lat_demand = 0
	pitch_demand = 0
	roll_demand = 0
	yaw_demand = 0
