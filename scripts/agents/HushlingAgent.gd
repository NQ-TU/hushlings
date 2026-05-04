extends "res://scripts/agents/AgentMotor3D.gd"
class_name HushlingAgent

const PerceptionHelper := preload("res://scripts/perception/AgentPerception.gd")
const BoidsHelper := preload("res://scripts/steering/Boids.gd")
const ObstacleAvoidanceHelper := preload("res://scripts/steering/ObstacleAvoidance.gd")
const HushlingStateMachine := preload("res://scripts/fsm/HushlingStateMachine.gd")
const HushlingProfileResource := preload("res://scripts/profiles/HushlingProfile.gd")

enum SteeringMode {
	AUTO,
	WANDER,
	SEEK,
	ARRIVE,
	FLEE,
}

@export_group("Debug")
@export var agent_debug_enabled: bool = true

@export_group("Profile")
@export var profile: HushlingProfileResource

@export_group("Steering Test Modes")
@export var steering_mode: SteeringMode = SteeringMode.AUTO
@export var enable_keyboard_mode_switching: bool = true
@export var seek_target_path: NodePath
@export var arrive_target_path: NodePath
@export var flee_threat_path: NodePath
@export_range(0.05, 5.0, 0.01) var arrive_slowing_radius: float = 0.8
@export var apply_home_tether_in_test_modes: bool = true

@export_group("Minimal Autonomous Test")
@export var autonomous_enabled: bool = true
@export var use_group_perception: bool = true
@export var interest_group: StringName = &"interest_entity"
@export var threat_group: StringName = &"threat_entity"
@export var interest_target_path: NodePath
@export var threat_target_path: NodePath
@export_range(0.1, 10.0, 0.01) var awareness_radius: float = 2.0
@export_range(0.1, 10.0, 0.01) var observe_distance: float = 0.65
@export_range(0.05, 10.0, 0.01) var interest_flee_radius: float = 0.8
@export_range(0.0, 5.0, 0.01) var interest_flee_clearance: float = 0.2
@export_range(0.05, 10.0, 0.01) var flee_radius: float = 0.7
@export_range(0.1, 10.0, 0.01) var flee_safe_radius: float = 1.35
@export_range(0.05, 1.0, 0.01) var calm_speed_scale: float = 0.45
@export_range(0.0, 5.0, 0.01) var observe_speed_scale: float = 0.42
@export_range(0.05, 1.0, 0.01) var observe_speed_limit_scale: float = 0.32
@export_range(0.0, 5.0, 0.01) var flee_speed_scale: float = 1.0

@export_group("Flee Breakup")
@export_range(0.0, 2.0, 0.01) var flee_breakup_strength: float = 0.38
@export_range(0.0, 1.0, 0.01) var flee_breakup_sway_strength: float = 0.12
@export_range(0.01, 2.0, 0.01) var flee_breakup_sway_frequency: float = 0.34
@export_range(0.0, 1.0, 0.01) var flee_breakup_vertical_strength: float = 0.12
@export_range(0.0, 3.0, 0.01) var flee_separation_multiplier: float = 1.35
@export_range(0.0, 1.0, 0.01) var flee_cohesion_multiplier: float = 0.12
@export_range(0.0, 1.0, 0.01) var flee_alignment_multiplier: float = 0.0

@export_group("Social Response")
@export var social_flee_scaling_enabled: bool = true
@export_range(1, 8, 1) var supported_group_size: int = 3
@export_range(0.05, 10.0, 0.01) var isolated_interest_flee_radius: float = 1.6
@export_range(0.05, 10.0, 0.01) var isolated_interest_gaze_flee_radius: float = 2.4
@export_range(0.05, 10.0, 0.01) var isolated_threat_flee_radius: float = 1.4
@export_range(0.1, 10.0, 0.01) var isolated_flee_safe_radius: float = 2.25
@export_range(0.1, 8.0, 0.01) var regroup_radius: float = 2.0
@export_range(0.0, 3.0, 0.01) var regroup_strength: float = 0.16
@export_range(0.0, 1.0, 0.01) var regroup_loneliness_threshold: float = 0.45
@export_range(0.05, 1.0, 0.01) var regroup_speed_scale: float = 0.34

@export_group("Visibility")
@export var require_interest_los_to_observe: bool = true
@export var use_raycast_line_of_sight: bool = true
@export_flags_3d_physics var perception_los_collision_mask: int = 1
@export_range(0.0, 0.5, 0.01) var perception_los_end_margin: float = 0.04
@export_range(1.0, 360.0, 1.0) var interest_fov_degrees: float = 145.0
@export var flee_if_interest_sees_agent: bool = true
@export_range(1.0, 360.0, 1.0) var interest_gaze_fov_degrees: float = 115.0
@export_range(0.05, 10.0, 0.01) var interest_gaze_flee_radius: float = 1.45

