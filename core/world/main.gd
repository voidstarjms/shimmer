extends Node

enum slomo_env {
	attack,
	sustain,
	release,
	none
}

var slomo_phase = slomo_env.none
var slomo_phase_duration = 0
var slomo_counter = 0
var slomo_speed = 0.0
# Attack, sustain, and release durations in frames
var slomo_envelope = [0, 0, 0]

func set_slomo(speed : float, envelope : Array):
	if slomo_phase != slomo_env.none:
		return
	
	slomo_phase = slomo_env.attack
	slomo_counter = 0
	slomo_speed = speed
	for i in slomo_env.none:
		slomo_envelope[i] = envelope[i]

func step_slomo():
	# Return if not in slomo
	if slomo_phase == slomo_env.none:
		return
	
	slomo_counter += 1
	var lerp_fraction = 0.0
	if slomo_envelope[slomo_phase] != 0:
		lerp_fraction = float(slomo_counter) / slomo_envelope[slomo_phase]
	
	match slomo_phase:
		slomo_env.attack:
			Engine.time_scale = lerp(1.0, slomo_speed, lerp_fraction)
		slomo_env.release:
			Engine.time_scale = lerp(slomo_speed, 1.0, lerp_fraction)
	
	if slomo_counter >= slomo_phase_duration:
		slomo_phase += 1
		slomo_counter = 0
		if slomo_phase != slomo_env.none:
			slomo_phase_duration = slomo_envelope[slomo_phase]

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()

func _physics_process(delta: float) -> void:
	if slomo_phase != slomo_env.none:
		step_slomo()
