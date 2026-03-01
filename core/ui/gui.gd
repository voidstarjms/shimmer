extends Control

const pi_over_6 = PI / 6
const pi_over_4 = PI / 4
const pi_over_2 = PI / 2
const sqrt2_over_2 = sqrt(2) / 2
const compass_rose = ["N", "E", "S", "W"]
const UI_font_path = "res://CONSOLA.TTF"

var pitch_ladder : PitchLadder
#var heading_indicator : HeadingGauge
var speed_tape : TapeGauge
var speed_box : NumberBox
var altimeter_tape : TapeGauge
var altimeter_box : NumberBox
var speed_tape_labels : Array[Label]
var health_bar : BarGauge
var heading_number : NumberBox
var lat_vel_gauge : SlidingArrowGauge
var vrt_vel_gauge : SlidingArrowGauge

var gui_color = Color.GREEN
var warning_color = Color.RED

class TextScalable extends Node:
	var label_list
	var base_label_size
	var base_font_size
	
	func resize_text(view_rect : Rect2):
		for i in label_list:
			var scale = view_rect.size.x / base_label_size.x
			var scaled_size : int = floor(base_font_size * scale)
			
			if scaled_size > 4096:
				continue
			
			i.add_theme_font_size_override("font_size", scaled_size)
			i.add_theme_font_size_override("normal_font_size", scaled_size)

class PitchLadder extends TextScalable:
	var position
	var size
	var level_mark_inner_width# = 0.164
	var level_mark_len
	var level_mark_margin
	var rung_outer_width# = 0.16
	var rung_inner_width# = 0.12
	var rung_length
	var max_vert# = 0.375
	var rung_spacing
	var max_visible_rungs
	var gap_value
	
	func _init(pos : Vector2, sz : Vector2, lvl_len : float, lvl_margin : float, rung_len : float, rung_spc : float, gap_val : int, view_rect : Rect2) -> void:
		position = pos
		size = sz
		level_mark_len = lvl_len
		level_mark_margin = lvl_margin
		rung_length = rung_len
		rung_outer_width = size.x / 2 - level_mark_len - lvl_margin
		rung_inner_width = rung_outer_width - rung_len
		max_vert = size.y / 2
		rung_spacing = rung_spc
		max_visible_rungs = int(1 / rung_spacing)
		gap_value = gap_val
		
		# Initialize pitch marker text
		label_list = Array()
		var font = load(UI_font_path)
		for i in max_visible_rungs:
			var label = Label.new()
			label.add_theme_font_override("font", font)
			label_list.append(label)
			self.add_child(label)
		base_label_size = view_rect.size
		base_font_size = label_list[0].get_theme_font_size("font_size")
	
	func set_label_color(c : Color):
		for i in label_list:
			i.set("theme_override_colors/font_color", c)
	
	func construct_ladder_array(view_rect : Rect2, raw_fwd : Vector3):
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		var sx = size.x * wx
		var sy = size.y * wy
		var px = position.x * wx
		var py = position.y * wy
		
		var ret_arr = Array()
		
		# Append level marks
		var level_mark_left = [Vector2(px, py + sy / 2),
			Vector2(px + wx * level_mark_len, py + sy / 2)]
		var level_mark_right = [Vector2(px + sx, py + sy / 2),
			Vector2(px + sx - wx * level_mark_len, py + sy / 2)]
		ret_arr.append([level_mark_left, level_mark_right])
		
		var center = Vector2(px + sx / 2, py + sy / 2)
		
		for i in label_list:
			i.visible = false
		# Append rungs
		var pitch_angle = rad_to_deg(pi_over_2 - acos(raw_fwd.dot(Vector3.UP)))
		var base_rung_angle
		if sign(pitch_angle) >= 0: 
			base_rung_angle = floor((pitch_angle + (gap_value * max_visible_rungs) / 2) / gap_value) * gap_value
		else:
			base_rung_angle = ceil((pitch_angle + (gap_value * max_visible_rungs) / 2) / gap_value) * gap_value
		var rung_vrt_gap_modulo = fmod(pitch_angle, gap_value)
		var rung_vrt_offset = -1000
		for rung_ix in max_visible_rungs:
			rung_vrt_offset = (-(int(max_visible_rungs / 2)) + rung_ix + rung_vrt_gap_modulo / gap_value) * rung_spacing
			var snapped_rung_angle = int(base_rung_angle - gap_value * rung_ix)
			var rung_angle = snapped_rung_angle - rung_vrt_gap_modulo
			# Cull rung if angle is out of bounds
			if rung_angle > 90 or rung_vrt_offset < -max_vert:
				continue
			if rung_angle < -90 or rung_vrt_offset > max_vert:
				break
			var rung_vrt_vec = Vector2.UP * rung_vrt_offset * wy
			
			var rung_outer_vec = rung_outer_width * wx * Vector2.RIGHT
			var rung_inner_vec = rung_inner_width * wx * Vector2.RIGHT
			label_list[rung_ix].visible = true
			label_list[rung_ix].text = str(snapped_rung_angle)
			label_list[rung_ix].position = center - rung_outer_vec - rung_vrt_vec
			
			var rung_left = [center - rung_outer_vec - rung_vrt_vec, center - rung_inner_vec - rung_vrt_vec]
			var rung_right = [center + rung_outer_vec - rung_vrt_vec, center + rung_inner_vec - rung_vrt_vec]
			ret_arr.append([rung_left, rung_right])
		
		return ret_arr