@export_group("Obstacle Avoidance")
@export var obstacle_avoidance_enabled: bool = true
@export_flags_3d_physics var obstacle_collision_mask: int = 1
@export_range(0.05, 5.0, 0.01) var obstacle_feeler_length: float = 0.55
@export_range(1.0, 85.0, 1.0) var obstacle_feeler_angle_degrees: float = 34.0
@export_range(0.0, 5.0, 0.01) var obstacle_avoidance_weight: float = 0.82

@export_group("Internal Variables")
@export_range(0.0, 1.0, 0.01) var fear: float = 0.0
@export_range(0.0, 1.0, 0.01) var curiosity: float = 0.0
@export_range(0.0, 1.0, 0.01) var confidence: float = 0.0
@export_range(0.0, 1.0, 0.01) var loneliness: float = 0.0
@export_range(0.0, 1.0, 0.01) var energy: float = 1.0
@export_range(0.0, 3.0, 0.01) var fear_rise_rate: float = 1.2
@export_range(0.0, 3.0, 0.01) var fear_decay_rate: float = 0.35
@export_range(0.0, 3.0, 0.01) var curiosity_rise_rate: float = 0.55
@export_range(0.0, 3.0, 0.01) var curiosity_decay_rate: float = 0.4
@export_range(0.0, 3.0, 0.01) var confidence_rise_rate: float = 0.35
@export_range(0.0, 3.0, 0.01) var confidence_decay_rate: float = 0.24
@export_range(0.0, 3.0, 0.01) var loneliness_rise_rate: float = 0.38
@export_range(0.0, 3.0, 0.01) var loneliness_decay_rate: float = 0.7
@export_range(0.0, 3.0, 0.01) var energy_recovery_rate: float = 0.14
@export_range(0.0, 3.0, 0.01) var energy_drain_rate: float = 0.18
@export_range(0.0, 1.0, 0.01) var fear_flee_threshold: float = 0.72
@export_range(0.0, 1.0, 0.01) var curiosity_observe_threshold: float = 0.22
@export_range(0.0, 1.0, 0.01) var confidence_fear_resistance: float = 0.18

@export_group("Wander")
@export_range(0.0, 2.0, 0.01) var wander_strength: float = 0.86
@export_range(0.01, 3.0, 0.01) var wander_frequency: float = 0.18
@export_range(0.01, 10.0, 0.01) var wander_smoothing: float = 1.25
@export_range(0.0, 1.0, 0.01) var vertical_wander_amount: float = 0.24

@export_group("Home Tether")
@export_range(0.1, 10.0, 0.01) var home_radius: float = 1.25
@export_range(0.0, 4.0, 0.01) var home_tether_strength: float = 0.72

@export_group("Social Boids")
@export var social_forces_enabled: bool = true
@export var separation_enabled: bool = true
@export var neighbour_group: StringName = &"hushling"
@export_range(0.01, 3.0, 0.01) var separation_radius: float = 0.38
@export_range(0.0, 5.0, 0.01) var separation_weight: float = 0.85
@export_range(0.0, 3.0, 0.01) var separation_prediction_time: float = 0.7
@export_range(0.01, 5.0, 0.01) var group_radius: float = 1.3
@export_range(0.0, 5.0, 0.01) var cohesion_weight: float = 0.12
@export_range(0.0, 5.0, 0.01) var alignment_weight: float = 0.05
@export var group_flee_enabled: bool = true
@export_range(0.01, 5.0, 0.01) var group_flee_radius: float = 1.35
@export_range(0.05, 5.0, 0.01) var group_flee_memory_time: float = 1.2
@export_group("Individual Variation")
@export_range(0.0, 1.0, 0.01) var per_agent_variation: float = 0.18

var home_position: Vector3 = Vector3.ZERO
var current_wander_direction: Vector3 = Vector3.FORWARD
var current_state: String = "WANDER"
var separation_force: Vector3 = Vector3.ZERO
var cohesion_force: Vector3 = Vector3.ZERO
var alignment_force: Vector3 = Vector3.ZERO
var regroup_force: Vector3 = Vector3.ZERO
var obstacle_avoidance_force: Vector3 = Vector3.ZERO
var debug_neighbour_count: int = 0
var debug_has_target: bool = false
var debug_target_position: Vector3 = Vector3.ZERO
var debug_target_name: String = ""
var debug_interest_distance: float = -1.0
var debug_threat_distance: float = -1.0
var debug_interest_visible: bool = false
var debug_interest_sees_agent: bool = false
var debug_interest_in_fov: bool = false
var debug_interest_los_clear: bool = false
var debug_interest_gaze_in_fov: bool = false
var debug_interest_gaze_los_clear: bool = false
var debug_group_support: float = 0.0
var debug_isolation_factor: float = 1.0
var debug_effective_interest_flee_radius: float = 0.0
var debug_effective_gaze_flee_radius: float = 0.0
var debug_effective_threat_flee_radius: float = 0.0
var debug_effective_flee_safe_radius: float = 0.0
var debug_obstacle_hit: bool = false
var debug_obstacle_hit_position: Vector3 = Vector3.ZERO
var debug_obstacle_hit_normal: Vector3 = Vector3.ZERO

