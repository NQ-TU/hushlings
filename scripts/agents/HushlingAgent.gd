extends "res://scripts/agents/AgentMotor3D.gd"
class_name HushlingAgent

const PerceptionHelper := preload("res://scripts/perception/AgentPerception.gd")
const PlayerPerceptionHelper := preload("res://scripts/perception/PlayerPerception.gd")
const BoidsHelper := preload("res://scripts/steering/Boids.gd")
const ObstacleAvoidanceHelper := preload("res://scripts/steering/ObstacleAvoidance.gd")
const IdleCadenceHelper := preload("res://scripts/agents/IdleCadence.gd")
const FleeMemoryHelper := preload("res://scripts/agents/FleeMemory.gd")
const HushlingStateMachine := preload("res://scripts/fsm/HushlingStateMachine.gd")
const HushlingProfileResource := preload("res://scripts/profiles/HushlingProfile.gd")
const HushlingVisualTimidScene := preload("res://scenes/visuals/HushlingVisual_Timid.tscn")
const HushlingVisualBoldScene := preload("res://scenes/visuals/HushlingVisual_Bold.tscn")

@export_group("Debug")
@export var agent_debug_enabled: bool = true

@export_group("Profile")
@export var profile: HushlingProfileResource

@export_group("Visual")
@export_enum("Auto", "Timid", "Bold") var visual_variant: String = "Auto"
@export var visual_root_path: NodePath = ^"VisualRoot"

@export_group("Behaviour")
@export var autonomous_enabled: bool = true
@export var use_group_perception: bool = true
@export var interest_group: StringName = &"interest_entity"
@export var threat_group: StringName = &"threat_entity"
@export var interest_target_path: NodePath
@export var threat_target_path: NodePath
@export_range(0.05, 5.0, 0.01) var arrive_slowing_radius: float = 0.8
@export_range(0.1, 10.0, 0.01) var awareness_radius: float = 2.0
@export_range(0.1, 10.0, 0.01) var observe_distance: float = 0.65
@export_range(0.05, 10.0, 0.01) var interest_flee_radius: float = 0.8
@export_range(0.0, 5.0, 0.01) var interest_flee_clearance: float = 0.2
@export_range(0.05, 10.0, 0.01) var flee_radius: float = 0.7
@export_range(0.1, 10.0, 0.01) var flee_safe_radius: float = 1.35
@export_range(0.05, 1.0, 0.01) var calm_speed_scale: float = 0.45
@export_range(0.05, 1.0, 0.01) var observe_speed_limit_scale: float = 0.32
@export_range(0.1, 10.0, 0.01) var follow_distance: float = 0.9
@export_range(0.1, 10.0, 0.01) var follow_start_distance: float = 1.1
@export_range(0.0, 2.0, 0.01) var follow_start_margin: float = 0.12
@export_range(0.0, 5.0, 0.01) var follow_speed_scale: float = 0.34
@export_range(0.0, 1.0, 0.01) var follow_curiosity_threshold: float = 0.34
@export_range(0.0, 1.0, 0.01) var follow_confidence_threshold: float = 0.12
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
@export_range(0.0, 3.0, 0.01) var regroup_strength: float = 0.38
@export_range(0.0, 1.0, 0.01) var regroup_loneliness_threshold: float = 0.45
@export_range(0.0, 1.0, 0.01) var regroup_exit_loneliness: float = 0.22
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

@export_group("Player Interaction")
@export var player_influence_enabled: bool = true
@export var player_group: StringName = &"player"
@export var player_hand_group: StringName = &"player_hand"
@export var flee_from_player_hand_feelers: bool = true
@export var observe_player_when_grouped: bool = true
@export_range(1, 12, 1) var player_observe_min_group_size: int = 3
@export_range(0.1, 10.0, 0.01) var player_observe_radius: float = 2.0
@export_range(0.05, 5.0, 0.01) var player_hand_flee_memory_time: float = 1.3
@export_range(0.1, 10.0, 0.01) var player_hand_flee_safe_radius: float = 1.15
@export var startle_from_direct_player_gaze: bool = true
@export_range(0.1, 10.0, 0.01) var player_gaze_range: float = 2.6
@export_range(1.0, 45.0, 0.5) var player_dead_center_gaze_degrees: float = 8.0
@export_range(0.0, 1.0, 0.01) var player_gaze_isolation_threshold: float = 0.65
@export_range(0.05, 5.0, 0.01) var player_gaze_startled_duration: float = 1.0
@export_range(0.1, 16.0, 0.1) var player_gaze_turn_response: float = 5.0

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
@export_range(0.0, 1.0, 0.01) var vertical_wander_amount: float = 0.34
@export_range(0.1, 5.0, 0.01) var vertical_wander_frequency_scale: float = 2.15
@export_range(0.0, 1.0, 0.01) var lateral_wander_amount: float = 0.28
@export_range(0.0, 0.95, 0.01) var wander_forward_bias: float = 0.62
@export_range(1.0, 180.0, 1.0) var wander_turn_degrees_per_second: float = 34.0

