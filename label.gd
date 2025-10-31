extends Label

func _process(delta: float) -> void:
	var vel_vec = $"../../ZealousJay".vel_vec
	var eng_lvl = $"../../ZealousJay".engine_lvl
	var poi_lvl = $"../../ZealousJay".poiser_lvl
	text = "Velocity vector: %s \nSpeed: %s\nEngine level: %s\nPoiser level: %s" % [vel_vec, vel_vec.length(), eng_lvl, poi_lvl]
