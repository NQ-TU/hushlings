extends Node3D
class_name AgentDebugDraw

@export_group("Debug")
@export var debug_enabled: bool = true
@export var target_path: NodePath
@export var allow_keyboard_toggle: bool = true
@export var toggle_key: Key = KEY_G

@export_group("Display")
@export var show_home_volume: bool = false
@export var show_separation_radius: bool = true
@export var show_velocity: bool = true
@export var show_desired_velocity: bool = true
@export var show_steering_force: bool = false
@export var show_final_velocity: bool = false
@export var show_separation_force: bool = true
@export var show_cohesion_force: bool = false
@export var show_alignment_force: bool = false
@export var show_obstacle_avoidance: bool = true
@export var show_obstacle_feelers: bool = true
@export var show_wander_direction: bool = false
@export var show_target_ray: bool = true
@export var show_state_label: bool = true
@export var show_2d_overlay: bool = true
@export var compact_2d_overlay: bool = true
@export_range(0.001, 0.2, 0.001) var line_thickness: float = 0.006
@export_range(0.0, 1.0, 0.01) var center_brightness: float = 0.25
@export_range(0.01, 10.0, 0.01) var velocity_vector_scale: float = 0.82
@export_range(0.01, 10.0, 0.01) var force_vector_scale: float = 1.25
@export_range(0.01, 1.0, 0.01) var arrow_head_size: float = 0.045
@export_range(0.0, 1.0, 0.01) var vector_vertical_offset: float = 0.22
@export_range(0.1, 3.0, 0.01) var label_height: float = 0.62
@export_range(8, 48, 1) var label_font_size: int = 18
@export var draw_without_depth_test: bool = false
@export var fallback_state_name: String = "STEERING"

@export_group("Colours")
@export var home_volume_color: Color = Color(0.22, 0.75, 1.0, 0.08)
@export var home_line_color: Color = Color(0.35, 0.65, 0.9, 0.22)
@export var separation_radius_color: Color = Color(1.0, 0.55, 0.12, 0.12)
@export var separation_force_color: Color = Color(1.0, 0.55, 0.08, 0.82)
@export var cohesion_force_color: Color = Color(0.1, 0.85, 0.9, 0.62)
@export var alignment_force_color: Color = Color(0.35, 0.68, 1.0, 0.62)
@export var obstacle_avoidance_color: Color = Color(1.0, 0.18, 0.75, 0.78)
@export var obstacle_hit_color: Color = Color(1.0, 0.18, 0.28, 0.82)
@export var obstacle_feeler_color: Color = Color(1.0, 0.18, 0.75, 0.18)
@export var wander_direction_color: Color = Color(0.15, 0.95, 0.95, 0.55)
@export var velocity_color: Color = Color(0.2, 0.45, 1.0, 0.78)
@export var desired_velocity_color: Color = Color(0.15, 0.9, 0.25, 0.78)
@export var steering_force_color: Color = Color(1.0, 0.85, 0.1, 0.72)
@export var final_velocity_color: Color = Color(0.75, 0.25, 1.0, 0.7)
@export var target_ray_color: Color = Color(1.0, 1.0, 1.0, 0.45)
@export var label_color: Color = Color(0.85, 0.96, 1.0, 0.78)

var _target: Node3D
var _debug_draw_3d: Object
var _debug_draw_2d: Object


func _ready() -> void:
	_resolve_target()
	_resolve_debug_draw_singletons()


func _unhandled_input(event: InputEvent) -> void:
	if not allow_keyboard_toggle:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		debug_enabled = not debug_enabled


func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		_resolve_target()
	if _debug_draw_3d == null or _debug_draw_2d == null:
		_resolve_debug_draw_singletons()

	if _target == null or _debug_draw_3d == null:
		return

	if not debug_enabled:
		_clear_overlay()
		return

	var debug_config: Variant = _debug_draw_3d.call("new_scoped_config")
	if debug_config != null:
		debug_config.call("set_thickness", line_thickness)
		debug_config.call("set_center_brightness", center_brightness)
		debug_config.call("set_no_depth_test", draw_without_depth_test)

	_draw_debug()
	_update_overlay()


func _resolve_target() -> void:
	_target = null
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node3D

	if _target == null:
		_target = get_parent() as Node3D


func _resolve_debug_draw_singletons() -> void:
	_debug_draw_3d = null
	_debug_draw_2d = null
	if Engine.has_singleton("DebugDraw3D"):
		_debug_draw_3d = Engine.get_singleton("DebugDraw3D")
	if Engine.has_singleton("DebugDraw2D"):
		_debug_draw_2d = Engine.get_singleton("DebugDraw2D")