@export_group("Idle Cadence")
@export var idle_cadence_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var idle_probability: float = 0.34
@export_range(0.05, 8.0, 0.01) var idle_duration_min: float = 0.7
@export_range(0.05, 8.0, 0.01) var idle_duration_max: float = 1.8
@export_range(0.05, 12.0, 0.01) var move_duration_min: float = 1.4
@export_range(0.05, 12.0, 0.01) var move_duration_max: float = 3.4
@export_range(0.0, 0.3, 0.01) var idle_drift_scale: float = 0.05

@export_group("Home Tether")
@export_range(0.1, 10.0, 0.01) var home_radius: float = 1.25
@export_range(0.0, 4.0, 0.01) var home_tether_strength: float = 0.72
@export var use_home_bounds: bool = false
@export var home_bounds_size: Vector3 = Vector3.ZERO
@export_range(0.1, 0.95, 0.01) var home_return_inner_ratio: float = 0.68
@export_range(0.05, 1.0, 0.01) var home_return_speed_scale: float = 0.5
@export_range(1.0, 180.0, 1.0) var home_return_turn_degrees_per_second: float = 58.0

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
var debug_player_hand_flee_active: bool = false
var debug_player_gaze_direct: bool = false
var debug_player_gaze_distance: float = -1.0
var debug_player_gaze_source_name: String = ""
var debug_is_idle: bool = false
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
var _interest_target: Node3D
var _threat_target: Node3D
var _autonomous_flee_target: Node3D
var _autonomous_flee_clear_distance: float = 0.0
var _group_flee_source: Node3D
var _group_flee_time_remaining: float = 0.0
var _direct_player_gaze_source: Node3D
var _startled_target: Node3D
var _startled_time_remaining: float = 0.0
var _autonomous_state: int = HushlingStateMachine.WANDER
var _separation_fallback_direction: Vector3 = Vector3.RIGHT
var _flee_breakup_axis: Vector3 = Vector3.RIGHT
var _speed_variation: float = 1.0
var _wander_variation: float = 1.0
var _cohesion_variation: float = 1.0
var _alignment_variation: float = 1.0
var _returning_home: bool = false
var _idle_cadence := IdleCadenceHelper.new()
var _player_hand_flee := FleeMemoryHelper.new()


func _ready() -> void:
	_apply_profile()
	home_position = global_position
	_wander_seed = _make_instance_seed()
	_setup_individual_variation()
	_idle_cadence.configure(_wander_seed)
	_idle_cadence.force_move(move_duration_min, move_duration_max)
	current_wander_direction = _sample_wander_direction(0.0)
	_separation_fallback_direction = _sample_wander_direction(0.37)
	_flee_breakup_axis = _sample_wander_direction(1.19)
	direction = current_wander_direction
	target_direction = current_wander_direction
	_apply_visual_binding()
	_apply_debug_visibility()


func _process(delta: float) -> void:
	_elapsed_time += delta
	_update_group_flee_memory(delta)
	_update_player_hand_flee_memory(delta)
	_update_startled_timer(delta)
	_update_home_return_state()
	_update_wander_direction(delta)
	_refresh_neighbour_count()
	_update_perception_targets()
	_update_player_gaze_state()
	_update_autonomous_state(delta)
	_update_idle_cadence(delta)

	var desired: Vector3 = _calculate_desired_velocity()
	if _is_startled_state_active():
		apply_desired_velocity(Vector3.ZERO, delta)
		_update_startled_facing(delta)
		return

	desired = _apply_home_tether(desired)
	desired += _calculate_social_forces()
	desired += _calculate_obstacle_avoidance(desired)
	desired = SteeringHelper.limit_vector(desired, _get_active_speed_limit())
	apply_desired_velocity(desired, delta)
	if _is_observe_state_active():
		_update_target_facing(_interest_target, delta)


