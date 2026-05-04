extends Resource
class_name HushlingProfile

@export_group("Minimal Autonomous Test")
@export var autonomous_enabled: bool = true
@export var use_group_perception: bool = true
@export var interest_group: StringName = &"interest_entity"
@export var threat_group: StringName = &"threat_entity"
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


func apply_to(agent: Node) -> void:
	if agent == null:
		return

	var agent_properties := _property_name_set(agent)
	for property in _profile_property_names():
		if agent_properties.has(property):
			agent.set(property, get(property))


func _property_name_set(object: Object) -> Dictionary:
	var names: Dictionary = {}
	for property in object.get_property_list():
		names[StringName(property.get("name", ""))] = true
	return names


func _profile_property_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for property in get_property_list():
		var property_name: StringName = StringName(property.get("name", ""))
		var property_name_text := String(property_name)
		if property_name == &"resource_path" or property_name == &"resource_name":
			continue
		if property_name_text.begins_with("script"):
			continue
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			names.append(property_name)
	return names
