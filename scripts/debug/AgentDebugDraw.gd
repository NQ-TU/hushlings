extends Node3D
class_name AgentDebugDraw

const LABEL_COLOR := Color(0.85, 0.96, 1.0, 0.82)
const FACING_COLOR := Color(0.75, 1.0, 1.0, 0.74)
const VELOCITY_COLOR := Color(0.2, 0.45, 1.0, 0.78)
const DESIRED_VELOCITY_COLOR := Color(0.15, 0.9, 0.25, 0.78)
const STEERING_FORCE_COLOR := Color(1.0, 0.85, 0.1, 0.76)
const FINAL_VELOCITY_COLOR := Color(0.75, 0.25, 1.0, 0.68)
const AWARENESS_COLOR := Color(0.25, 0.8, 1.0, 0.16)
const OBSERVE_COLOR := Color(0.2, 1.0, 0.55, 0.16)
const FLEE_RADIUS_COLOR := Color(1.0, 0.18, 0.18, 0.18)
const SEPARATION_COLOR := Color(1.0, 0.55, 0.12, 0.18)
const TARGET_COLOR := Color(1.0, 1.0, 1.0, 0.52)
const OBSTACLE_FEELER_COLOR := Color(1.0, 0.18, 0.75, 0.08)
const OBSTACLE_FORCE_COLOR := Color(1.0, 0.18, 0.75, 0.55)
const OBSTACLE_HIT_COLOR := Color(1.0, 0.18, 0.28, 0.86)
const HAND_FLEE_COLOR := Color(1.0, 0.18, 0.05, 0.9)

@export_group("Debug")
@export var debug_enabled: bool = true
@export var target_path: NodePath
@export_enum("Auto", "Hushling", "Crawler") var agent_kind: String = "Auto"
@export var allow_keyboard_toggle: bool = true
@export var toggle_key: Key = KEY_G

@export_group("Display")
@export var show_state_label: bool = true
@export var show_movement_vectors: bool = true
@export var show_final_velocity: bool = false
@export var show_hushling_ranges: bool = true
@export var show_target_ray: bool = true
@export var show_obstacle_debug: bool = true
@export var show_hand_flee: bool = true
@export_range(0.0, 0.05, 0.001) var line_thickness: float = 0.0
@export_range(0.0, 1.0, 0.01) var center_brightness: float = 0.0
@export_range(0.01, 2.0, 0.01) var direction_vector_length: float = 0.34
@export_range(0.01, 4.0, 0.01) var velocity_vector_scale: float = 1.2
@export_range(0.01, 4.0, 0.01) var force_vector_scale: float = 1.45
@export_range(0.01, 1.0, 0.01) var hand_indicator_length: float = 0.28
@export_range(0.001, 0.2, 0.001) var arrow_head_size: float = 0.018
@export_range(0.0, 1.0, 0.01) var vector_height: float = 0.2
@export_range(0.05, 2.0, 0.01) var label_height: float = 0.36
@export_range(8, 36, 1) var label_font_size: int = 14
@export_range(8, 96, 1) var ring_segments: int = 32
@export var draw_without_depth_test: bool = false

var _target: Node3D
var _debug_draw_3d: Object


func _ready() -> void:
	_resolve_target()
	_resolve_debug_draw()


func _unhandled_input(event: InputEvent) -> void:
	if not allow_keyboard_toggle:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		debug_enabled = not debug_enabled


func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		_resolve_target()
	if _debug_draw_3d == null:
		_resolve_debug_draw()

	if not debug_enabled or _target == null or _debug_draw_3d == null:
		return

	var _draw_config: Variant = _create_draw_config()

	var kind: String = _resolved_agent_kind()
	var agent_position: Vector3 = _target.global_position
	var vector_origin: Vector3 = agent_position + Vector3.UP * vector_height

	if show_movement_vectors:
		_draw_movement_vectors(vector_origin)
	if show_obstacle_debug:
		_draw_obstacle_debug(agent_position, vector_origin)
	if show_hand_flee:
		_draw_hand_flee(agent_position, vector_origin)
	if kind == "Hushling":
		_draw_hushling_debug(agent_position)
	if show_state_label:
		_draw_state_label(kind, agent_position)


func _resolve_target() -> void:
	_target = null
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		_target = get_parent() as Node3D


func _resolve_debug_draw() -> void:
	_debug_draw_3d = null
	if Engine.has_singleton("DebugDraw3D"):
		_debug_draw_3d = Engine.get_singleton("DebugDraw3D")


func _create_draw_config() -> Variant:
	var config: Variant = _debug_draw_3d.call("new_scoped_config")
	if config == null:
		return null

	config.call("set_thickness", line_thickness)
	config.call("set_center_brightness", center_brightness)
	config.call("set_no_depth_test", draw_without_depth_test)
	return config