func _apply_profile() -> void:
	if profile:
		profile.apply_to(self)


func _apply_visual_binding() -> void:
	var visual_root: Node = get_node_or_null(visual_root_path)
	var selected_visual_scene: PackedScene = _get_selected_visual_scene()
	if selected_visual_scene == HushlingVisualBoldScene:
		visual_root = _replace_visual_root(selected_visual_scene)
	elif visual_root == null and selected_visual_scene:
		visual_root = _replace_visual_root(selected_visual_scene)

	if visual_root and visual_root.has_method(&"bind_agent"):
		visual_root.call(&"bind_agent", self)


func _replace_visual_root(visual_scene: PackedScene) -> Node:
	var old_visual_root: Node = get_node_or_null(visual_root_path)
	if old_visual_root:
		remove_child(old_visual_root)
		old_visual_root.queue_free()

	var visual_root := visual_scene.instantiate()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	move_child(visual_root, 0)
	return visual_root


func _get_selected_visual_scene() -> PackedScene:
	match _get_visual_variant_name():
		"Bold":
			return HushlingVisualBoldScene
		"Timid":
			return HushlingVisualTimidScene
		_:
			return null


func _get_visual_variant_name() -> String:
	if visual_variant != "Auto":
		return visual_variant

	if profile == null:
		return ""

	var profile_text: String = "%s %s" % [profile.resource_path, profile.resource_name]
	profile_text = profile_text.to_lower()
	if profile_text.contains("bold"):
		return "Bold"
	if profile_text.contains("timid"):
		return "Timid"
	return ""


func _apply_debug_visibility() -> void:
	var debug_draw: Node = get_node_or_null("AgentDebugDraw")
	if debug_draw:
		debug_draw.set(&"debug_enabled", agent_debug_enabled)


func _update_wander_direction(delta: float) -> void:
	var sampled_direction: Vector3 = _home_return_direction() if _is_home_return_active() \
			else _sample_wander_direction(_elapsed_time)
	var turn_rate: float = home_return_turn_degrees_per_second if _is_home_return_active() \
			else wander_turn_degrees_per_second
	current_wander_direction = _smooth_direction_change(
		current_wander_direction,
		sampled_direction,
		delta,
		wander_smoothing,
		wander_forward_bias,
		turn_rate
	)


func _update_idle_cadence(delta: float) -> void:
	if _is_home_return_active() or not _can_apply_idle_cadence():
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


func _can_apply_idle_cadence() -> bool:
	return _autonomous_state == HushlingStateMachine.WANDER


func _calculate_desired_velocity() -> Vector3:
	_set_debug_target(null)
	_update_current_state_label()
	if _is_home_return_active():
		current_state = "RETURN"
		return _calculate_home_return_velocity()

	return _calculate_autonomous_desired_velocity()


func _calculate_autonomous_desired_velocity() -> Vector3:
	regroup_force = Vector3.ZERO
	match _autonomous_state:
		HushlingStateMachine.FLEE:
			var flee_target: Node3D = _get_autonomous_flee_target()
			if flee_target:
				_set_debug_target(flee_target)
				return _calculate_flee_velocity(flee_target)
		HushlingStateMachine.STARTLED:
			if _startled_target:
				_set_debug_target(_startled_target)
			return Vector3.ZERO
		HushlingStateMachine.REGROUP:
			return _calculate_regroup_velocity()
		HushlingStateMachine.OBSERVE:
			if _interest_target:
				_set_debug_target(_interest_target)
				return _calculate_observe_velocity()
		HushlingStateMachine.FOLLOW:
			if _interest_target:
				_set_debug_target(_interest_target)
				return _calculate_follow_velocity(_interest_target.global_position)
		HushlingStateMachine.WANDER:
			return _calculate_wander_velocity()

	return _calculate_wander_velocity()


func _calculate_wander_velocity() -> Vector3:
	var idle_scale: float = idle_drift_scale if debug_is_idle else 1.0
	return current_wander_direction * max_speed * wander_strength * _wander_variation * idle_scale


func _calculate_home_return_velocity() -> Vector3:
	return _home_return_direction() * max_speed * home_return_speed_scale * _speed_variation


