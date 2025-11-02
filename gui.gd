extends Control

var pitch_ladder_outer_width
var pitch_ladder_inner_width
var pitch_ladder_level_mark_outer_width
var pitch_ladder_level_mark_inner_width
const pi_over_6 = PI / 6
const pi_over_4 = PI / 4
const pi_over_2 = PI / 2
const sqrt2_over_2 = sqrt(2) / 2
const compass_rose = ["N", "E", "S", "W"]
## NOTE: this value must not exceed 90 or it will result in div by 0
const pitch_mark_count = 7
var pitch_marker_text
var max_pitch_ladder_vert
const compass_subdivision_count = 5
var compass_text
var compass_mark_top
var compass_mark_bottom
var compass_half_width

func _on_window_resized():
	var window = get_window()
	pitch_ladder_level_mark_outer_width = window.size.x * 0.18
	pitch_ladder_level_mark_inner_width = window.size.x * 0.164
	pitch_ladder_outer_width = window.size.x * 0.16
	pitch_ladder_inner_width = window.size.x * 0.12
	max_pitch_ladder_vert = window.size.y * 0.375
	compass_mark_top = window.size.y * 0.02
	compass_mark_bottom = window.size.y * 0.07
	compass_half_width = window.size.x * 0.3

func _ready() -> void:
	get_window().size_changed.connect(_on_window_resized)
	_on_window_resized()
	
	# Initialize pitch marker text
	pitch_marker_text = Array()
	for i in pitch_mark_count:
		var label = Label.new()
		label.text = str(90 - i * 180 / (pitch_mark_count - 1))
		label.add_theme_color_override("green", Color.GREEN)
		pitch_marker_text.append(label)
		add_child(label)
		
	# Initialize heading indicator text
	compass_text = Array()
	for i in 4:
		var label = Label.new()
		label.text = compass_rose[i]
		compass_text.append(label)
		add_child(label)

func _process(delta: float) -> void:
	queue_redraw()
	
func _draw() -> void:
	var view_rect = get_viewport_rect()
	var view_center = Vector2(view_rect.size.x / 2, view_rect.size.y / 2)
	var raw_fwd = -$"../../ZealousJay".transform.basis.z
	
	## Draw pitch ladder
	var pitch_angle = pi_over_2 - acos(raw_fwd.dot(Vector3.UP))
	for i in pitch_mark_count:
		pitch_marker_text[i].visible = false
		var rung_angle = pitch_angle + (6.0 / (pitch_mark_count - 1) * pi_over_6 * i - pi_over_2)
		if (abs(rung_angle) > pi_over_4):
			continue
		var pitch_ladder_vrt_offset = rung_angle / pi_over_4 * max_pitch_ladder_vert * Vector2.UP
		pitch_marker_text[i].visible = true
		pitch_marker_text[i].position = view_center - pitch_ladder_outer_width * Vector2.RIGHT - pitch_ladder_vrt_offset
		draw_line(view_center - pitch_ladder_level_mark_outer_width * Vector2.RIGHT, view_center - pitch_ladder_level_mark_inner_width * Vector2.RIGHT, Color.GREEN)
		draw_line(view_center + pitch_ladder_level_mark_outer_width * Vector2.RIGHT, view_center + pitch_ladder_level_mark_inner_width * Vector2.RIGHT, Color.GREEN)
		draw_line(view_center - pitch_ladder_outer_width * Vector2.RIGHT - pitch_ladder_vrt_offset, view_center - pitch_ladder_inner_width * Vector2.RIGHT - pitch_ladder_vrt_offset, Color.GREEN)
		draw_line(view_center + pitch_ladder_outer_width * Vector2.RIGHT - pitch_ladder_vrt_offset, view_center + pitch_ladder_inner_width * Vector2.RIGHT - pitch_ladder_vrt_offset, Color.GREEN)

	## Draw heading indicator
	var heading_vec = Vector3(raw_fwd.x, 0, raw_fwd.z).normalized()
	var heading_angle = acos(heading_vec.dot(Vector3.FORWARD)) if heading_vec.dot(Vector3.LEFT) >= 0 else PI + acos(heading_vec.dot(Vector3.BACK))
	for i in 4:
		compass_text[i].visible = false
	for i in 4 * compass_subdivision_count:
		var marker_vec = Vector3.BACK.rotated(Vector3.UP, i * 3.0 / compass_subdivision_count * pi_over_6)
		var marker_angle = marker_vec.signed_angle_to(heading_vec, Vector3.DOWN)
		if abs(marker_angle) > pi_over_4:
			continue
		var marker_horiz_offset = Vector2.RIGHT * compass_half_width * marker_angle / pi_over_4
		
		if i % compass_subdivision_count == 0:
			var current_compass_text = compass_text[(i / compass_subdivision_count) % 4]
			current_compass_text.visible = true
			current_compass_text.position = Vector2(view_rect.size.x / 2, compass_mark_top) + marker_horiz_offset
		else:
			draw_line(Vector2(view_rect.size.x / 2, compass_mark_top) + marker_horiz_offset, Vector2(view_rect.size.x / 2, compass_mark_bottom) + marker_horiz_offset, Color.GREEN)