class HeadingGauge extends TextScalable:
	var pos : Vector2 # Fraction of screen size
	var sz : Vector2 # Fraction of screen size
	var marker_distance # Fraction of object size
	var subdivision_count
	var marker_frequency
	var angle_marker_increment
	var label_distance
	var visible_labels
	var invisible_labels
	var angle_divisor
	var prev_angle = 0
	
	func _init(p : Vector2, s : Vector2, mark_dist : float, subdiv_count : int, marker_freq : int, color : Color, view_rect : Rect2):
		pos = p
		sz = s
		marker_distance = mark_dist
		subdivision_count = subdiv_count
		marker_frequency = marker_freq
		angle_marker_increment = int(90.0 / subdivision_count * marker_freq)
		base_font_size = 1
		label_distance = marker_distance * marker_frequency
		angle_divisor = marker_frequency * (sz.x) / marker_distance
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		var px = wx * p.x
		var py = wy * p.y
		var sx = wx * s.x
		var sy = wy * s.y
		var center = px + sx / 2
		
		label_list = Array()
		visible_labels = Array()
		invisible_labels = Array()
		var font = load(UI_font_path)
		var leftmost_label_x = center - (floor(sz.x / label_distance) - 1) * label_distance * sx
		var leftmost_label_val = -(floor(sz.x / label_distance) - 1) * angle_marker_increment
		for i in int(ceil(1 / label_distance) + 1):
			var label = Label.new()
			label.position = Vector2(leftmost_label_x + i * label_distance * sx, py + sy)
			if label.position.x > px + sx:
				label.visible = false
				invisible_labels.append(label)
			else:
				visible_labels.append(label)
			label.text = str(int(fposmod(leftmost_label_val + i * angle_marker_increment, 360)))
			label.theme = Theme.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			label.add_theme_font_override("font", font)
			label.set("theme_override_colors/font_color", color)
			label_list.append(label)
			add_child(label)
		base_label_size = view_rect.size
		base_font_size = label_list[0].get_theme_font_size("font_size")
	
	func construct(fwd_vec : Vector3, view_rect : Rect2):
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		var px = pos.x * wx
		var py = pos.y * wy
		var sx = sz.x * wx
		var sy = sz.y * wy
		var ret_arr = Array()
		var heading_vec = Vector3(fwd_vec.x, 0, fwd_vec.z).normalized()
		var heading_angle = Vector3.BACK.signed_angle_to(heading_vec, Vector3.DOWN)
		if heading_angle < 0:
			heading_angle += TAU
		if heading_angle > TAU:
			heading_angle -= TAU
		var clamped_heading_angle = fmod(heading_angle / angle_divisor, pi_over_2 / angle_divisor)
		var clamped_heading_vec = Vector3.BACK.rotated(Vector3.DOWN, clamped_heading_angle)
		var center = px + sx / 2
		
		#for i in label_list:
			#i.visible = false
		for i in 2 * subdivision_count:
			var marker_vec = Vector3.BACK.rotated(Vector3.UP, i * pi_over_4 / subdivision_count - pi_over_4)
			var marker_angle = marker_vec.signed_angle_to(clamped_heading_vec, Vector3.DOWN)
			var marker_horiz_offset = Vector2.RIGHT * sx / 2 * marker_distance * marker_angle * 90.0 / subdivision_count
			if marker_horiz_offset.x > sx / 2:
				break
			if marker_horiz_offset.x < -sx / 2:
				continue
			
			ret_arr.append([Vector2(wx / 2, py) + marker_horiz_offset, Vector2(wx / 2, py + sy) + marker_horiz_offset])
		
		var label_pos_change = (heading_angle - fmod(prev_angle, TAU)) * label_distance * sx / 2 * (1 / (marker_frequency * label_distance))
		
		var visible_label_ix = 0
		while visible_label_ix < len(visible_labels):
			var label = visible_labels[visible_label_ix]
			label.position.x += label_pos_change
			if label.position.x < px or label.position.x > px + sx:
				invisible_labels.append(visible_labels.pop_at(visible_label_ix))
				label.visible = false
			else:
				visible_label_ix += 1
		
		if visible_labels[0].position.x - label_distance * sx > px:
			var new_label = invisible_labels.pop_back()
			new_label.visible = true
			new_label.text = str(int(fposmod(float(visible_labels[0].text) - angle_marker_increment, 360)))
			new_label.position = Vector2(visible_labels[0].position.x - label_distance * sx, py + sy)
			visible_labels.push_front(new_label)
		var rightmost_label = visible_labels[len(visible_labels) - 1]
		if rightmost_label.position.x + label_distance * sx < px + sx:
			var new_label = invisible_labels.pop_back()
			new_label.visible = true
			new_label.text = str(int(fposmod(float(rightmost_label.text) + angle_marker_increment, 360)))
			new_label.position = Vector2(rightmost_label.position.x + label_distance * sx, py + sy)
			visible_labels.push_back(new_label)
			
		prev_angle = heading_angle
		
		return ret_arr

