extends RefCounted
class_name IdleCadence

var is_idle: bool = false
var time_remaining: float = 0.0

var _seed: float = 0.0
var _step: int = 0


func configure(seed: float) -> void:
	_seed = seed
	_step = 0
	is_idle = false
	time_remaining = 0.0


func update(
	delta: float,
	enabled: bool,
	idle_probability: float,
	idle_duration_min: float,
	idle_duration_max: float,
	move_duration_min: float,
	move_duration_max: float
) -> bool:
	if not enabled:
		is_idle = false
		time_remaining = 0.0
		return false

	time_remaining -= delta
	if time_remaining <= 0.0:
		if is_idle:
			_start_phase(false, move_duration_min, move_duration_max)
		else:
			_start_phase(
				_sample(17.0) < idle_probability,
				idle_duration_min,
				idle_duration_max,
				move_duration_min,
				move_duration_max
			)

	return is_idle


func force_move(move_duration_min: float, move_duration_max: float) -> void:
	if not is_idle and time_remaining > 0.0:
		return

	_start_phase(false, 0.0, 0.0, move_duration_min, move_duration_max)


func _start_phase(
	next_is_idle: bool,
	idle_duration_min: float,
	idle_duration_max: float,
	move_duration_min: float = 0.0,
	move_duration_max: float = 0.0
) -> void:
	_step += 1
	is_idle = next_is_idle
	if is_idle:
		time_remaining = lerp(idle_duration_min, idle_duration_max, _sample(29.0))
	else:
		time_remaining = lerp(move_duration_min, move_duration_max, _sample(43.0))
	time_remaining = max(time_remaining, 0.05)


func _sample(offset: float) -> float:
	return 0.5 + sin(_seed * 3.71 + float(_step) * 1.618 + offset) * 0.5