func _resolved_agent_kind() -> String:
	if agent_kind != "Auto":
		return agent_kind
	if _target.is_in_group(&"hushling"):
		return "Hushling"
	if _target.is_in_group(&"interest_entity"):
		return "Crawler"
	return "Agent"


func _draw_movement_vectors(origin: Vector3) -> void:
	var facing: Vector3 = _safe_direction(
		_read_vector(&"direction", Vector3.FORWARD),
		_read_vector(&"target_direction", Vector3.FORWARD)
	)
	_draw_arrow(origin, facing * direction_vector_length, FACING_COLOR)
	_draw_arrow(origin + Vector3.UP * 0.025, _read_vector(&"desired_velocity", Vector3.ZERO) * velocity_vector_scale, DESIRED_VELOCITY_COLOR)
	_draw_arrow(origin + Vector3.UP * 0.05, _read_vector(&"velocity", Vector3.ZERO) * velocity_vector_scale, VELOCITY_COLOR)
	_draw_arrow(origin + Vector3.UP * 0.075, _read_vector(&"steering_force", Vector3.ZERO) * force_vector_scale, STEERING_FORCE_COLOR)

	if show_final_velocity:
		var final_velocity: Vector3 = _read_vector(&"final_velocity", Vector3.ZERO)
		if final_velocity.distance_to(_read_vector(&"velocity", Vector3.ZERO)) > 0.01:
			_draw_arrow(origin + Vector3.UP * 0.1, final_velocity * velocity_vector_scale, FINAL_VELOCITY_COLOR)


func _draw_hushling_debug(agent_position: Vector3) -> void:
	if show_hushling_ranges:
		_draw_wire_sphere(agent_position, _read_float(&"awareness_radius", 0.0), AWARENESS_COLOR)
		_draw_wire_sphere(agent_position, _read_float(&"observe_distance", 0.0), OBSERVE_COLOR)
		_draw_wire_sphere(agent_position, _effective_flee_radius(), FLEE_RADIUS_COLOR)
		_draw_wire_sphere(agent_position, _read_float(&"separation_radius", 0.0), SEPARATION_COLOR)

	if show_target_ray and _read_bool(&"debug_has_target", false):
		var target_position: Vector3 = _read_vector(&"debug_target_position", agent_position)
		_debug_draw_3d.call("draw_line", agent_position, target_position, TARGET_COLOR)
		_debug_draw_3d.call("draw_position", Transform3D(Basis.IDENTITY, target_position), TARGET_COLOR)


func _draw_obstacle_debug(agent_position: Vector3, vector_origin: Vector3) -> void:
	var feeler_length: float = _read_float(&"obstacle_feeler_length", 0.0)
	if feeler_length > 0.0:
		_draw_obstacle_feelers(agent_position, feeler_length)

	_draw_arrow(
		vector_origin,
		_read_vector(&"obstacle_avoidance_force", Vector3.ZERO) * force_vector_scale,
		OBSTACLE_FORCE_COLOR
	)

	if not _read_bool(&"debug_obstacle_hit", false):
		return

	var hit_position: Vector3 = _read_vector(&"debug_obstacle_hit_position", agent_position)
	var hit_normal: Vector3 = _safe_direction(_read_vector(&"debug_obstacle_hit_normal", Vector3.UP), Vector3.UP)
	_debug_draw_3d.call("draw_position", Transform3D(Basis.IDENTITY, hit_position), OBSTACLE_HIT_COLOR)
	_debug_draw_3d.call("draw_line", hit_position, hit_position + hit_normal * 0.14, OBSTACLE_HIT_COLOR)


func _draw_hand_flee(agent_position: Vector3, vector_origin: Vector3) -> void:
	if not _read_bool(&"debug_player_hand_flee_active", false):
		return

	var flee_direction: Vector3 = _safe_direction(
		_read_vector(&"steering_force", Vector3.ZERO),
		_read_vector(&"desired_velocity", Vector3.FORWARD)
	)
	_draw_arrow(vector_origin + Vector3.UP * 0.06, flee_direction * hand_indicator_length, HAND_FLEE_COLOR)
	_debug_draw_3d.call(
		"draw_text",
		agent_position + Vector3.UP * (label_height + 0.14),
		"HAND FLEE",
		label_font_size,
		HAND_FLEE_COLOR,
		0.0
	)


func _draw_state_label(kind: String, agent_position: Vector3) -> void:
	_debug_draw_3d.call(
		"draw_text",
		agent_position + Vector3.UP * label_height,
		_label_text(kind),
		label_font_size,
		LABEL_COLOR,
		0.0
	)


