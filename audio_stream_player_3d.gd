extends AudioStreamPlayer3D

func _process(delta: float) -> void:
	pitch_scale = 1 + 2 * ($"..".vel_vec.length() / $"..".max_spd_base)
