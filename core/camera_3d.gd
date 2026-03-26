extends Camera3D

var cam_prev_y = Vector3.UP
var cam_prev_z = Vector3.BACK
var prev_screenshake_offset = Vector2.ZERO
var tracking_position = Vector3.ZERO
var tracking_basis = Basis.IDENTITY
var tracking_velocity = Vector3.ZERO
var screenshake_jitter = 0
var shake_position = 0
const screenshake_jit_decay = 0.01
const screenshake_wavelength = 2 * TAU

func screenshake_set_jitter(j : float):
	screenshake_jitter = j

func screenshake_step(delta):
	screenshake_jitter = max(screenshake_jitter - screenshake_jit_decay, 0)
	shake_position += delta * screenshake_wavelength
	shake_position = fmod(shake_position, TAU)

func set_tracking_transform(t : Transform3D):
	tracking_position = t.origin
	tracking_basis = t.basis

func set_tracking_velocity(vel : Vector3):
	tracking_velocity = vel

func _physics_process(delta: float) -> void:
	# Camera vector interpolation
	var cam_y_vec = cam_prev_y.lerp(tracking_basis.y, 0.1)
	var cam_z_vec = cam_prev_z.lerp(Vector3.BACK if abs(tracking_basis.z.dot(Vector3.UP)) == 1 else lerp(-tracking_velocity, tracking_basis.z, 1), 0.1)
	cam_prev_z = cam_z_vec
	cam_prev_y = cam_y_vec
	
	# Set camera base position
	cam_z_vec = 6 * cam_z_vec.normalized()
	transform.origin = tracking_position + cam_z_vec + cam_y_vec
	
	# Add screenshake
	screenshake_step(delta)
	var screenshake_offset = screenshake_jitter * Vector2.RIGHT.rotated(randf_range(0, TAU))
	screenshake_offset = lerp(prev_screenshake_offset, screenshake_offset, 0.2)
	prev_screenshake_offset = screenshake_offset
	transform.origin += transform.basis.x * screenshake_offset.x + transform.basis.y * screenshake_offset.y
	
	# Define camera basis
	#if abs(transform.basis.z.dot(Vector3.UP)) < 0.86:
	transform.basis.z = (transform.origin - tracking_position).normalized()#(-($"..".transform.origin - cam.transform.origin)).normalized()
	transform.basis.x = transform.basis.z.cross(Vector3.UP)
	transform.basis.y = transform.basis.x.cross(transform.basis.z)
