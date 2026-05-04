extends Node3D
class_name AgentDebugDraw

@export_group("Debug")
@export var debug_enabled: bool = true
@export var target_path: NodePath
@export var toggle_key: Key = KEY_G

@export_group("Display")
@export var show_home_volume: bool = true
@export var show_velocity: bool = true
@export var show_desired_velocity: bool = true
@export var show_steering_force: bool = true
@export var show_final_velocity: bool = true
@export var show_wander_direction: bool = true
@export var show_state_label: bool = true
@export var show_2d_overlay: bool = true
@export_range(0.001, 0.2, 0.001) var line_thickness: float = 0.025
@export_range(0.0, 1.0, 0.01) var center_brightness: float = 0.7
@export_range(0.01, 10.0, 0.01) var velocity_vector_scale: float = 1.0
@export_range(0.01, 10.0, 0.01) var force_vector_scale: float = 2.2
@export_range(0.01, 1.0, 0.01) var arrow_head_size: float = 0.08
@export_range(0.0, 1.0, 0.01) var vector_vertical_offset: float = 0.28
@export_range(0.1, 3.0, 0.01) var label_height: float = 0.62
@export var draw_without_depth_test: bool = false
@export var fallback_state_name: String = "STEERING"

@export_group("Colours")
@export var home_volume_color: Color = Color(0.22, 0.75, 1.0, 0.34)
@export var home_line_color: Color = Color(0.35, 0.65, 0.9, 0.55)
@export var wander_direction_color: Color = Color(0.15, 0.95, 0.95, 1.0)
@export var velocity_color: Color = Color(0.2, 0.45, 1.0, 1.0)
@export var desired_velocity_color: Color = Color(0.15, 0.9, 0.25, 1.0)
@export var steering_force_color: Color = Color(1.0, 0.85, 0.1, 1.0)
@export var final_velocity_color: Color = Color(0.75, 0.25, 1.0, 1.0)
@export var label_color: Color = Color(0.85, 0.96, 1.0, 1.0)

var _target: Node3D


func _ready() -> void:
	_resolve_target()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		debug_enabled = not debug_enabled


func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		_resolve_target()

	if _target == null:
		return

	if not debug_enabled:
		_clear_overlay()
		return

	var debug_config = DebugDraw3D.new_scoped_config()
	debug_config.set_thickness(line_thickness)
	debug_config.set_center_brightness(center_brightness)
	debug_config.set_no_depth_test(draw_without_depth_test)

	_draw_debug()
	_update_overlay()


func _resolve_target() -> void:
	_target = null
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node3D

	if _target == null:
		_target = get_parent() as Node3D


func _draw_debug() -> void:
	var agent_position: Vector3 = _target.global_position
	var vector_origin: Vector3 = agent_position + Vector3.UP * vector_vertical_offset
	var home_position: Vector3 = _read_vector_property(&"home_position", agent_position)
	var home_radius: float = _read_float_property(&"home_radius", 0.0)

	if show_home_volume and home_radius > 0.0:
		DebugDraw3D.draw_sphere(home_position, home_radius, home_volume_color)
		DebugDraw3D.draw_line(home_position, agent_position, home_line_color)

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

	if show_state_label:
		DebugDraw3D.draw_text(
			agent_position + Vector3.UP * label_height,
			_get_agent_label_text(),
			24,
			label_color,
			0.0
		)


func _draw_arrow(start_position: Vector3, vector: Vector3, color: Color) -> void:
	if vector.length_squared() <= 0.0001:
		return

	DebugDraw3D.draw_arrow(start_position, start_position + vector, color, arrow_head_size)


func _update_overlay() -> void:
	if not show_2d_overlay:
		_clear_overlay()
		return

	var velocity: Vector3 = _read_vector_property(&"velocity", Vector3.ZERO)
	var desired_velocity: Vector3 = _read_vector_property(&"desired_velocity", Vector3.ZERO)
	var steering_force: Vector3 = _read_vector_property(&"steering_force", Vector3.ZERO)

	DebugDraw2D.set_text("Hushlings/debug", "G toggles agent debug")
	DebugDraw2D.set_text("Agent/state", _read_string_property(&"current_state", fallback_state_name))
	DebugDraw2D.set_text("Agent/speed", "%.3f" % velocity.length())
	DebugDraw2D.set_text("Agent/desired_velocity", _format_vector(desired_velocity))
	DebugDraw2D.set_text("Agent/steering_force", _format_vector(steering_force))


func _clear_overlay() -> void:
	DebugDraw2D.set_text("Hushlings/debug", "")
	DebugDraw2D.set_text("Agent/state", "")
	DebugDraw2D.set_text("Agent/speed", "")
	DebugDraw2D.set_text("Agent/desired_velocity", "")
	DebugDraw2D.set_text("Agent/steering_force", "")


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


func _read_string_property(property_name: StringName, fallback: String) -> String:
	var value: Variant = _target.get(property_name)
	if value is String:
		return value
	if value != null:
		return str(value)
	return fallback


func _format_vector(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
