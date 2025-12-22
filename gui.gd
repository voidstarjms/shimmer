extends Control

const pi_over_6 = PI / 6
const pi_over_4 = PI / 4
const pi_over_2 = PI / 2
const sqrt2_over_2 = sqrt(2) / 2
const compass_rose = ["N", "E", "S", "W"]

var pitch_ladder : PitchLadder
var heading_indicator : HeadingGauge
var speed_tape
var speed_tape_labels : Array[Label]
var health_bar : BarGauge

var gui_color = Color.GREEN

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
	var rung_count
	
	func _init(pos : Vector2, sz : Vector2, lvl_len : float, lvl_margin : float, rung_len : float, num_rungs : int, color : Color, view_rect : Rect2) -> void:
		position = pos
		size = sz
		level_mark_len = lvl_len
		level_mark_margin = lvl_margin
		rung_length = rung_len
		rung_outer_width = size.x / 2 - level_mark_len - lvl_margin
		rung_inner_width = rung_outer_width - rung_len
		max_vert = size.y / 2
		rung_count = num_rungs
		
		# Initialize pitch marker text
		label_list = Array()
		for i in rung_count:
			var label = Label.new()
			label.text = str(90 - i * 180 / (rung_count - 1))
			label.set("theme_override_colors/font_color", color)
			label_list.append(label)
			self.add_child(label)
			# Singleton to initialize base label and font size
			if i == 0:
				base_label_size = view_rect.size
				base_font_size = label.get_theme_font_size("font_size", label.get_class())
	
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
		
		# Append rungs
		var pitch_angle = pi_over_2 - acos(raw_fwd.dot(Vector3.UP))
		for i in rung_count:
			label_list[i].visible = false
			var rung_angle = pitch_angle + (6.0 / (rung_count - 1) * pi_over_6 * i - pi_over_2)
			# Cull rung if angle is out of bounds
			if (abs(rung_angle) > pi_over_4):
				continue
			
			var rung_outer_vec = rung_outer_width * wx * Vector2.RIGHT
			var rung_inner_vec = rung_inner_width * wx * Vector2.RIGHT
			
			var rung_vrt_offset = rung_angle / pi_over_4 * max_vert * wy * Vector2.UP
			label_list[i].visible = true
			label_list[i].position = center - rung_outer_vec - rung_vrt_offset
			
			var rung_left = [center - rung_outer_vec - rung_vrt_offset, center - rung_inner_vec - rung_vrt_offset]
			var rung_right = [center + rung_outer_vec - rung_vrt_offset, center + rung_inner_vec - rung_vrt_offset]
			ret_arr.append([rung_left, rung_right])
		
		return ret_arr

class HeadingGauge extends TextScalable:
	var pos : Vector2 # Fraction of screen size
	var sz : Vector2 # Fraction of screen size
	var subdivision_count
	
	func _init(p : Vector2, s : Vector2, subdiv_count : int, base_fnt_sz : int, color : Color):
		pos = p
		sz = s
		subdivision_count = subdiv_count
		base_font_size = 1
		
		label_list = Array()
		for i in 4:
			var label = RichTextLabel.new()
			label.text = compass_rose[i]
			label.theme = Theme.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			label.size = Vector2(base_fnt_sz, 1.5 * base_fnt_sz)
			if i == 0:
				base_label_size = label.size
			label.add_theme_font_size_override("normal_font_size", base_font_size)
			label.add_theme_color_override("default_color", color)
			label_list.append(label)
			add_child(label)
	
	func construct_heading_markers(fwd_vec : Vector3, view_rect : Rect2):
		var wx = view_rect.size.x
		var wy = view_rect.size.y
		var px = pos.x * wx
		var py = pos.y * wy
		var sx = sz.x * wx
		var sy = sz.y * wy
		
		var ret_arr = Array()
		
		var heading_vec = Vector3(fwd_vec.x, 0, fwd_vec.z).normalized()
		for i in 4:
			label_list[i].visible = false
		for i in 4 * subdivision_count:
			var marker_vec = Vector3.BACK.rotated(Vector3.UP, i * 3.0 / subdivision_count * pi_over_6)
			var marker_angle = marker_vec.signed_angle_to(heading_vec, Vector3.DOWN)
			if abs(marker_angle) > pi_over_4:
				continue
			var marker_horiz_offset = Vector2.RIGHT * sx / 2 * marker_angle / pi_over_4
			
			if i % subdivision_count == 0:
				ret_arr.append(null)
				var current_compass_text : RichTextLabel = label_list[(i / subdivision_count) % 4]
				current_compass_text.visible = true
				var fnt_size = current_compass_text.get_theme_font_size("normal_font_size")
				current_compass_text.size = Vector2(fnt_size, fnt_size * 1.5)
				current_compass_text.position = Vector2(wx / 2, py) + marker_horiz_offset - Vector2((0.75 * current_compass_text.size.x) / 2, 0)
			else:
				ret_arr.append([Vector2(wx / 2, py) + marker_horiz_offset, Vector2(wx / 2, py + sy) + marker_horiz_offset])
		
		return ret_arr