func _calculate_regroup_velocity() -> Vector3:
	regroup_force = Vector3.ZERO
	if not social_forces_enabled or not is_inside_tree():
		return Vector3.ZERO

	var neighbours: Array = get_tree().get_nodes_in_group(neighbour_group)
	if BoidsHelper.neighbour_count(self, neighbours, regroup_radius) <= 0:
		return Vector3.ZERO

	var regroup_velocity: Vector3 = BoidsHelper.cohesion(
		self,
		neighbours,
		regroup_radius,
		max_speed * regroup_speed_scale
	)
	var loneliness_factor: float = clamp(
		inverse_lerp(regroup_exit_loneliness, regroup_loneliness_threshold, loneliness),
		0.0,
		1.0
	)
	regroup_force = regroup_velocity * regroup_strength * max(loneliness_factor, 0.25)
	return regroup_force


func _calculate_observe_velocity() -> Vector3:
	return Vector3.ZERO


func _calculate_follow_velocity(target_position: Vector3) -> Vector3:
	var to_target: Vector3 = target_position - global_position
	var distance_to_target: float = to_target.length()
	if distance_to_target <= 0.0001:
		return Vector3.ZERO

	var from_target: Vector3 = -to_target / distance_to_target
	var stand_off_position: Vector3 = target_position + from_target * follow_distance
	return SteeringHelper.arrive(
		global_position,
		stand_off_position,
		max_speed * follow_speed_scale,
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


func _update_home_return_state() -> void:
	if _is_outside_home_area():
		_returning_home = true
	elif _returning_home and _is_securely_inside_home_area():
		_returning_home = false


func _is_home_return_active() -> bool:
	return _returning_home \
			and _autonomous_state != HushlingStateMachine.FLEE \
			and _autonomous_state != HushlingStateMachine.STARTLED


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


func _apply_home_tether(input_desired_velocity: Vector3) -> Vector3:
	if not _should_apply_home_tether():
		return input_desired_velocity

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


func _should_apply_home_tether() -> bool:
	return _autonomous_state != HushlingStateMachine.FLEE \
			and _autonomous_state != HushlingStateMachine.STARTLED


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
	if _is_observe_state_active():
		separation_multiplier *= 0.7
		cohesion_multiplier = 0.0
		alignment_multiplier = 0.0
	elif _is_regroup_state_active():
		cohesion_multiplier = 0.0
		alignment_multiplier *= 0.5
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
	if not player_influence_enabled or not flee_from_player_hand_feelers:
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


func _update_startled_timer(delta: float) -> void:
	if _startled_time_remaining <= 0.0:
		return

	_startled_time_remaining = max(_startled_time_remaining - delta, 0.0)


func _refresh_neighbour_count() -> void:
	if not social_forces_enabled or not is_inside_tree():
		debug_neighbour_count = 0
		return

	debug_neighbour_count = BoidsHelper.neighbour_count(
		self,
		get_tree().get_nodes_in_group(neighbour_group),
		group_radius
	)


func _update_player_gaze_state() -> void:
	debug_player_gaze_direct = false
	debug_player_gaze_distance = -1.0
	debug_player_gaze_source_name = ""
	_direct_player_gaze_source = null

	if not player_influence_enabled or not startle_from_direct_player_gaze or not is_inside_tree():
		return
	if _get_isolation_factor() < player_gaze_isolation_threshold:
		return
	if _is_flee_state_active():
		return

	var los_collision_mask: int = perception_los_collision_mask if use_raycast_line_of_sight else 0
	_direct_player_gaze_source = PlayerPerceptionHelper.find_direct_gaze_source(
		self,
		player_group,
		player_hand_group,
		player_gaze_range,
		player_dead_center_gaze_degrees,
		los_collision_mask,
		perception_los_end_margin
	)
	if _direct_player_gaze_source == null:
		return

	debug_player_gaze_direct = true
	debug_player_gaze_distance = global_position.distance_to(_direct_player_gaze_source.global_position)
	debug_player_gaze_source_name = _direct_player_gaze_source.name


func _should_startle_from_player_gaze() -> bool:
	return debug_player_gaze_direct and _direct_player_gaze_source != null


func _is_startled_state_active() -> bool:
	return _autonomous_state == HushlingStateMachine.STARTLED


func _update_startled_facing(delta: float) -> void:
	_update_target_facing(_startled_target, delta)


func _update_target_facing(target: Node3D, delta: float) -> void:
	if not is_instance_valid(target):
		return

	var to_target: Vector3 = target.global_position - global_position
	if to_target.length_squared() <= 0.0001:
		return

	var face_direction: Vector3 = to_target.normalized()
	direction = face_direction
	target_direction = face_direction
	var target_basis: Basis = _basis_from_forward(face_direction)
	var rotation_alpha: float = 1.0 - exp(-player_gaze_turn_response * delta)
	var current_quat: Quaternion = global_transform.basis.orthonormalized().get_rotation_quaternion()
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()
	var next_transform: Transform3D = global_transform
	next_transform.basis = _basis_preserving_current_scale(
		Basis(current_quat.slerp(target_quat, rotation_alpha))
	)
	global_transform = next_transform


func _update_autonomous_state(delta: float) -> void:
	debug_interest_distance = _distance_to_or_negative(_interest_target)
	debug_threat_distance = _distance_to_or_negative(_threat_target)
	debug_interest_visible = _can_observe_interest_target()
	debug_interest_sees_agent = _interest_target_has_los_to_agent()
	debug_player_hand_flee_active = _is_player_hand_flee_active()
	_update_social_response_debug_values()
	_update_internal_variables(delta)

	if not autonomous_enabled:
		return

	if _autonomous_state == HushlingStateMachine.STARTLED:
		if _startled_time_remaining > 0.0 and not _is_player_hand_flee_active():
			return
		_startled_target = null
		_autonomous_state = HushlingStateMachine.WANDER

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
		HushlingStateMachine.STARTLED:
			_enter_startled_state()
		HushlingStateMachine.FOLLOW:
			_autonomous_state = HushlingStateMachine.FOLLOW
		HushlingStateMachine.OBSERVE:
			_autonomous_state = HushlingStateMachine.OBSERVE
		HushlingStateMachine.REGROUP:
			_autonomous_state = HushlingStateMachine.REGROUP
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
		"confidence": confidence,
		"loneliness": loneliness,
		"follow_distance": follow_distance,
		"follow_start_distance": follow_start_distance,
		"follow_start_margin": follow_start_margin,
		"follow_curiosity_threshold": follow_curiosity_threshold,
		"follow_confidence_threshold": follow_confidence_threshold,
		"has_regroup_target": _has_regroup_target(),
		"regroup_loneliness_threshold": regroup_loneliness_threshold,
		"regroup_exit_loneliness": regroup_exit_loneliness,
		"effective_fear": _get_effective_fear(),
		"fear_flee_threshold": fear_flee_threshold,
		"group_flee_active": group_flee_source != null,
		"player_hand_flee_active": _is_player_hand_flee_active(),
		"player_gaze_startle_active": _should_startle_from_player_gaze(),
		"startled_time_remaining": _startled_time_remaining,
	}


