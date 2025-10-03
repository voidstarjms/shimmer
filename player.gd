extends Node3D

func _process(delta: float) -> void:
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