var _elapsed_time: float = 0.0
var _wander_seed: float = 0.0
var _seek_target: Node3D
var _arrive_target: Node3D
var _flee_threat: Node3D
var _interest_target: Node3D
var _threat_target: Node3D
var _autonomous_flee_target: Node3D
var _autonomous_flee_clear_distance: float = 0.0
var _group_flee_source: Node3D
var _group_flee_time_remaining: float = 0.0
var _autonomous_state: int = HushlingStateMachine.WANDER
var _separation_fallback_direction: Vector3 = Vector3.RIGHT
var _flee_breakup_axis: Vector3 = Vector3.RIGHT
var _speed_variation: float = 1.0
var _wander_variation: float = 1.0
var _cohesion_variation: float = 1.0
var _alignment_variation: float = 1.0


func _ready() -> void:
	_apply_profile()
	home_position = global_position
	_wander_seed = _seed_from_name()
	_setup_individual_variation()
	current_wander_direction = _sample_wander_direction(0.0)
	_separation_fallback_direction = _sample_wander_direction(0.37)
	_flee_breakup_axis = _sample_wander_direction(1.19)
	direction = current_wander_direction
	target_direction = current_wander_direction
	_apply_debug_visibility()
	_resolve_target_nodes()


func _process(delta: float) -> void:
	_elapsed_time += delta
	_update_group_flee_memory(delta)
	_update_wander_direction(delta)
	_resolve_missing_target_nodes()
	_update_perception_targets()
	_update_autonomous_state(delta)

	var desired: Vector3 = _calculate_desired_velocity()
	desired = _apply_home_tether(desired)
	desired += _calculate_regroup_force()
	desired += _calculate_social_forces()
	desired += _calculate_obstacle_avoidance(desired)
	desired = SteeringHelper.limit_vector(desired, _get_active_speed_limit())
	apply_desired_velocity(desired, delta)


func _unhandled_input(event: InputEvent) -> void:
	if not enable_keyboard_mode_switching:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_0:
				set_steering_mode(SteeringMode.AUTO)
			KEY_1:
				set_steering_mode(SteeringMode.WANDER)
			KEY_2:
				set_steering_mode(SteeringMode.SEEK)
			KEY_3:
				set_steering_mode(SteeringMode.ARRIVE)
			KEY_4:
				set_steering_mode(SteeringMode.FLEE)


func set_steering_mode(mode: SteeringMode) -> void:
	steering_mode = mode
	_update_current_state_label()


func _apply_profile() -> void:
	if profile:
		profile.apply_to(self)


func _apply_debug_visibility() -> void:
	var debug_draw: Node = get_node_or_null("AgentDebugDraw")
	if debug_draw:
		debug_draw.set(&"debug_enabled", agent_debug_enabled)


func _update_wander_direction(delta: float) -> void:
	var sampled_direction: Vector3 = _sample_wander_direction(_elapsed_time)
	var alpha: float = 1.0 - exp(-wander_smoothing * delta)
	current_wander_direction = current_wander_direction.lerp(sampled_direction, alpha)
	current_wander_direction = _safe_direction(current_wander_direction, Vector3.FORWARD)


func _calculate_desired_velocity() -> Vector3:
	_set_debug_target(null)
	_update_current_state_label()

	match steering_mode:
		SteeringMode.SEEK:
			if _seek_target:
				_set_debug_target(_seek_target)
				return SteeringHelper.seek(global_position, _seek_target.global_position, max_speed)
		SteeringMode.ARRIVE:
			if _arrive_target:
				_set_debug_target(_arrive_target)
				return SteeringHelper.arrive(
					global_position,
					_arrive_target.global_position,
					max_speed,
					arrive_slowing_radius
				)
		SteeringMode.FLEE:
			if _flee_threat:
				_set_debug_target(_flee_threat)
				return _calculate_flee_velocity(_flee_threat)
		SteeringMode.AUTO:
			return _calculate_autonomous_desired_velocity()
		SteeringMode.WANDER:
			return _calculate_wander_velocity()

	return _calculate_wander_velocity()


func _calculate_autonomous_desired_velocity() -> Vector3:
	match _autonomous_state:
		HushlingStateMachine.FLEE:
			var flee_target: Node3D = _get_autonomous_flee_target()
			if flee_target:
				_set_debug_target(flee_target)
				return _calculate_flee_velocity(flee_target)
		HushlingStateMachine.OBSERVE:
			if _interest_target:
				_set_debug_target(_interest_target)
				return _calculate_observe_velocity(_interest_target.global_position)
		HushlingStateMachine.WANDER:
			return _calculate_wander_velocity()

	return _calculate_wander_velocity()


