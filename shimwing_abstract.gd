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
	var particle_source : GPUParticles3D
	
	func _init(thrust, toward, axis):
		thrust_vec = thrust
		toward_vec = toward
		varying_axis = axis
		particle_source = GPUParticles3D.new()
		particle_source.emitting = false
		particle_source.fixed_fps = 60

var thruster_array = null

# Axis demand
var lon_demand = 0
var vrt_demand = 0
var lat_demand = 0
var pitch_demand = 0
var roll_demand = 0
var yaw_demand = 0

# Equipment levels
const engine_max_lvl = 19
const poiser_max_lvl = 19
@export var engine_lvl : int
@export var poiser_lvl : int
# Equipment stat upgrade base values
const max_spd_base = 24
const main_thrust_base = 0.2
const vrt_thrust_base = 0.06
const lat_thrust_base = 0.06
const thrust_pitch_base = 0.06
const thrust_roll_base = 0.06
const thrust_yaw_base = 0.06
const poise_spring_const_base = 0.0875
const poise_damping_base = 0.05
# Equipment stat upgrade steps
const max_spd_step = 1
const main_thrust_step = 0.005
const strafe_thrust_step = 0.002
const rotation_thrust_step = 0.001
const poise_spring_const_step = 0.0059
const poise_damping_step = 0.0025

const dash_max_spd_multiplier = 2
const dash_acc_multiplier = 2

# Physics handling scalars
var max_spd

# Physics vectors
var vel_vec = Vector3.ZERO
var acc_vec = Vector3.ZERO

# Thrust values
var main_thrust
var vrt_thrust
var lat_thrust
var thrust_pitch
var thrust_roll
var thrust_yaw

# Drag values
@export var max_drag_decel : float

# Poise scalars
var poise_spring_const
var poise_damping

# Poise vectors
var poise_pos = Vector3.ZERO
var poise_vel = Vector3.ZERO
var poise_acc = Vector3.ZERO

const dash_duration = 60
var dash_counter = 0.0

@export var max_health : int
var health

var inactionable_timer = 0
func set_inactionable_timer(time : int) -> void:
	inactionable_timer = time
func actionable() -> bool:
	return inactionable_timer == 0

func compute_handling_stats():
	max_spd = max_spd_base + max_spd_step * engine_lvl
	main_thrust = main_thrust_base + main_thrust_step * engine_lvl
	vrt_thrust = vrt_thrust_base + strafe_thrust_step * engine_lvl
	lat_thrust = lat_thrust_base + strafe_thrust_step * engine_lvl
	thrust_pitch = thrust_pitch_base + rotation_thrust_step * engine_lvl
	thrust_roll = thrust_roll_base + rotation_thrust_step * engine_lvl
	thrust_yaw = thrust_yaw_base + rotation_thrust_step * engine_lvl
	poise_spring_const = poise_spring_const_base + poise_spring_const_step * poiser_lvl
	poise_damping = poise_damping_base + poise_damping_step * poiser_lvl

func _ready() -> void:
	compute_handling_stats()
	
	var th_arr = Array()
	
	var th_vec_arr = [Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0)]
	var tow_vec_arr = [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, -1), Vector3(0, -1, -1), Vector3(0, 1, 1), Vector3(0, -1, 1)]
	
	# Main thrusters
	for i in 2:
		th_arr.append(thruster.new(th_vec_arr[i].normalized(), tow_vec_arr[i].normalized(), ax.lon))
	# Vertical thrusters
	for i in range(2, 6):
		th_arr.append(thruster.new(th_vec_arr[i].normalized(), tow_vec_arr[i].normalized(), ax.vrt))
	# Lateral thrusters
	for i in range(6, 10):
		th_arr.append(thruster.new(th_vec_arr[i].normalized(), tow_vec_arr[i].normalized(), ax.lat))
	
	thruster_array = th_arr
	
	transform.basis = Basis.FLIP_Z
	
	health = max_health

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

# Dash mutator
func dash():
	if dash_counter == 0:
		dash_counter = dash_duration

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
		ret_arr.append(main_thrust * arr[i] * (1 + thruster_array[i].toward_vec.dot(poise_pos)) * thruster_array[i].thrust_vec)
	# Vertical thruster thrust
	for i in range(2, 6):
		ret_arr.append(vrt_thrust * arr[i] * (1 + thruster_array[i].toward_vec.dot(poise_pos)) * thruster_array[i].thrust_vec)
	# Lateral thruster thrust
	for i in range(6, 10):
		ret_arr.append(lat_thrust * arr[i] * (1 + thruster_array[i].toward_vec.dot(poise_pos)) * thruster_array[i].thrust_vec)

	return ret_arr

