extends Label

func _process(delta: float) -> void:
	var rel_spd = $"../../shimwing_abstract".rel_spd
	var acc_vec = $"../../shimwing_abstract".acc_vec
	var acc_transformed = $"../../shimwing_abstract".transform.basis * acc_vec
	#text = "%f %f %f" % [rel_spd.x, rel_spd.y, rel_spd.z]
	text = "%s %s %s" % [acc_vec.x == acc_transformed.x, acc_vec.y == acc_transformed.y, acc_vec.z == acc_transformed.z]
