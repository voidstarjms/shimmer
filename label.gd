extends Label

func _process(delta: float) -> void:
	var vel_vec = $"../../shimwing_abstract".vel_vec
	var eng_lvl = $"../../shimwing_abstract".engine_lvl
	var poi_lvl = $"../../shimwing_abstract".poiser_lvl
	text = "Velocity vector: %s \nSpeed: %s\nEngine level: %s\nPoiser level: %s" % [vel_vec, vel_vec.length(), eng_lvl, poi_lvl]
