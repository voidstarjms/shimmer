extends Label

func _process(delta: float) -> void:
	var vel_vec = $"../../shimwing_abstract".vel_vec
	#text = "%f %f %f" % [rel_spd.x, rel_spd.y, rel_spd.z]
	text = "%s" % [vel_vec]
	#text = "%s %s %s" % [vel_vec.x == thr_vec.x, vel_vec.y == thr_vec.y, vel_vec.z == thr_vec.z]
