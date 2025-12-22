extends AudioStreamPlayer3D

func _process(delta: float) -> void:
	var vel_vec = abs($"..".vel_vec)
	var max_vel_component = max(vel_vec.x, vel_vec.y, vel_vec.z)
	pitch_scale = 1 + 2 * (max_vel_component / $"..".max_spd_base)