class TapeGauge extends TextScalable:
	var pos : Vector2 # Fraction of screen size
	var sz : Vector2 # Fraction of screen size
	var max_value : int
	var major_tick_freq : int
	var minor_tick_gap : float # Fraction of screen size
	var minor_tick_sz : float # Fraction of major tick width
	var gap_value : int # The value interval between major ticks
	var major_tick_count : int
	
	func _init(p : Vector2, s : Vector2, max_val : int, division : Vector2, minor_sz : float, gap_val : int, view_rect : Rect2):
		pos = p
		sz = s
		max_value = max_val
		major_tick_freq = int(division.x)
		minor_tick_gap = division.y
		minor_tick_sz = minor_sz
		gap_value = gap_val
		# TODO This doesn't work because major tick count needs to be dynamically updated
		var tape_height = view_rect.size.y * sz.y
		var tick_count = int(tape_height / (tape_height * minor_tick_gap))
		major_tick_count = tick_count / major_tick_freq

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
		var wy = view_rect.size.y
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

func _on_window_resized():
	var window = get_window()
	var wx = window.size.x
	var wy = window.size.y
	pitch_ladder.resize_text(get_viewport_rect())
	heading_indicator.resize_text(get_viewport_rect())

func _ready() -> void:
	pitch_ladder = PitchLadder.new(Vector2(0.3, 0.125), Vector2(0.4, 0.75), 0.016, 0.004, 0.04, 7, gui_color, get_viewport_rect())
	self.add_child(pitch_ladder)
	
	heading_indicator = HeadingGauge.new(Vector2(0.2, 0.02), Vector2(0.6, 0.05), 5, 40, gui_color)
	self.add_child(heading_indicator)
	
	# Initialize speed tape
	speed_tape = TapeGauge.new(Vector2(0.02, 0.25), Vector2(0.05, 0.5), 100, Vector2(5, 0.04), 0.5, 20, get_viewport_rect())
	speed_tape_labels = []
	for i in speed_tape.major_tick_count + 1:
		var label = Label.new()
		label.set("theme_override_colors/font_color", gui_color)
		speed_tape_labels.append(label)
		add_child(label)
	
	health_bar = BarGauge.new(Vector2(0.3, 0.95), Vector2(0.4, 0.03), [Color.RED, Color.GREEN], 0)
	health_bar.set_framing(0.002, Color.GREEN, 0, 20)
	health_bar.set_bar2(1, Color.WHITE)
	health_bar.set_flash(0.2, 30, 0.7)
	health_bar.add_observer($"./GUI_health_beep")
	
	get_window().size_changed.connect(_on_window_resized)
	_on_window_resized()

