extends Label

func _process(delta: float) -> void:
	var vel_vec = $"../../ZealousJay".vel_vec
	var eng_lvl = $"../../ZealousJay".clutch_lvl
	var poi_lvl = $"../../ZealousJay".poiser_lvl
	var drv_lvl = $"../../ZealousJay".drive_lvl
	var arm_lvl = $"../../ZealousJay".deflector_lvl
	var health = $"../../ZealousJay".health
	text = "Velocity vector: %s \nSpeed: %s\nClutch level: %s\nPoiser level: %s\n\
		Drive level: %s\nDeflector level: %s" % [vel_vec, vel_vec.length(), eng_lvl, poi_lvl, drv_lvl, arm_lvl]