func _calculate_wander_velocity() -> Vector3:
	return current_wander_direction * max_speed * wander_strength * _wander_variation


func _calculate_observe_velocity(target_position: Vector3) -> Vector3:
	var to_target: Vector3 = target_position - global_position
	var distance_to_target: float = to_target.length()
	if distance_to_target <= 0.0001:
		return Vector3.ZERO

	var from_target: Vector3 = -to_target / distance_to_target
	var stand_off_position: Vector3 = target_position + from_target * observe_distance
	return SteeringHelper.arrive(
		global_position,
		stand_off_position,
		max_speed * observe_speed_scale,
		arrive_slowing_radius
	)


func _calculate_flee_velocity(flee_target: Node3D) -> Vector3:
	var away_from_target: Vector3 = global_position - flee_target.global_position
	var flee_direction: Vector3 = _safe_direction(away_from_target, _separation_fallback_direction)
	var lane_direction: Vector3 = _get_flee_breakup_direction(flee_direction)
	var sway: float = sin(_elapsed_time * TAU * flee_breakup_sway_frequency + _wander_seed * 1.73) \
			* flee_breakup_sway_strength
	var inherited_flee_scale: float = 1.2 if _group_flee_source != null else 1.0
	var vertical_sign: float = 1.0 if sin(_wander_seed * 2.11) >= 0.0 else -1.0
	var breakup: Vector3 = lane_direction * (flee_breakup_strength + sway) * inherited_flee_scale
	var vertical_breakup: Vector3 = Vector3.UP * vertical_sign * flee_breakup_vertical_strength
	var escape_direction: Vector3 = _safe_direction(
		flee_direction + breakup + vertical_breakup,
		flee_direction
	)

	return escape_direction * max_speed * flee_speed_scale


func _get_flee_breakup_direction(flee_direction: Vector3) -> Vector3:
	var lane_direction: Vector3 = _flee_breakup_axis - flee_direction * _flee_breakup_axis.dot(flee_direction)
	if lane_direction.length_squared() > 0.0001:
		return lane_direction.normalized()

	lane_direction = Vector3.UP.cross(flee_direction)
	if lane_direction.length_squared() > 0.0001:
		return lane_direction.normalized()

	return _safe_direction(Vector3.RIGHT.cross(flee_direction), Vector3.RIGHT)


func _apply_home_tether(input_desired_velocity: Vector3) -> Vector3:
	if not _should_apply_home_tether():
		return input_desired_velocity

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


func _should_apply_home_tether() -> bool:
	if steering_mode == SteeringMode.AUTO:
		return _autonomous_state != HushlingStateMachine.FLEE

	if steering_mode == SteeringMode.WANDER:
		return true

	return apply_home_tether_in_test_modes


func _calculate_social_forces() -> Vector3:
	if not social_forces_enabled or not is_inside_tree():
		separation_force = Vector3.ZERO
		cohesion_force = Vector3.ZERO
		alignment_force = Vector3.ZERO
		debug_neighbour_count = 0
		_update_social_response_debug_values()
		return Vector3.ZERO

	var neighbours: Array = get_tree().get_nodes_in_group(neighbour_group)
	var separation_multiplier: float = flee_separation_multiplier if _is_flee_state_active() else 1.0
	var cohesion_multiplier: float = flee_cohesion_multiplier if _is_flee_state_active() else 1.0
	var alignment_multiplier: float = flee_alignment_multiplier if _is_flee_state_active() else 1.0
	if separation_enabled:
		separation_force = BoidsHelper.separation(
			self,
			neighbours,
			separation_radius,
			max_speed,
			_separation_fallback_direction,
			separation_prediction_time
		) * separation_weight * separation_multiplier
	else:
		separation_force = Vector3.ZERO
	cohesion_force = BoidsHelper.cohesion(
		self,
		neighbours,
		group_radius,
		max_speed
	) * cohesion_weight * _cohesion_variation * cohesion_multiplier
	alignment_force = BoidsHelper.alignment(
		self,
		neighbours,
		group_radius,
		max_speed
	) * alignment_weight * _alignment_variation * alignment_multiplier
	debug_neighbour_count = BoidsHelper.neighbour_count(self, neighbours, group_radius)
	_update_social_response_debug_values()

	return separation_force + cohesion_force + alignment_force


func _calculate_regroup_force() -> Vector3:
	regroup_force = Vector3.ZERO
	if not social_forces_enabled or not is_inside_tree():
		return Vector3.ZERO
	if _is_flee_state_active() or loneliness < regroup_loneliness_threshold:
		return Vector3.ZERO

	var neighbours: Array = get_tree().get_nodes_in_group(neighbour_group)
	if BoidsHelper.neighbour_count(self, neighbours, regroup_radius) <= 0:
		return Vector3.ZERO

	var loneliness_factor: float = inverse_lerp(regroup_loneliness_threshold, 1.0, loneliness)
	var regroup_velocity: Vector3 = BoidsHelper.cohesion(
		self,
		neighbours,
		regroup_radius,
		max_speed * regroup_speed_scale
	)
	regroup_force = regroup_velocity \
			* regroup_strength \
			* clamp(loneliness_factor, 0.0, 1.0) \
			* max(_get_isolation_factor(), 0.25)
	return regroup_force


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
	return obstacle_avoidance_force