func construct_tape_gauge_array(gauge : TapeGauge, label_arr : Array, left : bool, metered_value : float):
	var w = get_viewport_rect()
	var wx = w.size.x
	var wy = w.size.y
	
	# Extract members from TapeGuage object
	var tape_pos = gauge.pos
	var tape_sz = gauge.sz
	var tape_max_value = gauge.max_value
	var tape_major_tick_freq = gauge.major_tick_freq
	var tape_minor_tick_gap = gauge.minor_tick_gap
	var tape_minor_tick_sz = gauge.minor_tick_sz
	var tape_gap_value = gauge.gap_value
	
	# Derive measurements
	var tape_width = wx * tape_sz.x
	var tape_height = wy * tape_sz.y
	var tick_count = int(tape_height / (tape_height * tape_minor_tick_gap))
	var tick_gap_absolute = int(tape_minor_tick_gap * tape_height)
	var x_absolute = tape_pos.x * wx
	var y_absolute = tape_pos.y * wy
	metered_value = min(metered_value, tape_max_value)
	
	var mark_arr = Array()
	for i in tick_count + tape_major_tick_freq:
		var is_major_tick = i % tape_major_tick_freq == 0
		if is_major_tick == true:
			label_arr[i / tape_major_tick_freq].visible = false
		
		# Compute mark offset, cull if out of bounds
		var metered_val_offset = tick_gap_absolute * i + ((tape_gap_value * -int(metered_value) % (tape_major_tick_freq * tick_gap_absolute)) - tape_gap_value * fposmod(metered_value, 1))
		if metered_val_offset < 0 or metered_val_offset >= tape_height:
			continue
		
		var tick_width = tape_width
		if is_major_tick == false:
			tick_width *= tape_minor_tick_sz
		else:
			label_arr[i / tape_major_tick_freq].visible = true
		
		# Compute tick mark vertices
		var tick_start
		var tick_end
		if left == true:
			tick_start = Vector2(x_absolute, y_absolute + tape_height - metered_val_offset)
			tick_end = Vector2(x_absolute + tick_width, y_absolute + tape_height - metered_val_offset)
		else:
			tick_start = Vector2(x_absolute + tape_width - tick_width, y_absolute + metered_val_offset)
			tick_end = Vector2(x_absolute + tape_width, y_absolute + metered_val_offset)
		
		if is_major_tick == true:
			label_arr[i / tape_major_tick_freq].position = tick_end
			if label_arr[i / tape_major_tick_freq].position.y > tape_height + tape_pos.y:
				pass#label_arr.push_back(label_arr.pop_front())
			label_arr[i / tape_major_tick_freq].text = str((i / tape_major_tick_freq) * tape_gap_value / tape_major_tick_freq * tape_major_tick_freq)
		mark_arr.append([tick_start, tick_end])
	
	return mark_arr

func _process(delta: float) -> void:
	queue_redraw()

func update_health_bar(val : int) -> void:
	health_bar.set_value(val)

func _draw() -> void:
	var view_rect = get_viewport_rect()
	var wx = view_rect.size.x
	#var wy = view_rect.size.y
	#var view_center = Vector2(view_rect.size.x / 2, view_rect.size.y / 2)
	var raw_fwd = -$"../../ZealousJay".transform.basis.z
	
	# Draw pitch ladder
	var pitch_ladder_data = pitch_ladder.construct_ladder_array(view_rect, raw_fwd)
	draw_line(pitch_ladder_data[0][0][0], pitch_ladder_data[0][0][1], gui_color)
	draw_line(pitch_ladder_data[0][1][0], pitch_ladder_data[0][1][1], gui_color)
	pitch_ladder_data.pop_front()
	
	for i in pitch_ladder_data:
		draw_line(i[0][0], i[0][1], gui_color)
		draw_line(i[1][0], i[1][1], gui_color)
	
	var compass_data = heading_indicator.construct_heading_markers(raw_fwd, view_rect)
	for i in compass_data:
		if i != null:
			draw_line(i[0], i[1], gui_color)
	
	## Draw heading indicator
	#var heading_vec = Vector3(raw_fwd.x, 0, raw_fwd.z).normalized()
	#var compass_data = heading_indicator.construct_heading_markers(raw_fwd, view_rect)
	#for i in 4:
		#compass_text[i].visible = false
	#for i in 4 * compass_subdivision_count:
		#var marker_vec = Vector3.BACK.rotated(Vector3.UP, i * 3.0 / compass_subdivision_count * pi_over_6)
		#var marker_angle = marker_vec.signed_angle_to(heading_vec, Vector3.DOWN)
		#if abs(marker_angle) > pi_over_4:
			#continue
		#var marker_horiz_offset = Vector2.RIGHT * compass_half_width * marker_angle / pi_over_4
		#
		#if i % compass_subdivision_count == 0:
			#var current_compass_text = compass_text[(i / compass_subdivision_count) % 4]
			#current_compass_text.visible = true
			#current_compass_text.position = Vector2(wx / 2, compass_mark_top) + marker_horiz_offset - Vector2((current_compass_text.size.x - 10) / 2, 0)
		#else:
			#draw_line(Vector2(view_rect.size.x / 2, compass_mark_top) + marker_horiz_offset, Vector2(view_rect.size.x / 2, compass_mark_bottom) + marker_horiz_offset, gui_color)

	## Draw speed tape
	#var speed_tape_array = construct_tape_gauge_array(speed_tape, speed_tape_labels, true, $"../../ZealousJay".vel_vec.length() * 3.6)
	#for i in speed_tape_array:
		#draw_line(i[0], i[1], gui_color)
		#
	#draw_line(Vector2(wx / 2, 0), Vector2(wx / 2, 100), gui_color)
	
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
