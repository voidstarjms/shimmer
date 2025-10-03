extends AudioStreamPlayer3D

func _process(delta: float) -> void:
	pitch_scale = 1 + 2 * ($"..".thr_vel_vec.length() / $"..".max_spd)