class TapeGauge extends TextScalable:
	var pos : Vector2 # Fraction of screen size
	var sz : Vector2 # Fraction of screen size
	var max_value : int
	var major_tick_freq : int
	var minor_tick_gap : float # Fraction of tape height
	var minor_tick_sz : float # Fraction of major tick width
	var gap_value : int # The value interval between major ticks
	var nve_allowed : bool
	var value_box_pos : float
	var value_box_height : float
	var value_span : float
	var tape_value_offset : float
	
	func _init(p : Vector2, s : Vector2, max_val : int, division : Vector2, minor_sz : float, gap_val : int, nve : bool, color : Color, view_rect : Rect2):
		pos = p
		sz = s
		max_value = max_val
		major_tick_freq = int(division.x)
		minor_tick_gap = division.y
		minor_tick_sz = minor_sz
		gap_value = gap_val
		nve_allowed = nve
		var minor_tick_count = int(1.0 / minor_tick_gap)
		var major_tick_count = int(minor_tick_count / major_tick_freq)
		label_list = Array()
		var font = load(UI_font_path)
		for i in major_tick_count + 1:
			var label : Label = Label.new()
			label.add_theme_font_override("font", font)
			label.add_theme_color_override("font_color", color)
			label_list.append(label)
			add_child(label)
		base_label_size = view_rect.size
		base_font_size = label_list[0].get_theme_font_size("font_size")
		## TESTING get exact glyph sizes
		#var font_id : RID = label_list[0].get_theme_font("font").get_rid()
		#var ts = TextServerManager.get_primary_interface()
		#var glyph_ix = ts.font_get_glyph_index(font_id, base_font_size, "0".unicode_at(0), 0)
		#print(ts.font_get_glyph_size(font_id, Vector2i(base_font_size, base_font_size), glyph_ix))
		
		# Default value box params
		init_display_gap()
	
	func init_display_gap(p : float = 0.0, height : float = 0.0):
		value_box_pos = p
		value_box_height = height
	
	func get_display_box(view_rect : Rect2) -> Rect2:
		if value_box_height == 0:
			return Rect2()
		
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		var box_pos = Vector2(pos.x * wx, (pos.y + value_box_pos) * wy)
		var box_sz = Vector2(sz.x, value_box_height)
		return Rect2(box_pos, box_sz)
	
	func set_tape_offset(offset : float):
		tape_value_offset = offset
	
	func construct(left : bool, metered_value : float, view_rect : Rect2):
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		
		# Derive measurements
		var tape_width = wx * sz.x
		var tape_height = wy * sz.y
		var tick_count = int(1.0 / minor_tick_gap)
		var tick_gap_absolute = minor_tick_gap * tape_height
		var x_absolute = pos.x * wx
		var y_absolute = pos.y * wy
		metered_value = clamp(metered_value, -max_value, max_value)
		
		for i in label_list:
			i.visible = false
		
		var meter_capacity = (1.0 / minor_tick_gap) * gap_value / major_tick_freq
		var absolute_offset = meter_capacity * tape_value_offset
		metered_value -= absolute_offset
		var base_major_tick_value = ceil(metered_value / gap_value) * gap_value
		if nve_allowed == false:
			base_major_tick_value = max(base_major_tick_value, 0)
		var major_tick_index = 0
		var mark_arr = Array()
		for i in range(-major_tick_freq, tick_count + major_tick_freq):
			# Compute mark offset, cull if out of bounds
			if nve_allowed == false:
				metered_value = max(0, metered_value)
			var unmetered_value_offset = tick_gap_absolute * major_tick_freq / gap_value * metered_value
			var value_offset = fmod(unmetered_value_offset, tick_gap_absolute * major_tick_freq)
			var tick_offset = tick_gap_absolute * i - value_offset
			if tick_offset < 0 or tick_offset > tape_height:
				continue
			var is_major_tick = i % major_tick_freq == 0
			var tick_offset_relative = tick_offset / tape_height
			if tick_offset_relative >= value_box_pos and tick_offset_relative <= value_box_pos + value_box_height:
				if is_major_tick == true:
					major_tick_index += 1
				continue
			
			var tick_width = tape_width
			if is_major_tick == false:
				tick_width *= minor_tick_sz
			
			# Compute tick mark vertices
			var tick_start
			var tick_end
			var label_position
			var font_size = label_list[0].get_theme_font_size("font_size")
			if left == true:
				tick_start = Vector2(x_absolute, y_absolute + tape_height - tick_offset)
				tick_end = Vector2(x_absolute + tick_width, y_absolute + tape_height - tick_offset)
				
				label_position = tick_end - Vector2(0, font_size)
			else:
				tick_start = Vector2(x_absolute + tape_width - tick_width, y_absolute + tape_height - tick_offset)
				tick_end = Vector2(x_absolute + tape_width, y_absolute + tape_height - tick_offset)
				label_position = tick_start - Vector2(font_size, font_size)
			
			if is_major_tick == true:
				if label_position.y > (pos.y + (value_box_pos + value_box_height) * sz.y) * wy or label_position.y + font_size < (pos.y + value_box_pos * sz.y) * wy:
					label_list[major_tick_index].visible = true
					var label_text = str(int(base_major_tick_value + gap_value * major_tick_index))
					label_list[major_tick_index].text = label_text
					if !left:
						label_position.x -= (label_text.length() - 1) * font_size / 2
					label_list[major_tick_index].position = label_position
				major_tick_index += 1
			
			mark_arr.append([tick_start, tick_end])
		
		return mark_arr