func _label_text(kind: String) -> String:
	var state: String = _read_string(&"current_state", kind)
	var speed: float = _read_vector(&"velocity", Vector3.ZERO).length()
	if kind == "Hushling":
		return "%s | %s | %.2f | group %d" % [
			_target.name,
			state,
			speed,
			_read_int(&"debug_neighbour_count", 0) + 1,
		]
	return "%s | %s | %.2f" % [_target.name, state, speed]


func _draw_obstacle_feelers(origin: Vector3, feeler_length: float) -> void:
	var forward: Vector3 = _safe_direction(
		_read_vector(&"desired_velocity", Vector3.ZERO),
		_read_vector(&"direction", Vector3.FORWARD)
	)
	var angle: float = deg_to_rad(_read_float(&"obstacle_feeler_angle_degrees", 34.0))
	var right_axis: Vector3 = _safe_direction(forward.cross(Vector3.UP), Vector3.RIGHT)

	_draw_feeler(origin, forward, feeler_length)
	_draw_feeler(origin, Quaternion(Vector3.UP, angle) * forward, feeler_length)
	_draw_feeler(origin, Quaternion(Vector3.UP, -angle) * forward, feeler_length)
	_draw_feeler(origin, Quaternion(right_axis, angle) * forward, feeler_length)
	_draw_feeler(origin, Quaternion(right_axis, -angle) * forward, feeler_length)


func _draw_feeler(origin: Vector3, direction: Vector3, length: float) -> void:
	_debug_draw_3d.call("draw_line", origin, origin + direction.normalized() * length, OBSTACLE_FEELER_COLOR)


func _draw_arrow(start_position: Vector3, vector: Vector3, color: Color) -> void:
	if vector.length_squared() <= 0.0001:
		return

	var end_position: Vector3 = start_position + vector
	_debug_draw_3d.call("draw_line", start_position, end_position, color)

	var forward: Vector3 = vector.normalized()
	var side_axis: Vector3 = _safe_direction(forward.cross(Vector3.UP), Vector3.RIGHT)
	var up_axis: Vector3 = _safe_direction(side_axis.cross(forward), Vector3.UP)
	var head_length: float = min(arrow_head_size, vector.length() * 0.28)
	var head_width: float = head_length * 0.55
	var head_base: Vector3 = end_position - forward * head_length

	_debug_draw_3d.call("draw_line", end_position, head_base + side_axis * head_width, color)
	_debug_draw_3d.call("draw_line", end_position, head_base - side_axis * head_width, color)
	_debug_draw_3d.call("draw_line", end_position, head_base + up_axis * head_width, color)


func _draw_wire_sphere(center: Vector3, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return

	_draw_ring(center, radius, Vector3.RIGHT, Vector3.FORWARD, color)
	_draw_ring(center, radius, Vector3.RIGHT, Vector3.UP, color)
	_draw_ring(center, radius, Vector3.FORWARD, Vector3.UP, color)


func _draw_ring(center: Vector3, radius: float, axis_a: Vector3, axis_b: Vector3, color: Color) -> void:
	var previous: Vector3 = center + Vector3(radius, 0.0, 0.0)
	previous = center + axis_a * radius
	for index in range(1, ring_segments + 1):
		var angle: float = TAU * float(index) / float(ring_segments)
		var next: Vector3 = center + axis_a * cos(angle) * radius + axis_b * sin(angle) * radius
		_debug_draw_3d.call("draw_line", previous, next, color)
		previous = next


func _effective_flee_radius() -> float:
	var interest_flee_radius: float = _read_float(&"debug_effective_interest_flee_radius", 0.0)
	if interest_flee_radius > 0.0:
		return interest_flee_radius
	return max(_read_float(&"interest_flee_radius", 0.0), _read_float(&"flee_radius", 0.0))


func _read_vector(property_name: StringName, fallback: Vector3) -> Vector3:
	var value: Variant = _target.get(property_name)
	if value is Vector3:
		return value
	return fallback


func _read_float(property_name: StringName, fallback: float) -> float:
	var value: Variant = _target.get(property_name)
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback


func _read_int(property_name: StringName, fallback: int) -> int:
	var value: Variant = _target.get(property_name)
	if value is int:
		return value
	if value is float:
		return int(value)
	return fallback


func _read_bool(property_name: StringName, fallback: bool) -> bool:
	var value: Variant = _target.get(property_name)
	if value is bool:
		return value
	return fallback


func _read_string(property_name: StringName, fallback: String) -> String:
	var value: Variant = _target.get(property_name)
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		return str(value)
	return fallback


func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		return fallback.normalized() if fallback.length_squared() > 0.0001 else Vector3.FORWARD
	return value.normalized()