func _draw_debug() -> void:
	var agent_position: Vector3 = _target.global_position
	var vector_origin: Vector3 = agent_position + Vector3.UP * vector_vertical_offset
	var home_position: Vector3 = _read_vector_property(&"home_position", agent_position)
	var home_radius: float = _read_float_property(&"home_radius", 0.0)

	if show_home_volume and home_radius > 0.0:
		_debug_draw_3d.call("draw_sphere", home_position, home_radius, home_volume_color)
		_debug_draw_3d.call("draw_line", home_position, agent_position, home_line_color)

	if show_separation_radius:
		var separation_radius: float = _read_float_property(&"separation_radius", 0.0)
		if separation_radius > 0.0:
			_debug_draw_3d.call("draw_sphere", agent_position, separation_radius, separation_radius_color)

	if show_wander_direction:
		_draw_arrow(
			vector_origin,
			_read_vector_property(&"current_wander_direction", Vector3.ZERO) * 0.42,
			wander_direction_color
		)

	if show_velocity:
		_draw_arrow(
			vector_origin,
			_read_vector_property(&"velocity", Vector3.ZERO) * velocity_vector_scale,
			velocity_color
		)

	if show_desired_velocity:
		_draw_arrow(
			vector_origin,
			_read_vector_property(&"desired_velocity", Vector3.ZERO) * velocity_vector_scale,
			desired_velocity_color
		)

	if show_steering_force:
		_draw_arrow(
			vector_origin,
			_read_vector_property(&"steering_force", Vector3.ZERO) * force_vector_scale,
			steering_force_color
		)

	if show_final_velocity:
		_draw_arrow(
			vector_origin,
			_read_vector_property(&"final_velocity", Vector3.ZERO) * velocity_vector_scale,
			final_velocity_color
		)

	if show_separation_force:
		_draw_arrow(
			vector_origin,
			_read_vector_property(&"separation_force", Vector3.ZERO) * force_vector_scale,
			separation_force_color
		)

	if show_cohesion_force:
		_draw_arrow(
			vector_origin,
			_read_vector_property(&"cohesion_force", Vector3.ZERO) * force_vector_scale,
			cohesion_force_color
		)

	if show_alignment_force:
		_draw_arrow(
			vector_origin,
			_read_vector_property(&"alignment_force", Vector3.ZERO) * force_vector_scale,
			alignment_force_color
		)

	if show_obstacle_feelers:
		_draw_obstacle_feelers(agent_position)

	if show_obstacle_avoidance:
		_draw_arrow(
			vector_origin,
			_read_vector_property(&"obstacle_avoidance_force", Vector3.ZERO) * force_vector_scale,
			obstacle_avoidance_color
		)
		if _read_bool_property(&"debug_obstacle_hit", false):
			var hit_position: Vector3 = _read_vector_property(&"debug_obstacle_hit_position", agent_position)
			var hit_normal: Vector3 = _read_vector_property(&"debug_obstacle_hit_normal", Vector3.UP)
			_debug_draw_3d.call("draw_position", Transform3D(Basis.IDENTITY, hit_position), obstacle_hit_color)
			_debug_draw_3d.call("draw_line", hit_position, hit_position + hit_normal * 0.14, obstacle_hit_color)

	if show_target_ray and _read_bool_property(&"debug_has_target", false):
		var target_position: Vector3 = _read_vector_property(&"debug_target_position", agent_position)
		_debug_draw_3d.call("draw_line", agent_position, target_position, target_ray_color)
		_debug_draw_3d.call("draw_position", Transform3D(Basis.IDENTITY, target_position), target_ray_color)

	if show_state_label:
		_debug_draw_3d.call(
			"draw_text",
			agent_position + Vector3.UP * label_height,
			_get_agent_label_text(),
			label_font_size,
			label_color,
			0.0
		)


func _draw_arrow(start_position: Vector3, vector: Vector3, color: Color) -> void:
	if vector.length_squared() <= 0.0001:
		return

	_debug_draw_3d.call("draw_arrow", start_position, start_position + vector, color, arrow_head_size)


func _draw_obstacle_feelers(origin: Vector3) -> void:
	var feeler_length: float = _read_float_property(&"obstacle_feeler_length", 0.0)
	if feeler_length <= 0.0:
		return

	var forward: Vector3 = _safe_direction(
		_read_vector_property(&"desired_velocity", Vector3.ZERO),
		_read_vector_property(&"direction", Vector3.FORWARD)
	)
	var right_axis: Vector3 = forward.cross(Vector3.UP)
	if right_axis.length_squared() <= 0.0001:
		right_axis = Vector3.RIGHT
	else:
		right_axis = right_axis.normalized()

	var angle: float = deg_to_rad(_read_float_property(&"obstacle_feeler_angle_degrees", 34.0))
	var directions: Array[Vector3] = [
		forward,
		Quaternion(Vector3.UP, angle) * forward,
		Quaternion(Vector3.UP, -angle) * forward,
		Quaternion(right_axis, angle) * forward,
		Quaternion(right_axis, -angle) * forward,
	]
	for direction in directions:
		_debug_draw_3d.call("draw_line", origin, origin + direction.normalized() * feeler_length, obstacle_feeler_color)