class NumberBox extends TextScalable:
	var pos : Vector2
	var sz : Vector2
	
	func _init(p : Vector2, s : Vector2, label_color : Color, view_rect : Rect2):
		label_list = Array()
		pos = p
		sz = s
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		var pos_absolute = Vector2(wx * pos.x, wy * pos.y)
		var label = Label.new()
		label.add_theme_font_override("font", load(UI_font_path))
		label.add_theme_color_override("font_color", label_color)
		label.add_theme_font_size_override("font_size", int(sz.y * wy))
		label.position = pos_absolute
		label.text = "0"
		base_label_size = view_rect.size
		base_font_size = label.get_theme_font_size("font_size")
		label_list.append(label)
		add_child(label)
	
	func construct(view_rect : Rect2):
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		var pos_absolute = Vector2(wx * pos.x, wy * pos.y)
		label_list[0].position = pos_absolute
		return Rect2(Vector2(pos.x * wx, pos.y * wy), Vector2(sz.x * wx, sz.y * wy))
	
	func set_value(val : int):
		label_list[0].text = str(val)

class BarGauge:
	var pos : Vector2 # Fraction of screen size
	var sz : Vector2 # Fraction of screen size
	var lo_color : Color
	var hi_color : Color
	var value : int
	var max_value : int
	var bar1_display_value : int
	var bar2_display_value : int
	var bezel_margin : float # Fraction of screen size
	var bezel_color : Color # Any color with alpha = 0 indicates no bezel
	var segment_count : int # 0 indicates to use value-dependent division
	var segment_value : int
	var bar1_increment_rate : int # 0 is instant
	var bar2_increment_rate : int # <= 0 is instant (i.e. no bar2)
	var bar2_color : Color
	var flash_threshold : float # fraction of max_value, 0 means never flash
	var flash_time : int
	var flash_duty : float
	var flash_counter : int
	var flash_observer_list : Array
	
	func _init(position : Vector2, size : Vector2, bar1_colors : Array[Color], max_val : int, inc_rate : int = 0):
		pos = position
		sz = size
		lo_color = bar1_colors[0]
		hi_color = bar1_colors[1]
		max_value = max_val
		value = max_val
		bar1_display_value = max_val
		bar2_display_value = max_val
		bar1_increment_rate = inc_rate
		
		# Default bezel and segment parameters
		set_framing()
		
		# Default bar2 parameters
		set_bar2()
		
		# Default flash parameters
		set_flash()
	
	func set_framing(margin : float = 0, color : Color = Color(0, 0, 0, 0), seg_count : int = 1, seg_value : int = 0):
		bezel_margin = margin
		bezel_color = color
		segment_count = seg_count
		segment_value = seg_value
	
	func set_bar2(inc_rate : int = -1, color : Color = Color(0, 0, 0, 0)):
		bar2_increment_rate = inc_rate
		bar2_color = color
	
	func set_flash(threshold : float = 0, time : int = 0, duty : float = 0.0):
		flash_threshold = threshold
		flash_time = time
		flash_duty = duty
	
	func _make_bar(view_rect : Rect2, val : int) -> Rect2:
		if float(value) / max_value <= flash_threshold and float(flash_counter) / flash_time > flash_duty:
			return Rect2()
		
		val = min(val, max_value)
		
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		var bar_percent = float(val) / max_value
		
		return Rect2(Vector2(pos.x * wx, pos.y * wy),
			Vector2(sz.x * wx * bar_percent, sz.y * wy))
	
	func get_bar1(view_rect : Rect2) -> Rect2:
		return _make_bar(view_rect, bar1_display_value)
	
	func get_bar2(view_rect : Rect2) -> Rect2:
		return _make_bar(view_rect, bar2_display_value)
	
	func get_bar1_color() -> Color:
		return lerp(lo_color, hi_color, float(value) / max_value)
	
	func get_bar2_color() -> Color:
		return bar2_color
	
	func get_bezel_rect(view_rect : Rect2) -> Rect2:
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		var aspect_ratio = wx / wy
		var margin_vec = Vector2(bezel_margin * wx, bezel_margin * wy * aspect_ratio)
		var position = Vector2(pos.x * wx, pos.y * wy)
		var size = Vector2(sz.x * wx, sz.y * wy)
		return Rect2(position - margin_vec, size + 2 * margin_vec)
	
	func get_bezel_color() -> Color:
		return bezel_color
	
	func get_segment_lines(view_rect : Rect2) -> Array:
		var wx = view_rect.size.x
		#var wy = view_rect.size.y
		var segment_list = Array()
		
		if segment_count == 1:
			return segment_list
		var bezel_rect = get_bezel_rect(view_rect)
		var bezel_x = bezel_rect.position.x
		var bezel_y = bezel_rect.position.y
		var bezel_h = bezel_rect.size.y
		if segment_count == 0:
			var i = segment_value
			while i < max_value:
				var seg_x = sz.x + bezel_x + i * wx * sz.x / max_value
				var seg_top = Vector2(seg_x, bezel_y)
				var seg_bot = Vector2(seg_x, bezel_y + bezel_h)
				segment_list.append([seg_top, seg_bot])
				i += segment_value
		else:
			for i in range(1, segment_count):
				var seg_x = sz.x + bezel_x + i * wx * sz.x / segment_count
				var seg_top = Vector2(seg_x, bezel_y)
				var seg_bot = Vector2(seg_x, bezel_y + bezel_h)
				segment_list.append([seg_top, seg_bot])
		
		return segment_list
	
	# Decrement bars if necessary, update flash counter
	func step():
		if float(value) / max_value <= flash_threshold and flash_counter == 0:
			update_observers()
		if flash_time > 0:
			flash_counter = (flash_counter + 1) % flash_time
		
		if bar1_increment_rate == 0:
			bar1_display_value = value
		elif bar1_display_value > value:
			bar1_display_value = max(bar1_display_value - bar1_increment_rate, value)
		elif bar1_display_value < value:
			bar1_display_value = min(bar1_display_value + bar1_increment_rate, value)
		
		if bar2_increment_rate <= 0:
			return
		if bar2_display_value > value:
			bar2_display_value = max(bar2_display_value - bar2_increment_rate, value)
		elif bar2_display_value < value:
			bar2_display_value = min(bar2_display_value + bar2_increment_rate, value)
		return
	
	func set_value(val : int):
		value = max(val, 0)
	
	func set_max_value(val : int):
		max_value = val
	
	func add_observer(obj : Node):
		flash_observer_list.append(obj)
	
	func update_observers():
		for i in flash_observer_list:
			i.update()