func _enter_flee_state(group_flee_source: Node3D = null) -> void:
	if _is_player_hand_flee_active():
		_clear_group_flee_memory()
		_autonomous_flee_clear_distance = player_hand_flee_safe_radius
		_autonomous_flee_target = _player_hand_flee.target
	elif _threat_target and debug_threat_distance <= _get_effective_threat_flee_radius():
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


func _enter_startled_state() -> void:
	if _direct_player_gaze_source == null:
		return

	_clear_group_flee_memory()
	_autonomous_flee_target = null
	_autonomous_flee_clear_distance = 0.0
	_startled_target = _direct_player_gaze_source
	_startled_time_remaining = player_gaze_startled_duration
	_autonomous_state = HushlingStateMachine.STARTLED


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

	if _is_player_hand_flee_active():
		target_fear = max(target_fear, 1.0)

	if _is_startled_state_active():
		target_fear = max(target_fear, 0.64)

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
	if _autonomous_state == HushlingStateMachine.STARTLED:
		return 0.7
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
	if _autonomous_state == HushlingStateMachine.WANDER and debug_is_idle:
		current_state = "IDLE"
	else:
		current_state = HushlingStateMachine.state_name(_autonomous_state)


func _update_perception_targets() -> void:
	_interest_target = _get_node3d_or_null(interest_target_path)
	_threat_target = _get_node3d_or_null(threat_target_path)

	if not use_group_perception:
		return

	if _interest_target == null:
		var interest_entity_target: Node3D = PerceptionHelper.nearest_in_group(
			self,
			interest_group,
			_get_interest_perception_radius()
		)
		var player_interest_target: Node3D = _find_observable_player_target()
		_interest_target = _choose_interest_target(interest_entity_target, player_interest_target)

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