func _update_autonomous_state(delta: float) -> void:
	debug_interest_distance = _distance_to_or_negative(_interest_target)
	debug_threat_distance = _distance_to_or_negative(_threat_target)
	debug_interest_visible = _can_observe_interest_target()
	debug_interest_sees_agent = _interest_target_has_los_to_agent()
	_update_social_response_debug_values()
	_update_internal_variables(delta)

	if not autonomous_enabled:
		return

	if _autonomous_state == HushlingStateMachine.FLEE:
		var flee_target: Node3D = _get_autonomous_flee_target()
		if not HushlingStateMachine.is_safe_to_stop_fleeing(_build_state_facts(flee_target)):
			return
		_clear_group_flee_memory()
		_autonomous_flee_target = null
		_autonomous_flee_clear_distance = 0.0
		_autonomous_state = HushlingStateMachine.WANDER

	var group_flee_source: Node3D = _find_group_flee_source()
	var facts: Dictionary = _build_state_facts(_get_autonomous_flee_target(), group_flee_source)
	match HushlingStateMachine.choose_state(_autonomous_state, facts):
		HushlingStateMachine.FLEE:
			_enter_flee_state(group_flee_source)
		HushlingStateMachine.OBSERVE:
			_autonomous_state = HushlingStateMachine.OBSERVE
		_:
			_autonomous_state = HushlingStateMachine.WANDER


func _build_state_facts(flee_target: Node3D = null, group_flee_source: Node3D = null) -> Dictionary:
	return {
		"has_interest": _interest_target != null,
		"interest_distance": debug_interest_distance,
		"threat_distance": debug_threat_distance,
		"interest_visible": debug_interest_visible,
		"interest_sees_agent": debug_interest_sees_agent,
		"interest_flee_radius": _get_effective_interest_flee_radius(),
		"interest_gaze_flee_radius": _get_effective_interest_gaze_flee_radius(),
		"threat_flee_radius": _get_effective_threat_flee_radius(),
		"flee_target_distance": _distance_to_or_negative(flee_target),
		"flee_safe_radius": _get_flee_safe_distance(flee_target),
		"awareness_radius": awareness_radius,
		"curiosity": curiosity,
		"curiosity_observe_threshold": curiosity_observe_threshold,
		"effective_fear": _get_effective_fear(),
		"fear_flee_threshold": fear_flee_threshold,
		"group_flee_active": group_flee_source != null,
	}


func _enter_flee_state(group_flee_source: Node3D = null) -> void:
	if _threat_target and debug_threat_distance <= _get_effective_threat_flee_radius():
		_clear_group_flee_memory()
		_autonomous_flee_clear_distance = _get_effective_flee_safe_radius(_threat_target)
		_autonomous_flee_target = _threat_target
	elif _interest_target and debug_interest_visible and debug_interest_distance <= _get_effective_interest_flee_radius():
		_clear_group_flee_memory()
		_autonomous_flee_clear_distance = _get_close_interest_flee_safe_distance()
		_autonomous_flee_target = _interest_target
	elif debug_interest_sees_agent and _get_effective_fear() >= fear_flee_threshold:
		_clear_group_flee_memory()
		_autonomous_flee_clear_distance = _get_effective_interest_gaze_flee_radius() + interest_flee_clearance
		_autonomous_flee_target = _interest_target
	elif group_flee_source:
		_group_flee_source = group_flee_source
		_group_flee_time_remaining = group_flee_memory_time
		_autonomous_flee_clear_distance = _get_group_flee_clear_distance(group_flee_source)
		_autonomous_flee_target = group_flee_source
	else:
		return

	_autonomous_state = HushlingStateMachine.FLEE


func _update_internal_variables(delta: float) -> void:
	fear = _move_emotion_toward(fear, _get_fear_target(), fear_rise_rate, fear_decay_rate, delta)
	curiosity = _move_emotion_toward(
		curiosity,
		_get_curiosity_target(),
		curiosity_rise_rate,
		curiosity_decay_rate,
		delta
	)
	confidence = _move_emotion_toward(
		confidence,
		_get_confidence_target(),
		confidence_rise_rate,
		confidence_decay_rate,
		delta
	)
	loneliness = _move_emotion_toward(
		loneliness,
		_get_loneliness_target(),
		loneliness_rise_rate,
		loneliness_decay_rate,
		delta
	)
	energy = _move_emotion_toward(energy, _get_energy_target(), energy_recovery_rate, energy_drain_rate, delta)


