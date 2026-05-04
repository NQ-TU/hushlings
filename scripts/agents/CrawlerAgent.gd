extends "res://scripts/agents/AgentMotor3D.gd"
class_name CrawlerAgent

const ObstacleAvoidanceHelper := preload("res://scripts/steering/ObstacleAvoidance.gd")
const PlayerPerceptionHelper := preload("res://scripts/perception/PlayerPerception.gd")
const IdleCadenceHelper := preload("res://scripts/agents/IdleCadence.gd")
const FleeMemoryHelper := preload("res://scripts/agents/FleeMemory.gd")

@export_group("Crawler Wander")
@export_range(0.0, 2.0, 0.01) var wander_strength: float = 0.98
@export_range(0.05, 12.0, 0.01) var course_duration_min: float = 2.8
@export_range(0.05, 12.0, 0.01) var course_duration_max: float = 5.8
@export_range(0.01, 10.0, 0.01) var wander_smoothing: float = 1.55
@export_range(0.0, 1.0, 0.01) var vertical_wander_amount: float = 0.28
@export_range(0.0, 1.0, 0.01) var lateral_wander_amount: float = 0.55
@export_range(0.0, 0.95, 0.01) var wander_forward_bias: float = 0.45
@export_range(1.0, 180.0, 1.0) var wander_turn_degrees_per_second: float = 52.0

@export_group("Idle Cadence")
@export var idle_cadence_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var idle_probability: float = 0.14
@export_range(0.05, 8.0, 0.01) var idle_duration_min: float = 0.45
@export_range(0.05, 8.0, 0.01) var idle_duration_max: float = 1.2
@export_range(0.05, 12.0, 0.01) var move_duration_min: float = 3.0
@export_range(0.05, 12.0, 0.01) var move_duration_max: float = 6.5
@export_range(0.0, 0.3, 0.01) var idle_drift_scale: float = 0.03

@export_group("Home Tether")
@export_range(0.1, 10.0, 0.01) var home_radius: float = 1.05
@export_range(0.0, 4.0, 0.01) var home_tether_strength: float = 0.85
@export var use_home_bounds: bool = false
@export var home_bounds_size: Vector3 = Vector3.ZERO
@export_range(0.1, 0.95, 0.01) var home_return_inner_ratio: float = 0.62
@export_range(1.0, 180.0, 1.0) var home_return_turn_degrees_per_second: float = 82.0

@export_group("Obstacle Avoidance")
@export var obstacle_avoidance_enabled: bool = true
@export_flags_3d_physics var obstacle_collision_mask: int = 1
@export_range(0.05, 5.0, 0.01) var obstacle_feeler_length: float = 0.5
@export_range(1.0, 85.0, 1.0) var obstacle_feeler_angle_degrees: float = 34.0
@export_range(0.0, 5.0, 0.01) var obstacle_avoidance_weight: float = 0.72

@export_group("Player Interaction")
@export var avoid_player_body: bool = true
@export var player_group: StringName = &"player"
@export var flee_from_player_hand_feelers: bool = true
@export var player_hand_group: StringName = &"player_hand"
@export_range(0.1, 3.0, 0.01) var player_keepout_radius: float = 0.85
@export_range(0.0, 3.0, 0.01) var player_keepout_strength: float = 0.55
@export_range(0.05, 5.0, 0.01) var player_hand_flee_memory_time: float = 1.1
@export_range(0.1, 10.0, 0.01) var player_hand_flee_safe_radius: float = 1.0
@export_range(0.0, 5.0, 0.01) var player_hand_flee_speed_scale: float = 1.75

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
var _course_direction: Vector3 = Vector3.FORWARD
var _course_time_remaining: float = 0.0
var _course_index: int = 0
var _returning_home: bool = false
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
	_begin_next_course()
	current_wander_direction = _course_direction
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
		if not _returning_home:
			desired_velocity_for_frame = _apply_home_tether(desired_velocity_for_frame)

	desired_velocity_for_frame += _calculate_player_keepout_velocity()
	desired_velocity_for_frame += _calculate_obstacle_avoidance(desired_velocity_for_frame)
	apply_desired_velocity(desired_velocity_for_frame, delta)
	_update_visual()


func _update_wander_direction(delta: float) -> void:
	var target_course_direction: Vector3 = _update_course_target(delta)
	var turn_rate: float = home_return_turn_degrees_per_second if _returning_home else wander_turn_degrees_per_second
	current_wander_direction = _smooth_direction_change(
		current_wander_direction,
		target_course_direction,
		delta,
		wander_smoothing,
		wander_forward_bias,
		turn_rate
	)


