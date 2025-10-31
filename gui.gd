extends Control

var pitch_ladder_outer_width
var pitch_ladder_inner_width
var pitch_ladder_level_mark_outer_width
var pitch_ladder_level_mark_inner_width
const pi_over_6 = PI / 6
const pi_over_4 = PI / 4
const pi_over_2 = PI / 2
const sqrt2_over_2 = sqrt(2) / 2
const pitch_mark_increment = 30
var pitch_marker_text
var max_pitch_ladder_vert

func _on_window_resized():
	var window = get_window()
	pitch_ladder_level_mark_outer_width = window.size.x * 0.18
	pitch_ladder_level_mark_inner_width = window.size.x * 0.164
	pitch_ladder_outer_width = window.size.x * 0.16
	pitch_ladder_inner_width = window.size.x * 0.12
	max_pitch_ladder_vert = window.size.y * 0.375

func _ready() -> void:
	get_window().size_changed.connect(_on_window_resized)
	_on_window_resized()
	var pitch_mark_count = int(180 / pitch_mark_increment) + 1
	pitch_marker_text = Array()
	for i in pitch_mark_count:
		var label = Label.new()
		label.text = str(90 - i * pitch_mark_increment)
		label.add_theme_color_override("green", Color.GREEN)
		pitch_marker_text.append(label)
		add_child(label)

func _process(delta: float) -> void:
	queue_redraw()
	
func _draw() -> void:
	var view_rect = get_viewport_rect()
	var view_center = Vector2(view_rect.size.x / 2, view_rect.size.y / 2)
	var raw_fwd = -$"../../ZealousJay".transform.basis.z
	var pitch_angle = pi_over_2 - acos(raw_fwd.dot(Vector3.UP))
	print(pitch_angle)
	for i in 7:
		pitch_marker_text[i].visible = false
		var rung_angle = pitch_angle + (pi_over_6 * i - pi_over_2)
		if (abs(rung_angle) > pi_over_4):
			continue
		var pitch_ladder_vrt_offset = rung_angle / pi_over_4 * max_pitch_ladder_vert * Vector2.UP
		pitch_marker_text[i].visible = true
		pitch_marker_text[i].position = view_center - pitch_ladder_outer_width * Vector2.RIGHT - pitch_ladder_vrt_offset
		draw_line(view_center - pitch_ladder_level_mark_outer_width * Vector2.RIGHT, view_center - pitch_ladder_level_mark_inner_width * Vector2.RIGHT, Color.GREEN)
		draw_line(view_center + pitch_ladder_level_mark_outer_width * Vector2.RIGHT, view_center + pitch_ladder_level_mark_inner_width * Vector2.RIGHT, Color.GREEN)
		draw_line(view_center - pitch_ladder_outer_width * Vector2.RIGHT - pitch_ladder_vrt_offset, view_center - pitch_ladder_inner_width * Vector2.RIGHT - pitch_ladder_vrt_offset, Color.GREEN)
		draw_line(view_center + pitch_ladder_outer_width * Vector2.RIGHT - pitch_ladder_vrt_offset, view_center + pitch_ladder_inner_width * Vector2.RIGHT - pitch_ladder_vrt_offset, Color.GREEN)