func _move_emotion_toward(
	current_value: float,
	target_value: float,
	rise_rate: float,
	decay_rate: float,
	delta: float
) -> float:
	var rate: float = rise_rate if target_value > current_value else decay_rate
	return clamp(move_toward(current_value, target_value, rate * delta), 0.0, 1.0)


func _get_fear_target() -> float:
	var target_fear: float = 0.0

	if _autonomous_state == HushlingStateMachine.FLEE or _group_flee_time_remaining > 0.0:
		target_fear = max(target_fear, 0.72)

	if _threat_target and debug_threat_distance >= 0.0:
		var effective_threat_flee_radius: float = _get_effective_threat_flee_radius()
		var effective_safe_radius: float = _get_effective_flee_safe_radius(_threat_target)
		if debug_threat_distance <= effective_threat_flee_radius:
			target_fear = max(target_fear, 1.0)
		elif debug_threat_distance <= effective_safe_radius:
			target_fear = max(target_fear, 0.45)

	if _interest_target and debug_interest_distance >= 0.0 and debug_interest_visible:
		var effective_interest_flee_radius: float = _get_effective_interest_flee_radius()
		var effective_gaze_flee_radius: float = _get_effective_interest_gaze_flee_radius()
		if debug_interest_distance <= effective_interest_flee_radius:
			target_fear = max(target_fear, 1.0)
		elif debug_interest_sees_agent:
			var gaze_range: float = max(effective_gaze_flee_radius - effective_interest_flee_radius, 0.001)
			var proximity: float = 1.0 - clamp(
				(debug_interest_distance - effective_interest_flee_radius) / gaze_range,
				0.0,
				1.0
			)
			target_fear = max(target_fear, lerp(0.68, 1.0, proximity))

	return target_fear


func _get_curiosity_target() -> float:
	if _interest_target == null or not debug_interest_visible:
		return 0.0
	if debug_interest_distance < 0.0 or debug_interest_distance > awareness_radius:
		return 0.0
	if debug_interest_distance <= _get_effective_interest_flee_radius():
		return 0.0
	if _get_effective_fear() >= fear_flee_threshold:
		return 0.0

	var distance_factor: float = 1.0 - clamp(
		(debug_interest_distance - observe_distance) / max(awareness_radius - observe_distance, 0.001),
		0.0,
		1.0
	)
	return clamp(0.25 + distance_factor * 0.55 + confidence * 0.2, 0.0, 1.0)


func _get_confidence_target() -> float:
	var group_factor: float = _get_group_support()
	var fear_penalty: float = fear * 0.65
	return clamp(group_factor - fear_penalty, 0.0, 1.0)


func _get_loneliness_target() -> float:
	return 1.0 - _get_group_support()


func _get_energy_target() -> float:
	if _autonomous_state == HushlingStateMachine.FLEE:
		return 0.55
	return 1.0


func _get_effective_fear() -> float:
	return clamp(fear - confidence * confidence_fear_resistance, 0.0, 1.0)


func _get_group_support() -> float:
	var required_neighbours: int = max(supported_group_size - 1, 1)
	return clamp(float(debug_neighbour_count) / float(required_neighbours), 0.0, 1.0)


func _get_isolation_factor() -> float:
	return 1.0 - _get_group_support()


func _get_effective_interest_flee_radius() -> float:
	if not social_flee_scaling_enabled:
		return interest_flee_radius

	return lerp(
		interest_flee_radius,
		max(interest_flee_radius, isolated_interest_flee_radius),
		_get_isolation_factor()
	)


func _get_effective_interest_gaze_flee_radius() -> float:
	if not social_flee_scaling_enabled:
		return interest_gaze_flee_radius

	return lerp(
		interest_gaze_flee_radius,
		max(interest_gaze_flee_radius, isolated_interest_gaze_flee_radius),
		_get_isolation_factor()
	)


func _get_effective_threat_flee_radius() -> float:
	if not social_flee_scaling_enabled:
		return flee_radius

	return lerp(
		flee_radius,
		max(flee_radius, isolated_threat_flee_radius),
		_get_isolation_factor()
	)


func _get_effective_flee_safe_radius(_flee_target: Node3D = null) -> float:
	if not social_flee_scaling_enabled:
		return flee_safe_radius

	return lerp(
		flee_safe_radius,
		max(flee_safe_radius, isolated_flee_safe_radius),
		_get_isolation_factor()
	)


func _update_social_response_debug_values() -> void:
	debug_group_support = _get_group_support()
	debug_isolation_factor = _get_isolation_factor()
	debug_effective_interest_flee_radius = _get_effective_interest_flee_radius()
	debug_effective_gaze_flee_radius = _get_effective_interest_gaze_flee_radius()
	debug_effective_threat_flee_radius = _get_effective_threat_flee_radius()
	debug_effective_flee_safe_radius = _get_effective_flee_safe_radius()


func _update_current_state_label() -> void:
	if steering_mode != SteeringMode.AUTO:
		current_state = _mode_to_string(steering_mode)
		return

	current_state = HushlingStateMachine.state_name(_autonomous_state)