class SlidingArrowGauge extends TextScalable:
	var pos
	var sz
	var orientation
	var value = 0
	var max_value
	var subdiv_count
	var arrow_d
	
	func _init(p : Vector2, s : Vector2, orient : int, max_val : int, subdiv : float, arrow_dim : Vector2, label_color : Color, view_rect : Rect2):
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		pos = p
		sz = s
		var px = wx * p.x
		var py = wy * p.y
		var sx = wx * s.x
		var sy = wy * s.y
		
		orientation = orient
		max_value = max_val
		subdiv_count = subdiv
		arrow_d = arrow_dim
		var font = load(UI_font_path)
		label_list = Array()
		
		# Create lower valued label
		var label = RichTextLabel.new()
		label.add_theme_font_override("normal_font", font)
		label.add_theme_color_override("default_color", label_color)
		label.add_theme_font_size_override("normal_font_size", int(sy))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = str(-max_value)
		label.size = Vector2(40,40)
		label_list.append(label)
		add_child(label)
		# Create upper valued label
		label = RichTextLabel.new()
		label.add_theme_font_override("normal_font", font)
		label.add_theme_color_override("default_color", label_color)
		label.add_theme_font_size_override("normal_font_size", 12 * sz.y if orientation % 2 == 0 else 12 * sz.x)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = str(max_value)
		label.size = Vector2(40,40)
		label_list.append(label)
		add_child(label)
		
		base_label_size = view_rect.size
		base_font_size = label.get_theme_font_size("normal_font_size")
	
	func set_max_value(new_value: int):
		max_value = new_value
	
	func construct(view_rect : Rect2):
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		var px = wx * pos.x
		var py = wy * pos.y
		var sx = wx * sz.x
		var sy = wy * sz.y
		
		var ret_arr = Array()
		var ticks = subdiv_count + 2
		match orientation:
			0:
				label_list[0].position = Vector2(px - label_list[0].size.x/2, py + sy)
				label_list[1].position = Vector2(px - label_list[1].size.x/2 + sx, py + sy)
				# TODO this value ordering direction should be more flexible and this code is also repeated
				label_list[0].text = str(-max_value)
				label_list[1].text = str(max_value)
				
				var arrow_offset = sx * (0.5 + value / max_value * 0.5)
				ret_arr.append([[Vector2(px - sx * arrow_d.x + arrow_offset, py - sy * arrow_d.y), Vector2(px + arrow_offset, py)],
					[Vector2(px + arrow_offset, py), Vector2(px + sx * arrow_d.x + arrow_offset, py - sy * arrow_d.y)]])
				for i in ticks + 1:
					var div_frac = i / ticks
					# TODO get rid of these magic numbers and make it more flexible
					var tick_len
					if div_frac == 0 or div_frac == 0.5 or div_frac == 1:
						tick_len = sy
					else:
						tick_len = sy * 0.5
					ret_arr.append([Vector2(px + div_frac * sx, py + sy), Vector2(px + div_frac * sx, py + sy - tick_len)])
			1:
				label_list[0].position = Vector2(px - label_list[0].size.x, py + sy - label_list[0].size.y/2)
				label_list[1].position = Vector2(px - label_list[0].size.x, py - label_list[0].size.y/2)
				label_list[0].text = str(max_value)
				label_list[1].text = str(-max_value)
				
				var arrow_offset = sy * (0.5 + value / max_value * 0.5)
				ret_arr.append([[Vector2(px + sx + sx * arrow_d.y, py + sy - sy * arrow_d.x - arrow_offset), Vector2(px + sx, py + sy - arrow_offset)],
					[Vector2(px + sx, py + sy - arrow_offset), Vector2(px + sx + sx * arrow_d.y, py + sy + sy * arrow_d.x - arrow_offset)]])
				for i in ticks + 1:
					var div_frac = i / ticks
					# TODO get rid of these magic numbers and make it more flexible
					var tick_len
					if div_frac == 0 or div_frac == 0.5 or div_frac == 1:
						tick_len = sx
					else:
						tick_len = sx * 0.5
					ret_arr.append([Vector2(px + sx, py + sy * div_frac), Vector2(px + sx - tick_len, py + sy * div_frac)])
		
		return ret_arr
	
	func set_value(val : float):
		value = clamp(val, -max_value, max_value)