func _update_idle_cadence(delta: float) -> void:
	if _is_player_hand_flee_active() or _returning_home:
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
	if use_home_bounds:
		return SteeringHelper.apply_home_box_tether(
			global_position,
			home_position,
			input_desired_velocity,
			max_speed,
			home_bounds_size,
			home_tether_strength
		)

	return SteeringHelper.apply_home_tether(
		global_position,
		home_position,
		input_desired_velocity,
		max_speed,
		home_radius,
		home_tether_strength
	)


func _calculate_obstacle_avoidance(input_desired_velocity: Vector3) -> Vector3:
	if not obstacle_avoidance_enabled:
		_clear_obstacle_avoidance_debug()
		return Vector3.ZERO

	_clear_obstacle_avoidance_debug()
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


func _clear_obstacle_avoidance_debug() -> void:
	obstacle_avoidance_force = Vector3.ZERO
	debug_obstacle_hit = false
	debug_obstacle_hit_position = Vector3.ZERO
	debug_obstacle_hit_normal = Vector3.ZERO


func _calculate_player_keepout_velocity() -> Vector3:
	if not avoid_player_body or not is_inside_tree() or player_keepout_radius <= 0.0:
		return Vector3.ZERO

	var nearest_player: Node3D
	var nearest_distance_sq: float = player_keepout_radius * player_keepout_radius
	for candidate in get_tree().get_nodes_in_group(player_group):
		var player := candidate as Node3D
		if player == null or player.is_in_group(player_hand_group):
			continue

		var distance_sq: float = global_position.distance_squared_to(player.global_position)
		if distance_sq <= nearest_distance_sq:
			nearest_player = player
			nearest_distance_sq = distance_sq

	if nearest_player == null:
		return Vector3.ZERO

	var distance: float = sqrt(nearest_distance_sq)
	var pressure: float = 1.0 - clamp(distance / player_keepout_radius, 0.0, 1.0)
	return PlayerPerceptionHelper.flee_velocity(
		global_position,
		nearest_player,
		current_wander_direction,
		max_speed,
		player_keepout_strength * pressure
	)


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


func _update_course_target(delta: float) -> Vector3:
	if _is_outside_home_area():
		_returning_home = true
	elif _returning_home and _is_securely_inside_home_area():
		_returning_home = false
		_begin_next_course()

	if _returning_home:
		return _home_return_direction()

	_course_time_remaining -= delta
	if _course_time_remaining <= 0.0:
		_begin_next_course()

	return _course_direction


func _begin_next_course() -> void:
	_course_index += 1
	_course_direction = _sample_course_direction()
	_course_time_remaining = _sample_course_duration()


func _sample_course_direction() -> Vector3:
	var phase: float = _wander_seed + float(_course_index) * 2.399
	var forward: Vector3 = _safe_direction(current_wander_direction, direction)
	var side: Vector3 = _side_axis_for(forward)
	var lateral: float = sin(phase) * lateral_wander_amount
	lateral += sin(phase * 0.37 + 1.7) * lateral_wander_amount * 0.35
	var vertical: float = sin(phase * 0.83 + 1.8) * vertical_wander_amount
	var sample: Vector3 = forward + side * lateral + Vector3.UP * vertical
	return _safe_direction(sample, forward)


func _sample_course_duration() -> float:
	var min_duration: float = minf(course_duration_min, course_duration_max)
	var max_duration: float = maxf(course_duration_min, course_duration_max)
	var t: float = (sin(_wander_seed * 3.17 + float(_course_index) * 1.41) + 1.0) * 0.5
	return lerpf(min_duration, max_duration, t)


func _is_outside_home_area() -> bool:
	return SteeringHelper.is_outside_home_area(
		global_position,
		home_position,
		home_radius,
		use_home_bounds,
		home_bounds_size
	)


func _is_securely_inside_home_area() -> bool:
	return SteeringHelper.is_inside_home_area(
		global_position,
		home_position,
		home_radius,
		use_home_bounds,
		home_bounds_size,
		home_return_inner_ratio
	)


func _home_return_direction() -> Vector3:
	return SteeringHelper.home_return_direction(
		global_position,
		home_position,
		-current_wander_direction,
		home_radius,
		use_home_bounds,
		home_bounds_size,
		home_return_inner_ratio
	)