func _resolve_missing_target_nodes() -> void:
	if _target_needs_resolve(seek_target_path, _seek_target) \
			or _target_needs_resolve(arrive_target_path, _arrive_target) \
			or _target_needs_resolve(flee_threat_path, _flee_threat):
		_resolve_target_nodes()


func _resolve_target_nodes() -> void:
	_seek_target = _get_node3d_or_null(seek_target_path)
	_arrive_target = _get_node3d_or_null(arrive_target_path)
	_flee_threat = _get_node3d_or_null(flee_threat_path)


func _update_perception_targets() -> void:
	_interest_target = _get_node3d_or_null(interest_target_path)
	_threat_target = _get_node3d_or_null(threat_target_path)

	if not use_group_perception:
		return

	if _interest_target == null:
		_interest_target = PerceptionHelper.nearest_in_group(
			self,
			interest_group,
			_get_interest_perception_radius()
		)

	if _threat_target == null:
		_threat_target = PerceptionHelper.nearest_in_group(
			self,
			threat_group,
			max(_get_effective_flee_safe_radius(), _get_effective_threat_flee_radius())
		)


func _get_node3d_or_null(path: NodePath) -> Node3D:
	if path == NodePath():
		return null
	return get_node_or_null(path) as Node3D


func _target_needs_resolve(path: NodePath, target: Node3D) -> bool:
	return path != NodePath() and not is_instance_valid(target)


func _set_debug_target(target: Node3D) -> void:
	debug_has_target = target != null
	if target == null:
		debug_target_position = Vector3.ZERO
		debug_target_name = ""
		return

	debug_target_position = target.global_position
	debug_target_name = target.name


func _distance_to_or_negative(target: Node3D) -> float:
	return PerceptionHelper.distance_to_or_negative(self, target)


func is_fleeing() -> bool:
	return _is_flee_state_active()


func _is_flee_state_active() -> bool:
	if steering_mode == SteeringMode.FLEE:
		return true

	return steering_mode == SteeringMode.AUTO and _autonomous_state == HushlingStateMachine.FLEE


func is_propagating_flee() -> bool:
	if not is_fleeing():
		return false

	return _group_flee_source == null


func get_flee_source() -> Node3D:
	return _get_autonomous_flee_target()


func get_flee_clear_distance() -> float:
	return _get_flee_safe_distance(_get_autonomous_flee_target())


func _find_group_flee_source() -> Node3D:
	if not group_flee_enabled or not is_inside_tree():
		return null

	var nearest_source: Node3D
	var nearest_distance_sq: float = group_flee_radius * group_flee_radius
	for candidate in get_tree().get_nodes_in_group(neighbour_group):
		var neighbour := candidate as Node3D
		if neighbour == null or neighbour == self:
			continue

		var distance_sq: float = global_position.distance_squared_to(neighbour.global_position)
		if distance_sq > nearest_distance_sq:
			continue

		if not neighbour.has_method(&"is_propagating_flee") \
				or not bool(neighbour.call(&"is_propagating_flee")):
			continue

		nearest_distance_sq = distance_sq
		nearest_source = neighbour.call(&"get_flee_source") as Node3D
		if nearest_source == null:
			nearest_source = neighbour

	return nearest_source


func _get_group_flee_clear_distance(group_flee_source: Node3D) -> float:
	for candidate in get_tree().get_nodes_in_group(neighbour_group):
		var neighbour := candidate as Node3D
		if neighbour == null or neighbour == self:
			continue
		if not neighbour.has_method(&"is_propagating_flee") \
				or not bool(neighbour.call(&"is_propagating_flee")):
			continue

		var neighbour_source := neighbour.call(&"get_flee_source") as Node3D
		if neighbour_source != group_flee_source:
			continue
		if neighbour.has_method(&"get_flee_clear_distance"):
			var clear_distance: float = float(neighbour.call(&"get_flee_clear_distance"))
			if clear_distance > 0.0:
				return clear_distance

	return _get_flee_safe_distance(group_flee_source)


func _update_group_flee_memory(delta: float) -> void:
	if _group_flee_time_remaining <= 0.0:
		_group_flee_source = null
		return

	_group_flee_time_remaining = max(_group_flee_time_remaining - delta, 0.0)
	if _group_flee_time_remaining <= 0.0:
		_group_flee_source = null


func _clear_group_flee_memory() -> void:
	_group_flee_source = null
	_group_flee_time_remaining = 0.0


func _get_autonomous_flee_target() -> Node3D:
	if is_instance_valid(_autonomous_flee_target):
		return _autonomous_flee_target

	if _threat_target:
		return _threat_target

	return _flee_threat


func _get_flee_safe_distance(flee_target: Node3D) -> float:
	if _autonomous_flee_clear_distance > 0.0:
		return _autonomous_flee_clear_distance

	if flee_target and flee_target.is_in_group(interest_group):
		return _get_close_interest_flee_safe_distance()

	return _get_effective_flee_safe_radius(flee_target)