func _choose_interest_target(a: Node3D, b: Node3D) -> Node3D:
	if a == null:
		return b
	if b == null:
		return a

	var can_observe_a: bool = _can_observe_candidate(a)
	var can_observe_b: bool = _can_observe_candidate(b)
	if can_observe_a != can_observe_b:
		return a if can_observe_a else b

	var distance_a: float = global_position.distance_squared_to(a.global_position)
	var distance_b: float = global_position.distance_squared_to(b.global_position)
	return a if distance_a <= distance_b else b


func _can_observe_candidate(target: Node3D) -> bool:
	if target == null:
		return false
	if global_position.distance_to(target.global_position) > awareness_radius:
		return false
	if not PerceptionHelper.is_target_in_fov(self, target, interest_fov_degrees):
		return false
	if require_interest_los_to_observe and not _has_perception_line_of_sight(self, target):
		return false

	return true


func _find_observable_player_target() -> Node3D:
	if not player_influence_enabled or not observe_player_when_grouped:
		return null
	if not _has_player_observe_group_support():
		return null

	var player_target: Node3D = PlayerPerceptionHelper.find_observable_source(
		self,
		player_group,
		player_hand_group,
		min(player_observe_radius, awareness_radius)
	)
	if player_target == null:
		return null
	if not PerceptionHelper.is_target_in_fov(self, player_target, interest_fov_degrees):
		return null
	if require_interest_los_to_observe and not _has_perception_line_of_sight(self, player_target):
		return null

	return player_target


func _has_player_observe_group_support() -> bool:
	return debug_neighbour_count + 1 >= player_observe_min_group_size


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
	return _autonomous_state == HushlingStateMachine.FLEE


func _is_observe_state_active() -> bool:
	return _autonomous_state == HushlingStateMachine.OBSERVE


func _is_regroup_state_active() -> bool:
	return _autonomous_state == HushlingStateMachine.REGROUP


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


func _has_regroup_target() -> bool:
	if not social_forces_enabled or not is_inside_tree():
		return false

	return BoidsHelper.neighbour_count(
		self,
		get_tree().get_nodes_in_group(neighbour_group),
		regroup_radius
	) > 0


func _get_autonomous_flee_target() -> Node3D:
	if _is_player_hand_flee_active():
		return _player_hand_flee.target

	if is_instance_valid(_autonomous_flee_target):
		return _autonomous_flee_target

	if _threat_target:
		return _threat_target

	return null


func _get_flee_safe_distance(flee_target: Node3D) -> float:
	if _autonomous_flee_clear_distance > 0.0:
		return _autonomous_flee_clear_distance

	if flee_target and flee_target.is_in_group(player_hand_group):
		return player_hand_flee_safe_radius

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

	debug_interest_in_fov = PerceptionHelper.is_target_in_fov(self, _interest_target, interest_fov_degrees)
	if not debug_interest_in_fov:
		return false

	debug_interest_los_clear = _has_perception_line_of_sight(self, _interest_target)
	return debug_interest_los_clear


func _interest_target_has_los_to_agent() -> bool:
	debug_interest_gaze_in_fov = false
	debug_interest_gaze_los_clear = false
	if not flee_if_interest_sees_agent or _interest_target == null:
		return false
	if _interest_target.is_in_group(player_group):
		return false
	if debug_interest_distance < 0.0 or debug_interest_distance > _get_effective_interest_gaze_flee_radius():
		return false

	debug_interest_gaze_in_fov = PerceptionHelper.is_target_in_fov(_interest_target, self, interest_gaze_fov_degrees)
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


func _get_active_speed_limit() -> float:
	if _is_flee_state_active():
		return max_speed * flee_speed_scale

	if _is_home_return_active():
		return max_speed * home_return_speed_scale * _speed_variation

	if _autonomous_state == HushlingStateMachine.FOLLOW:
		return max_speed * follow_speed_scale * _speed_variation

	if _autonomous_state == HushlingStateMachine.REGROUP:
		return max_speed * regroup_speed_scale * _speed_variation

	if _autonomous_state == HushlingStateMachine.OBSERVE:
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
	var forward: Vector3 = _safe_direction(current_wander_direction, direction)
	var side: Vector3 = _side_axis_for(forward)
	var lateral: float = sin(phase * 0.73 + 0.8) * lateral_wander_amount
	lateral += sin(phase * 0.31 + 2.2) * lateral_wander_amount * 0.35
	var vertical: float = sin(phase * vertical_wander_frequency_scale + 1.4) * vertical_wander_amount
	var sample: Vector3 = forward + side * lateral + Vector3.UP * vertical
	return _safe_direction(sample, forward)