func _on_window_resized():
	var view_rect = get_viewport_rect()
	pitch_ladder.resize_text(view_rect)
	#heading_indicator.resize_text(view_rect)
	speed_tape.resize_text(view_rect)
	altimeter_tape.resize_text(view_rect)
	speed_box.resize_text(view_rect)
	altimeter_box.resize_text(view_rect)
	lat_vel_gauge.resize_text(view_rect)
	vrt_vel_gauge.resize_text(view_rect)

func _ready() -> void:
	var view_rect = get_viewport_rect()
	
	pitch_ladder = PitchLadder.new(Vector2(0.3, 0.225), Vector2(0.4, 0.55), 0.016, 0.004, 0.04, 0.25, 5, view_rect)
	pitch_ladder.set_label_color(gui_color)
	self.add_child(pitch_ladder)
	
	#heading_indicator = HeadingGauge.new(Vector2(0.2, 0.02), Vector2(0.6, 0.03), 0.2, 6, 1, gui_color, view_rect)
	#self.add_child(heading_indicator)
	
	var speed_tape_x = 0.2675
	var speed_tape_y = 0.35
	var speed_tape_w = 0.0125
	var speed_tape_h = 0.3
	var speed_tape_pos = Vector2(speed_tape_x, speed_tape_y)
	var speed_tape_sz = Vector2(speed_tape_w, speed_tape_h)
	var speed_tape_gap_h = 0.1
	var speed_tape_gap_y = 0.5 - speed_tape_gap_h / 2
	speed_tape = TapeGauge.new(speed_tape_pos, speed_tape_sz, 99, Vector2(5, 0.04), 0.5, 5, true, gui_color, view_rect)
	speed_tape.init_display_gap(speed_tape_gap_y, speed_tape_gap_h)
	speed_tape.set_tape_offset(0.5)
	self.add_child(speed_tape)
	
	var speed_box_x = speed_tape_x - 2 * speed_tape_w
	var speed_box_y = speed_tape_y + speed_tape_gap_y * speed_tape_h
	var speed_box_pos = Vector2(speed_box_x, speed_box_y)
	var speed_box_sz = Vector2(3 * speed_tape_w, speed_tape_gap_h * speed_tape_h)
	speed_box = NumberBox.new(speed_box_pos, speed_box_sz, gui_color, view_rect)
	self.add_child(speed_box)
	
	var altimeter_tape_x = 0.72
	var altimeter_tape_y = 0.35
	var altimeter_tape_w = 0.0125
	var altimeter_tape_h = 0.3
	var altimeter_tape_pos = Vector2(altimeter_tape_x, altimeter_tape_y)
	var altimeter_tape_sz = Vector2(altimeter_tape_w, altimeter_tape_h)
	var altimeter_tape_gap_h = 0.1
	var altimeter_tape_gap_y = 0.5 - altimeter_tape_gap_h / 2
	altimeter_tape = TapeGauge.new(altimeter_tape_pos, altimeter_tape_sz, 999, Vector2(5, 0.04), 0.5, 10, false, gui_color, view_rect)
	altimeter_tape.init_display_gap(altimeter_tape_gap_y, altimeter_tape_gap_h)
	altimeter_tape.set_tape_offset(0.5)
	self.add_child(altimeter_tape)
	
	var altimeter_box_x = altimeter_tape_x
	var altimeter_box_y = altimeter_tape_y + altimeter_tape_gap_y * altimeter_tape_h
	var altimeter_box_pos = Vector2(altimeter_box_x, altimeter_box_y)
	var altimeter_box_sz = Vector2(3 * altimeter_tape_w, altimeter_tape_gap_h * altimeter_tape_h)
	altimeter_box = NumberBox.new(altimeter_box_pos, altimeter_box_sz, gui_color, view_rect)
	self.add_child(altimeter_box)
	
	health_bar = BarGauge.new(Vector2(0.02, 0.95), Vector2(0.26, 0.03), [warning_color, gui_color], 0)
	health_bar.set_framing(0.002, Color.GREEN, 0, 20)
	health_bar.set_bar2(1, Color.WHITE)
	health_bar.set_flash(0.2, 30, 0.7)
	health_bar.add_observer($"./GUI_health_beep")
	
	heading_number = NumberBox.new(Vector2(0.5 - altimeter_box_sz.x / 2, 0.01), altimeter_box_sz, gui_color, view_rect)
	self.add_child(heading_number)
	
	lat_vel_gauge = SlidingArrowGauge.new(Vector2(0.4, 0.85), Vector2(0.2, 0.02), 0, 30, 12, Vector2(0.05, 1), gui_color, view_rect)
	self.add_child(lat_vel_gauge)
	
	vrt_vel_gauge = SlidingArrowGauge.new(Vector2(0.8, 0.35), Vector2(0.015, 0.3), 1, 30, 12, Vector2(0.05, 1), gui_color, view_rect)
	self.add_child(vrt_vel_gauge)
	
	get_window().size_changed.connect(_on_window_resized)
	_on_window_resized()