func _get_close_interest_flee_safe_distance() -> float:
	return max(
		observe_distance,
		_get_effective_interest_flee_radius(),
		_get_effective_flee_safe_radius(_interest_target)
	) + interest_flee_clearance


func _get_interest_perception_radius() -> float:
	if flee_if_interest_sees_agent:
		return max(awareness_radius, _get_effective_interest_gaze_flee_radius())

	return awareness_radius


func _can_observe_interest_target() -> bool:
	debug_interest_in_fov = false
	debug_interest_los_clear = false
	if _interest_target == null:
		return false
	if debug_interest_distance < 0.0 or debug_interest_distance > awareness_radius:
		return false
	if not require_interest_los_to_observe:
		debug_interest_in_fov = true
		debug_interest_los_clear = true
		return true

	debug_interest_in_fov = _is_target_in_fov(self, _interest_target, interest_fov_degrees)
	if not debug_interest_in_fov:
		return false

	debug_interest_los_clear = _has_perception_line_of_sight(self, _interest_target)
	return debug_interest_los_clear


func _interest_target_has_los_to_agent() -> bool:
	debug_interest_gaze_in_fov = false
	debug_interest_gaze_los_clear = false
	if not flee_if_interest_sees_agent or _interest_target == null:
		return false
	if debug_interest_distance < 0.0 or debug_interest_distance > _get_effective_interest_gaze_flee_radius():
		return false

	debug_interest_gaze_in_fov = _is_target_in_fov(_interest_target, self, interest_gaze_fov_degrees)
	if not debug_interest_gaze_in_fov:
		return false

	debug_interest_gaze_los_clear = _has_perception_line_of_sight(_interest_target, self)
	return debug_interest_gaze_los_clear


func _has_perception_line_of_sight(observer: Node3D, target: Node3D) -> bool:
	if not use_raycast_line_of_sight:
		return true

	return PerceptionHelper.has_line_of_sight(
		observer,
		target,
		perception_los_collision_mask,
		Vector3.ZERO,
		Vector3.ZERO,
		perception_los_end_margin
	)


func _is_target_in_fov(observer: Node3D, target: Node3D, fov_degrees: float) -> bool:
	if observer == null or target == null:
		return false
	if fov_degrees >= 359.0:
		return true

	var to_target: Vector3 = target.global_position - observer.global_position
	if to_target.length_squared() <= 0.0001:
		return true

	var forward: Vector3 = _get_agent_forward(observer)
	var dot_to_target: float = clamp(forward.dot(to_target.normalized()), -1.0, 1.0)
	var fov_threshold: float = cos(deg_to_rad(fov_degrees * 0.5))
	return dot_to_target >= fov_threshold


func _get_agent_forward(agent: Node3D) -> Vector3:
	var direction_value: Variant = agent.get(&"direction")
	if direction_value is Vector3 and direction_value.length_squared() > 0.0001:
		return direction_value.normalized()

	return (-agent.global_transform.basis.z).normalized()


func _get_active_speed_limit() -> float:
	if _is_flee_state_active():
		return max_speed * flee_speed_scale

	if steering_mode == SteeringMode.AUTO and _autonomous_state == HushlingStateMachine.OBSERVE:
		return max_speed * observe_speed_limit_scale * _speed_variation

	return max_speed * calm_speed_scale * _speed_variation


func _setup_individual_variation() -> void:
	_speed_variation = _variation_multiplier(11.0)
	_wander_variation = _variation_multiplier(23.0)
	_cohesion_variation = _variation_multiplier(37.0)
	_alignment_variation = _variation_multiplier(51.0)


func _variation_multiplier(offset: float) -> float:
	if per_agent_variation <= 0.0:
		return 1.0

	var sample: float = sin(_wander_seed + offset)
	return 1.0 + sample * per_agent_variation


func _sample_wander_direction(time: float) -> Vector3:
	var phase: float = time * TAU * wander_frequency + _wander_seed
	var sample: Vector3 = Vector3(
		sin(phase * 0.83),
		sin(phase * 1.37 + 1.4) * vertical_wander_amount,
		cos(phase * 0.67 + 0.8)
	)

	return _safe_direction(sample, Vector3.FORWARD)


func _seed_from_name() -> float:
	var seed_text: String = "%s:%s" % [name, str(get_instance_id())]
	var seed_value: int = abs(hash(seed_text)) % 10000
	return float(seed_value) / 10000.0 * TAU


func _mode_to_string(mode: SteeringMode) -> String:
	match mode:
		SteeringMode.AUTO:
			return "AUTO"
		SteeringMode.SEEK:
			return "SEEK"
		SteeringMode.ARRIVE:
			return "ARRIVE"
		SteeringMode.FLEE:
			return "FLEE"
		_:
			return "WANDER"