func sum_thrust(thrust : Array, th1 : th, th2 : th):
	return thrust[th1].dot(thruster_array[th1].thrust_vec) + thrust[th2].dot(thruster_array[th2].thrust_vec)

func take_damage(amount : int):
	health -= amount

func _physics_process(_delta: float) -> void:
	# Calculate thrust from each
	var thrust_demand = calc_applied_thrust()
	var thrust = calc_actual_thrust(thrust_demand)
	
	# Calculate linear acceleration
	acc_vec = Vector3.ZERO
	for i in 10:
		# Apply equal and doubled forward acceleration if dashing
		if dash_counter > 0 and (i == th.main_lt or i == th.main_rt):
			acc_vec += dash_acc_multiplier * main_thrust * thruster_array[i].thrust_vec
		acc_vec += thrust[i]
	acc_vec *= Engine.time_scale

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
	
	# Accelerate craft, taking max speed into account
	var prev_vel_vec = vel_vec
	var actual_max_speed = max_spd * (dash_max_spd_multiplier if dash_counter > 0 else 1)
	var acc_transformed = transform.basis * acc_vec
	if abs(vel_vec.x) > actual_max_speed:
		vel_vec.x -= max_drag_decel * sign(vel_vec.x) * Engine.time_scale
	else:
		vel_vec.x += acc_transformed.x * Engine.time_scale
	if abs(vel_vec.y) > actual_max_speed:
		vel_vec.y -= max_drag_decel * sign(vel_vec.y) * Engine.time_scale
	else:
		vel_vec.y += acc_transformed.y * Engine.time_scale
	if abs(vel_vec.z) > actual_max_speed:
		vel_vec.z -= max_drag_decel * sign(vel_vec.z) * Engine.time_scale
	else:
		vel_vec.z += acc_transformed.z * Engine.time_scale

	# Decrement dash time counter
	if dash_counter > 0:
		dash_counter -= Engine.time_scale
	
	# Apply deceleration
	if lat_demand == 0 and vrt_demand == 0 and lon_demand == 0 and dash_counter == 0:
		vel_vec = vel_vec - max_drag_decel * vel_vec.normalized()  * Engine.time_scale
		if sign(prev_vel_vec.x) != sign(vel_vec.x):
			vel_vec.x = 0
		if sign(prev_vel_vec.y) != sign(vel_vec.y):
			vel_vec.y = 0
		if sign(prev_vel_vec.z) != sign(vel_vec.z):
			vel_vec.z = 0
	
	## Calculate poise
	# Calculate undamped poise acceleration
	var poise_acc_undamped = 0.01 / poise_spring_const * (vel_vec - prev_vel_vec) - poise_spring_const * poise_pos
	# Apply damping and zero if needed
	poise_acc = poise_acc_undamped - poise_damping * poise_vel
	if sign(poise_acc.x) != sign(poise_acc_undamped.x):
		poise_acc.x = 0
	if sign(poise_acc.y) != sign(poise_acc_undamped.y):
		poise_acc.y = 0
	if sign(poise_acc.z) != sign(poise_acc_undamped.z):
		poise_acc.z = 0
	# Integrate velocity and position
	poise_vel += poise_acc * Engine.time_scale
	poise_pos += poise_vel * Engine.time_scale
	# Clamp poise position
	if abs(poise_pos.x) > 1:
		poise_pos.x = sign(poise_pos.x)
		poise_vel.x = 0
	if abs(poise_pos.y) > 1:
		poise_pos.y = sign(poise_pos.y)
		poise_vel.y = 0
	if abs(poise_pos.z) > 1:
		poise_pos.z = sign(poise_pos.z)
		poise_vel.z = 0

	# Move actor and collide
	var collision = move_and_collide(vel_vec * _delta)
	if collision:
		var collision_normal = collision.get_normal()
		var vel_dot_normal = vel_vec.normalized().dot(collision_normal)
		if vel_dot_normal < 0:
			# Inflict crash damage based on angle of impact
			take_damage(floor(-4 * vel_dot_normal * vel_vec.project(collision_normal).length()))
			vel_vec = vel_vec.slide(collision_normal)
			if vel_vec != Vector3.ZERO:
				transform.basis = Basis.looking_at(lerp(-transform.basis.z,
					-transform.basis.z.slide(collision_normal), 0.05), transform.basis.y)
				# Why is this necessary?
				transform.basis.x *= -1

	# Clear demand values
	lon_demand = 0
	vrt_demand = 0
	lat_demand = 0
	pitch_demand = 0
	roll_demand = 0
	yaw_demand = 0
	
	# Decrement inactionable timer
	if inactionable_timer > 0:
		inactionable_timer -= Engine.time_scale