func _update_overlay() -> void:
	if _debug_draw_2d == null:
		return

	if not show_2d_overlay:
		_clear_overlay()
		return

	var velocity: Vector3 = _read_vector_property(&"velocity", Vector3.ZERO)
	var desired_velocity: Vector3 = _read_vector_property(&"desired_velocity", Vector3.ZERO)
	var steering_force: Vector3 = _read_vector_property(&"steering_force", Vector3.ZERO)
	var separation_force: Vector3 = _read_vector_property(&"separation_force", Vector3.ZERO)
	var cohesion_force: Vector3 = _read_vector_property(&"cohesion_force", Vector3.ZERO)
	var alignment_force: Vector3 = _read_vector_property(&"alignment_force", Vector3.ZERO)
	var neighbour_count: int = _read_int_property(&"debug_neighbour_count", 0)
	var interest_visible: bool = _read_bool_property(&"debug_interest_visible", false)
	var interest_sees_agent: bool = _read_bool_property(&"debug_interest_sees_agent", false)
	var interest_los_clear: bool = _read_bool_property(&"debug_interest_los_clear", false)
	var interest_gaze_los_clear: bool = _read_bool_property(&"debug_interest_gaze_los_clear", false)
	var obstacle_hit: bool = _read_bool_property(&"debug_obstacle_hit", false)
	var player_hand_flee_active: bool = _read_bool_property(&"debug_player_hand_flee_active", false)
	var player_gaze_direct: bool = _read_bool_property(&"debug_player_gaze_direct", false)
	var mind_text: String = "fear %.2f | curiosity %.2f | confidence %.2f | loneliness %.2f | support %.2f | flee %.2f" % [
		_read_float_property(&"fear", 0.0),
		_read_float_property(&"curiosity", 0.0),
		_read_float_property(&"confidence", 0.0),
		_read_float_property(&"loneliness", 0.0),
		_read_float_property(&"debug_group_support", 0.0),
		_read_float_property(&"debug_effective_interest_flee_radius", 0.0),
	]

	if compact_2d_overlay:
		_debug_draw_2d.call("set_text", "Hushlings/debug", "G toggles debug")
		_debug_draw_2d.call(
			"set_text",
			"Agent/status",
			"%s | speed %.2f | group %d | interest %s | visible %s | watched %s | los %s/%s | hand %s | gaze %s" % [
				_read_string_property(&"current_state", fallback_state_name),
				velocity.length(),
				neighbour_count,
				_format_distance(_read_float_property(&"debug_interest_distance", -1.0)),
				_format_bool(interest_visible),
				_format_bool(interest_sees_agent),
				_format_bool(interest_los_clear),
				_format_bool(interest_gaze_los_clear),
				_format_bool(player_hand_flee_active or obstacle_hit),
				_format_bool(player_gaze_direct),
			]
		)
		_debug_draw_2d.call("set_text", "Agent/mind", mind_text)
		_clear_verbose_overlay()
		return

	_debug_draw_2d.call("set_text", "Hushlings/debug", "G toggles debug")
	_debug_draw_2d.call("set_text", "Agent/status", "")
	_debug_draw_2d.call("set_text", "Agent/state", _read_string_property(&"current_state", fallback_state_name))
	_debug_draw_2d.call("set_text", "Agent/mind", mind_text)
	_debug_draw_2d.call("set_text", "Agent/target", _read_string_property(&"debug_target_name", ""))
	_debug_draw_2d.call("set_text", "Agent/interest_distance", _format_distance(_read_float_property(&"debug_interest_distance", -1.0)))
	_debug_draw_2d.call("set_text", "Agent/threat_distance", _format_distance(_read_float_property(&"debug_threat_distance", -1.0)))
	_debug_draw_2d.call("set_text", "Agent/speed", "%.3f" % velocity.length())
	_debug_draw_2d.call("set_text", "Agent/desired_velocity", _format_vector(desired_velocity))
	_debug_draw_2d.call("set_text", "Agent/steering_force", _format_vector(steering_force))
	_debug_draw_2d.call("set_text", "Agent/separation_force", _format_vector(separation_force))
	_debug_draw_2d.call("set_text", "Agent/cohesion_force", _format_vector(cohesion_force))
	_debug_draw_2d.call("set_text", "Agent/alignment_force", _format_vector(alignment_force))
	_debug_draw_2d.call("set_text", "Agent/regroup_force", _format_vector(_read_vector_property(&"regroup_force", Vector3.ZERO)))
	_debug_draw_2d.call("set_text", "Agent/obstacle_avoidance_force", _format_vector(_read_vector_property(&"obstacle_avoidance_force", Vector3.ZERO)))
	_debug_draw_2d.call("set_text", "Agent/obstacle_hit", str(obstacle_hit))
	_debug_draw_2d.call("set_text", "Agent/player_hand_flee", str(player_hand_flee_active))
	_debug_draw_2d.call("set_text", "Agent/player_gaze_direct", str(player_gaze_direct))
	_debug_draw_2d.call("set_text", "Agent/interest_visible", str(interest_visible))
	_debug_draw_2d.call("set_text", "Agent/interest_sees_agent", str(interest_sees_agent))
	_debug_draw_2d.call("set_text", "Agent/interest_los_clear", str(interest_los_clear))
	_debug_draw_2d.call("set_text", "Agent/interest_gaze_los_clear", str(interest_gaze_los_clear))


