extends "res://scripts/agents/AgentMotor3D.gd"
class_name CrawlerAgent

@export_group("Crawler Wander")
@export_range(0.0, 2.0, 0.01) var wander_strength: float = 0.76
@export_range(0.01, 3.0, 0.01) var wander_frequency: float = 0.12
@export_range(0.01, 10.0, 0.01) var wander_smoothing: float = 0.9
@export_range(0.0, 1.0, 0.01) var vertical_wander_amount: float = 0.14

@export_group("Home Tether")
@export_range(0.1, 10.0, 0.01) var home_radius: float = 1.05
@export_range(0.0, 4.0, 0.01) var home_tether_strength: float = 0.85

@export_group("Placeholder Visual")
@export var visual_root_path: NodePath = ^"VisualRoot"
@export_range(0.0, 0.2, 0.001) var crawl_wave_amount: float = 0.025
@export_range(0.01, 5.0, 0.01) var crawl_wave_frequency: float = 0.9

var home_position: Vector3 = Vector3.ZERO
var current_wander_direction: Vector3 = Vector3.FORWARD
var current_state: String = "WANDER"

var _elapsed_time: float = 0.0
var _wander_seed: float = 0.0
var _visual_root: Node3D


func _ready() -> void:
	if not is_in_group(&"interest_entity"):
		add_to_group(&"interest_entity")

	home_position = global_position
	_wander_seed = _seed_from_name()
	current_wander_direction = _sample_wander_direction(0.0)
	direction = current_wander_direction
	target_direction = current_wander_direction
	_visual_root = get_node_or_null(visual_root_path) as Node3D


func _process(delta: float) -> void:
	_elapsed_time += delta
	_update_wander_direction(delta)

	var desired_velocity_for_frame: Vector3 = current_wander_direction * max_speed * wander_strength
	desired_velocity_for_frame = _apply_home_tether(desired_velocity_for_frame)
	apply_desired_velocity(desired_velocity_for_frame, delta)
	_update_placeholder_visual()


func _update_wander_direction(delta: float) -> void:
	var sampled_direction: Vector3 = _sample_wander_direction(_elapsed_time)
	var alpha: float = 1.0 - exp(-wander_smoothing * delta)
	current_wander_direction = current_wander_direction.lerp(sampled_direction, alpha)
	current_wander_direction = _safe_direction(current_wander_direction, Vector3.FORWARD)


func _apply_home_tether(input_desired_velocity: Vector3) -> Vector3:
	var distance_from_home: float = global_position.distance_to(home_position)
	var tether_start: float = home_radius * 0.55
	if distance_from_home <= tether_start:
		return input_desired_velocity

	var tether_blend: float = clamp(
		(distance_from_home - tether_start) / max(home_radius - tether_start, 0.001),
		0.0,
		1.0
	)
	var home_desired_velocity: Vector3 = SteeringHelper.arrive(
		global_position,
		home_position,
		max_speed,
		home_radius
	)
	return input_desired_velocity + home_desired_velocity * tether_blend * home_tether_strength


func _update_placeholder_visual() -> void:
	if not _visual_root:
		return

	var wave_phase: float = _elapsed_time * TAU * crawl_wave_frequency + _wander_seed
	_visual_root.position.y = sin(wave_phase) * crawl_wave_amount
	_visual_root.rotation.z = sin(wave_phase * 0.73) * crawl_wave_amount * 2.0


func _sample_wander_direction(time: float) -> Vector3:
	var phase: float = time * TAU * wander_frequency + _wander_seed
	var sample: Vector3 = Vector3(
		sin(phase * 0.79 + 0.4),
		sin(phase * 1.21 + 1.8) * vertical_wander_amount,
		cos(phase * 0.61 + 0.7)
	)

	return _safe_direction(sample, Vector3.FORWARD)


func _seed_from_name() -> float:
	var seed_text: String = "%s:%s" % [name, str(get_instance_id())]
	var seed_value: int = abs(hash(seed_text)) % 10000
	return float(seed_value) / 10000.0 * TAU
