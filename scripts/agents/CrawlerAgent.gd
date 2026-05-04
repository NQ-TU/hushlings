extends "res://scripts/agents/AgentMotor3D.gd"
class_name CrawlerAgent

const ObstacleAvoidanceHelper := preload("res://scripts/steering/ObstacleAvoidance.gd")
const PlayerPerceptionHelper := preload("res://scripts/perception/PlayerPerception.gd")
const IdleCadenceHelper := preload("res://scripts/agents/IdleCadence.gd")
const FleeMemoryHelper := preload("res://scripts/agents/FleeMemory.gd")

@export_group("Crawler Wander")
@export_range(0.0, 2.0, 0.01) var wander_strength: float = 0.76
@export_range(0.01, 3.0, 0.01) var wander_frequency: float = 0.12
@export_range(0.01, 10.0, 0.01) var wander_smoothing: float = 0.9
@export_range(0.0, 1.0, 0.01) var vertical_wander_amount: float = 0.14

@export_group("Idle Cadence")
@export var idle_cadence_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var idle_probability: float = 0.26
@export_range(0.05, 8.0, 0.01) var idle_duration_min: float = 0.8
@export_range(0.05, 8.0, 0.01) var idle_duration_max: float = 2.2
@export_range(0.05, 12.0, 0.01) var move_duration_min: float = 1.6
@export_range(0.05, 12.0, 0.01) var move_duration_max: float = 3.8
@export_range(0.0, 0.3, 0.01) var idle_drift_scale: float = 0.03

@export_group("Home Tether")
@export_range(0.1, 10.0, 0.01) var home_radius: float = 1.05
@export_range(0.0, 4.0, 0.01) var home_tether_strength: float = 0.85

@export_group("Obstacle Avoidance")
@export var obstacle_avoidance_enabled: bool = true
@export_flags_3d_physics var obstacle_collision_mask: int = 1
@export_range(0.05, 5.0, 0.01) var obstacle_feeler_length: float = 0.5
@export_range(1.0, 85.0, 1.0) var obstacle_feeler_angle_degrees: float = 34.0
@export_range(0.0, 5.0, 0.01) var obstacle_avoidance_weight: float = 0.72

@export_group("Player Interaction")
@export var flee_from_player_hand_feelers: bool = true
@export var player_hand_group: StringName = &"player_hand"
@export_range(0.05, 5.0, 0.01) var player_hand_flee_memory_time: float = 1.1
@export_range(0.1, 10.0, 0.01) var player_hand_flee_safe_radius: float = 1.0
@export_range(0.0, 5.0, 0.01) var player_hand_flee_speed_scale: float = 1.35

@export_group("Visual")
@export var visual_root_path: NodePath = ^"VisualRoot"

var home_position: Vector3 = Vector3.ZERO
var current_wander_direction: Vector3 = Vector3.FORWARD
var current_state: String = "WANDER"
var obstacle_avoidance_force: Vector3 = Vector3.ZERO
var debug_obstacle_hit: bool = false
var debug_obstacle_hit_position: Vector3 = Vector3.ZERO
var debug_obstacle_hit_normal: Vector3 = Vector3.ZERO
var debug_player_hand_flee_active: bool = false
var debug_is_idle: bool = false

var _elapsed_time: float = 0.0
var _wander_seed: float = 0.0
var _visual_root: Node3D
var _idle_cadence := IdleCadenceHelper.new()
var _player_hand_flee := FleeMemoryHelper.new()


func _ready() -> void:
	if not is_in_group(&"interest_entity"):
		add_to_group(&"interest_entity")

	home_position = global_position
	_wander_seed = _make_instance_seed()
	_idle_cadence.configure(_wander_seed)
	_idle_cadence.force_move(move_duration_min, move_duration_max)
	current_wander_direction = _sample_wander_direction(0.0)
	direction = current_wander_direction
	target_direction = current_wander_direction
	_visual_root = get_node_or_null(visual_root_path) as Node3D
	if _visual_root and _visual_root.has_method(&"bind_agent"):
		_visual_root.call(&"bind_agent", self)