func _clear_overlay() -> void:
	if _debug_draw_2d == null:
		return

	_debug_draw_2d.call("set_text", "Hushlings/debug", "")
	_debug_draw_2d.call("set_text", "Agent/status", "")
	_debug_draw_2d.call("set_text", "Agent/mind", "")
	_clear_verbose_overlay()


func _clear_verbose_overlay() -> void:
	if _debug_draw_2d == null:
		return

	_debug_draw_2d.call("set_text", "Agent/state", "")
	_debug_draw_2d.call("set_text", "Agent/target", "")
	_debug_draw_2d.call("set_text", "Agent/interest_distance", "")
	_debug_draw_2d.call("set_text", "Agent/threat_distance", "")
	_debug_draw_2d.call("set_text", "Agent/speed", "")
	_debug_draw_2d.call("set_text", "Agent/desired_velocity", "")
	_debug_draw_2d.call("set_text", "Agent/steering_force", "")
	_debug_draw_2d.call("set_text", "Agent/separation_force", "")
	_debug_draw_2d.call("set_text", "Agent/cohesion_force", "")
	_debug_draw_2d.call("set_text", "Agent/alignment_force", "")
	_debug_draw_2d.call("set_text", "Agent/regroup_force", "")
	_debug_draw_2d.call("set_text", "Agent/obstacle_avoidance_force", "")
	_debug_draw_2d.call("set_text", "Agent/obstacle_hit", "")
	_debug_draw_2d.call("set_text", "Agent/player_hand_flee", "")
	_debug_draw_2d.call("set_text", "Agent/player_gaze_direct", "")
	_debug_draw_2d.call("set_text", "Agent/interest_visible", "")
	_debug_draw_2d.call("set_text", "Agent/interest_sees_agent", "")
	_debug_draw_2d.call("set_text", "Agent/interest_los_clear", "")
	_debug_draw_2d.call("set_text", "Agent/interest_gaze_los_clear", "")


func _get_agent_label_text() -> String:
	var state_text: String = _read_string_property(&"current_state", fallback_state_name)
	var speed: float = _read_vector_property(&"velocity", Vector3.ZERO).length()
	return "%s\n%s  %.2f" % [_target.name, state_text, speed]


func _read_vector_property(property_name: StringName, fallback: Vector3) -> Vector3:
	var value: Variant = _target.get(property_name)
	if value is Vector3:
		return value
	return fallback


func _read_float_property(property_name: StringName, fallback: float) -> float:
	var value: Variant = _target.get(property_name)
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback


func _read_int_property(property_name: StringName, fallback: int) -> int:
	var value: Variant = _target.get(property_name)
	if value is int:
		return value
	if value is float:
		return int(value)
	return fallback


func _read_bool_property(property_name: StringName, fallback: bool) -> bool:
	var value: Variant = _target.get(property_name)
	if value is bool:
		return value
	return fallback


func _read_string_property(property_name: StringName, fallback: String) -> String:
	var value: Variant = _target.get(property_name)
	if value is String:
		return value
	if value != null:
		return str(value)
	return fallback


func _format_vector(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]


func _format_distance(value: float) -> String:
	if value < 0.0:
		return "--"
	return "%.2f" % value


func _format_bool(value: bool) -> String:
	return "yes" if value else "no"


func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		if fallback.length_squared() <= 0.0001:
			return Vector3.FORWARD
		return fallback.normalized()
	return value.normalized()