func _physics_process(delta: float) -> void:
	queue_redraw()

func update_health_bar(val : int) -> void:
	health_bar.set_value(val)

func _draw() -> void:
	var view_rect = get_viewport_rect()
	var raw_fwd = -$"../../ZealousJay".transform.basis.z
	
	# Draw pitch ladder
	var pitch_ladder_data = pitch_ladder.construct_ladder_array(view_rect, raw_fwd)
	draw_line(pitch_ladder_data[0][0][0], pitch_ladder_data[0][0][1], gui_color)
	draw_line(pitch_ladder_data[0][1][0], pitch_ladder_data[0][1][1], gui_color)
	pitch_ladder_data.pop_front()
	
	for i in pitch_ladder_data:
		draw_line(i[0][0], i[0][1], gui_color)
		draw_line(i[1][0], i[1][1], gui_color)

	# Draw speed tape
	var unsigned_fwd_vel = $"../../ZealousJay".vel_vec.project(raw_fwd).length()
	var fwd_vel = unsigned_fwd_vel * $"../../ZealousJay".vel_vec.project(raw_fwd).normalized().dot(raw_fwd)
	var speed_tape_array = speed_tape.construct(false, fwd_vel, view_rect)
	for i in speed_tape_array:
		draw_line(i[0], i[1], gui_color)
	var speed_box_rect = speed_box.construct(view_rect)
	draw_rect(speed_box_rect, gui_color, false)
	speed_box.set_value(fwd_vel)
	
	# Draw altimeter tape
	var altitude = $"../../ZealousJay".transform.origin.y
	var altimeter_tape_array = altimeter_tape.construct(true, altitude, view_rect)
	for i in altimeter_tape_array:
		draw_line(i[0], i[1], gui_color)
	var altimeter_box_rect = altimeter_box.construct(view_rect)
	draw_rect(altimeter_box_rect, gui_color, false)
	altimeter_box.set_value(altitude)
	
	## Draw health bar
	health_bar.set_value($"../../ZealousJay".health)
	health_bar.set_max_value($"../../ZealousJay".max_health)
	var health_bar_disp1 = health_bar.get_bar1(view_rect)
	var health_bar_disp2 = health_bar.get_bar2(view_rect)
	var health_bar_bezel = health_bar.get_bezel_rect(view_rect)
	var health_bar_segments = health_bar.get_segment_lines(view_rect)
	draw_rect(health_bar_disp2, health_bar.get_bar2_color())
	draw_rect(health_bar_disp1, health_bar.get_bar1_color())
	draw_rect(health_bar_bezel, health_bar.get_bezel_color(), false)
	for i in health_bar_segments:
		draw_line(i[0], i[1], Color.GREEN)
	health_bar.step()
	
	var heading_vec = Vector3(raw_fwd.x, 0, raw_fwd.z).normalized()
	var heading_angle = -Vector3.BACK.signed_angle_to(heading_vec, Vector3.DOWN)
	if heading_angle < 0:
		heading_angle += TAU
	heading_number.set_value(int(rad_to_deg(heading_angle)))
	draw_rect(heading_number.construct(view_rect), gui_color, false)
	
	var right_vec = $"../../ZealousJay".transform.basis.x
	var lat_vel = $"../../ZealousJay".vel_vec.project(right_vec)
	lat_vel_gauge.set_value(lat_vel.length() * sign(lat_vel.dot(right_vec)))
	var lat_vel_tick_array = lat_vel_gauge.construct(view_rect)
	draw_line(lat_vel_tick_array[0][0][0], lat_vel_tick_array[0][0][1], gui_color)
	draw_line(lat_vel_tick_array[0][1][0], lat_vel_tick_array[0][1][1], gui_color)
	for i in range(1, lat_vel_tick_array.size()):
		draw_line(lat_vel_tick_array[i][0], lat_vel_tick_array[i][1], gui_color)
	
	var up_vec = $"../../ZealousJay".transform.basis.y
	var vrt_vel = $"../../ZealousJay".vel_vec.project(up_vec)
	vrt_vel_gauge.set_value(vrt_vel.length() * sign(vrt_vel.dot(up_vec)))
	var vrt_vel_tick_array = vrt_vel_gauge.construct(view_rect)
	draw_line(vrt_vel_tick_array[0][0][0], vrt_vel_tick_array[0][0][1], gui_color)
	draw_line(vrt_vel_tick_array[0][1][0], vrt_vel_tick_array[0][1][1], gui_color)
	for i in range(1, vrt_vel_tick_array.size()):
		draw_line(vrt_vel_tick_array[i][0], vrt_vel_tick_array[i][1], gui_color)