func _process(delta: float) -> void:
	_elapsed_time += delta
	_update_player_hand_flee_memory(delta)
	_update_wander_direction(delta)
	_update_idle_cadence(delta)

	var desired_velocity_for_frame: Vector3
	if _is_player_hand_flee_active():
		current_state = "FLEE"
		desired_velocity_for_frame = _calculate_player_hand_flee_velocity()
	else:
		current_state = "IDLE" if debug_is_idle else "WANDER"
		var idle_scale: float = idle_drift_scale if debug_is_idle else 1.0
		desired_velocity_for_frame = current_wander_direction * max_speed * wander_strength * idle_scale
		desired_velocity_for_frame = _apply_home_tether(desired_velocity_for_frame)

	desired_velocity_for_frame += _calculate_obstacle_avoidance(desired_velocity_for_frame)
	apply_desired_velocity(desired_velocity_for_frame, delta)
	_update_visual()


func _update_wander_direction(delta: float) -> void:
	var sampled_direction: Vector3 = _sample_wander_direction(_elapsed_time)
	var alpha: float = 1.0 - exp(-wander_smoothing * delta)
	current_wander_direction = current_wander_direction.lerp(sampled_direction, alpha)
	current_wander_direction = _safe_direction(current_wander_direction, Vector3.FORWARD)


func _update_idle_cadence(delta: float) -> void:
	if _is_player_hand_flee_active():
		_idle_cadence.force_move(move_duration_min, move_duration_max)
		debug_is_idle = false
		return

	debug_is_idle = _idle_cadence.update(
		delta,
		idle_cadence_enabled,
		idle_probability,
		idle_duration_min,
		idle_duration_max,
		move_duration_min,
		move_duration_max
	)


func _apply_home_tether(input_desired_velocity: Vector3) -> Vector3:
	return SteeringHelper.apply_home_tether(
		global_position,
		home_position,
		input_desired_velocity,
		max_speed,
		home_radius,
		home_tether_strength
	)


func _calculate_obstacle_avoidance(input_desired_velocity: Vector3) -> Vector3:
	obstacle_avoidance_force = Vector3.ZERO
	debug_obstacle_hit = false
	debug_obstacle_hit_position = Vector3.ZERO
	debug_obstacle_hit_normal = Vector3.ZERO
	if not obstacle_avoidance_enabled:
		return Vector3.ZERO

	var result: Dictionary = ObstacleAvoidanceHelper.calculate(
		self,
		input_desired_velocity,
		obstacle_feeler_length,
		obstacle_feeler_angle_degrees,
		obstacle_collision_mask,
		max_speed
	)
	var raw_force: Vector3 = result.get("force", Vector3.ZERO)
	obstacle_avoidance_force = raw_force * obstacle_avoidance_weight
	debug_obstacle_hit = bool(result.get("hit", false))
	debug_obstacle_hit_position = result.get("hit_position", Vector3.ZERO)
	debug_obstacle_hit_normal = result.get("hit_normal", Vector3.ZERO)
	_handle_player_hand_feeler_hit(result)
	return obstacle_avoidance_force


func _handle_player_hand_feeler_hit(result: Dictionary) -> void:
	if not flee_from_player_hand_feelers:
		return

	var hand := PlayerPerceptionHelper.hand_from_feeler_result(result, player_hand_group)
	if hand == null:
		return

	_player_hand_flee.trigger(hand, player_hand_flee_memory_time)
	debug_player_hand_flee_active = true


func _update_player_hand_flee_memory(delta: float) -> void:
	_player_hand_flee.update(delta, global_position, player_hand_flee_safe_radius)
	debug_player_hand_flee_active = _is_player_hand_flee_active()


func _is_player_hand_flee_active() -> bool:
	return _player_hand_flee.is_active()


func _calculate_player_hand_flee_velocity() -> Vector3:
	return PlayerPerceptionHelper.flee_velocity(
		global_position,
		_player_hand_flee.target,
		current_wander_direction,
		max_speed,
		player_hand_flee_speed_scale
	)


func _update_visual() -> void:
	if not _visual_root:
		return

	if _visual_root.has_method(&"set_velocity"):
		_visual_root.call(&"set_velocity", velocity)
	if _visual_root.has_method(&"set_target_direction"):
		_visual_root.call(&"set_target_direction", target_direction)
	if _visual_root.has_method(&"set_agent_state"):
		_visual_root.call(&"set_agent_state", current_state)


func _sample_wander_direction(time: float) -> Vector3:
	var phase: float = time * TAU * wander_frequency + _wander_seed
	var sample: Vector3 = Vector3(
		sin(phase * 0.79 + 0.4),
		sin(phase * 1.21 + 1.8) * vertical_wander_amount,
		cos(phase * 0.61 + 0.7)
	)

	return _safe_direction(sample, Vector3.FORWARD)
