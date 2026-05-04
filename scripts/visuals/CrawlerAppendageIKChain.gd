@tool
extends Node3D
class_name CrawlerAppendageIKChain

const VALID_STATES := ["IDLE", "WANDER", "OBSERVE", "FLEE", "STARTLED", "CONFIDENT"]
const GENERATED_META := "crawler_ik_generated"

@export_group("Chain")
@export_range(2, 12, 1) var segment_count: int = 5:
	set(value):
		segment_count = max(value, 2)
		_rebuild_requested = true
@export_range(0.025, 0.28, 0.005) var segment_length: float = 0.08:
	set(value):
		segment_length = max(value, 0.02)
		_rebuild_requested = true
@export_range(0.003, 0.06, 0.001) var base_radius: float = 0.012:
	set(value):
		base_radius = max(value, 0.002)
@export_range(0.1, 0.9, 0.01) var tip_radius_factor: float = 0.34
@export var rest_direction: Vector3 = Vector3.LEFT
@export var segment_material: Material

@export_group("Role")
@export_enum("FEELER", "SWEEPER", "STABILIZER") var behavior_role: String = "SWEEPER"
@export_range(-1.0, 1.0, 0.01) var side_sign: float = 1.0

@export_group("Motion")
@export_range(0.2, 24.0, 0.1) var follow_speed: float = 5.4
@export_range(0.0, 3.0, 0.01) var trail_strength: float = 0.82
@export_range(0.0, 2.5, 0.01) var sweep_strength: float = 0.62
@export_range(0.0, 2.5, 0.01) var probe_strength: float = 0.45
@export_range(0.0, 1.5, 0.01) var curl_strength: float = 0.5
@export_range(0.0, 1.5, 0.01) var downward_bias: float = 0.22
@export_range(0.1, 5.0, 0.01) var stroke_frequency: float = 0.36
@export var phase: float = 0.0
@export var auto_update: bool = true

@export_group("State")
@export_enum("IDLE", "WANDER", "OBSERVE", "FLEE", "STARTLED", "CONFIDENT") var visual_state: String = "WANDER"

var _joints: Array[Vector3] = []
var _segments: Array[MeshInstance3D] = []
var _tip_node: MeshInstance3D
var _smoothed_target: Vector3 = Vector3.ZERO
var _world_velocity: Vector3 = Vector3.ZERO
var _agent_trail_strength: float = 1.0
var _agent_sweep_strength: float = 1.0
var _agent_probe_strength: float = 1.0
var _agent_follow_speed: float = 1.0
var _locomotion_phase: float = 0.0
var _body_pulse: float = 0.0
var _state_follow_speed: float = 1.0
var _time: float = 0.0
var _rebuild_requested: bool = false


func _ready() -> void:
	build_chain()
	set_process(auto_update or Engine.is_editor_hint())


func _process(delta: float) -> void:
	if _rebuild_requested:
		build_chain()
	if auto_update or Engine.is_editor_hint():
		animate(delta)


func build_chain() -> void:
	_rebuild_requested = false
	_clear_generated_segments()
	_prepare_joints()

	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.radial_segments = 7
	cylinder_mesh.rings = 1
	cylinder_mesh.height = 1.0
	cylinder_mesh.top_radius = 1.0
	cylinder_mesh.bottom_radius = 1.0

	for i in range(segment_count):
		var segment := MeshInstance3D.new()
		segment.name = "IKSegment%02d" % i
		segment.mesh = cylinder_mesh
		segment.material_override = segment_material
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segment.set_meta(GENERATED_META, true)
		add_child(segment)
		_segments.append(segment)

	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 1.0
	tip_mesh.height = 2.0
	tip_mesh.radial_segments = 7
	tip_mesh.rings = 4

	_tip_node = MeshInstance3D.new()
	_tip_node.name = "IKTip"
	_tip_node.mesh = tip_mesh
	_tip_node.material_override = segment_material
	_tip_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tip_node.set_meta(GENERATED_META, true)
	add_child(_tip_node)

	_draw_segments()


func set_motion_context(
		world_velocity: Vector3,
		state_name: String,
		locomotion_phase: float,
		body_pulse: float,
		agent_trail_strength: float,
		agent_sweep_strength: float,
		agent_probe_strength: float,
		agent_follow_speed: float
) -> void:
	_world_velocity = world_velocity
	visual_state = _normalized_state(state_name)
	_locomotion_phase = locomotion_phase
	_body_pulse = body_pulse
	_agent_trail_strength = agent_trail_strength
	_agent_sweep_strength = agent_sweep_strength
	_agent_probe_strength = agent_probe_strength
	_agent_follow_speed = agent_follow_speed


func animate(delta: float) -> void:
	if _joints.is_empty():
		_prepare_joints()

	_time += delta
	var desired_target: Vector3 = _compute_desired_target()
	var follow_alpha: float = 1.0 - exp(-max(follow_speed * _agent_follow_speed * _state_follow_speed, 0.01) * delta)
	_smoothed_target = _smoothed_target.lerp(desired_target, follow_alpha)
	_solve_fabrik(_smoothed_target)
	_draw_segments()


func _prepare_joints() -> void:
	_joints.clear()
	_joints.resize(segment_count + 1)

	var direction: Vector3 = _safe_direction(rest_direction + Vector3.DOWN * downward_bias, Vector3.LEFT)
	for i in range(segment_count + 1):
		_joints[i] = direction * segment_length * float(i)

	_smoothed_target = _joints[segment_count]


func _compute_desired_target() -> Vector3:
	var state: String = _normalized_state(visual_state)
	var state_trail: float = 0.75
	var state_sweep: float = 0.80
	var state_probe: float = 0.52
	var state_curl: float = 0.25
	var state_reach: float = 0.82
	var state_follow: float = 1.0
	var state_down: float = 1.0

	match state:
		"IDLE":
			state_trail = 0.24
			state_sweep = 0.32
			state_probe = 0.46
			state_curl = 0.22
			state_reach = 0.74
		"WANDER":
			state_trail = 0.92
			state_sweep = 1.0
			state_probe = 0.62
			state_reach = 0.88
		"OBSERVE":
			state_trail = 0.16
			state_sweep = 0.14
			state_probe = 1.18
			state_curl = 0.06
			state_reach = 0.94
			state_follow = 0.72
			state_down = 0.58
		"FLEE":
			state_trail = 2.0
			state_sweep = 1.45
			state_probe = 0.22
			state_curl = 0.12
			state_reach = 0.98
			state_follow = 1.65
			state_down = 0.70
		"STARTLED":
			state_trail = 0.12
			state_sweep = 0.08
			state_probe = 0.08
			state_curl = 1.45
			state_reach = 0.36
			state_follow = 2.25
			state_down = 0.12
		"CONFIDENT":
			state_trail = 0.38
			state_sweep = 0.30
			state_probe = 0.85
			state_curl = 0.05
			state_reach = 0.90
			state_follow = 0.76
			state_down = 0.42

	_state_follow_speed = state_follow

	var role: String = behavior_role.strip_edges().to_upper()
	var local_velocity: Vector3 = global_transform.basis.inverse() * _world_velocity
	local_velocity.y *= 0.18
	var speed_factor: float = clamp(local_velocity.length() / 1.25, 0.0, 1.0)
	var outward: Vector3 = _safe_direction(rest_direction, Vector3.LEFT * signf(side_sign))
	var side: Vector3 = Vector3.RIGHT * signf(side_sign)
	var total_length: float = segment_length * float(segment_count)
	var stroke: float = sin(_time * TAU * stroke_frequency + _locomotion_phase + phase)
	var counter_stroke: float = cos(_time * TAU * stroke_frequency * 0.47 + phase * 1.7)
	var target_vector: Vector3 = outward * 0.58 + Vector3.DOWN * downward_bias * state_down

	if role == "FEELER":
		target_vector = Vector3.FORWARD * probe_strength * _agent_probe_strength * state_probe
		target_vector += outward * 0.22
		target_vector += side * counter_stroke * 0.06
		if local_velocity.length_squared() > 0.0001:
			target_vector += -local_velocity.normalized() * trail_strength * 0.20 * speed_factor
	elif role == "STABILIZER":
		target_vector = outward * 0.72 + Vector3.DOWN * downward_bias * state_down * 0.65
		target_vector += -Vector3.FORWARD * 0.16
		target_vector += side * stroke * sweep_strength * _agent_sweep_strength * state_sweep * 0.32
	else:
		target_vector = outward * 0.48 + Vector3.DOWN * downward_bias * state_down
		target_vector += -Vector3.FORWARD * stroke * sweep_strength * _agent_sweep_strength * state_sweep
		target_vector += side * counter_stroke * 0.08

	if local_velocity.length_squared() > 0.0001:
		target_vector += -local_velocity.normalized() * trail_strength * _agent_trail_strength * state_trail * speed_factor

	if state == "STARTLED":
		target_vector = -outward * curl_strength * state_curl + Vector3.UP * 0.42 + Vector3.FORWARD * 0.18

	target_vector += Vector3.UP * _body_pulse * 0.07
	return _safe_direction(target_vector, Vector3.DOWN) * total_length * state_reach


func _solve_fabrik(target: Vector3) -> void:
	var root: Vector3 = Vector3.ZERO
	var total_length: float = segment_length * float(segment_count)

	if target.length() >= total_length:
		var direction: Vector3 = _safe_direction(target, Vector3.DOWN)
		_joints[0] = root
		for i in range(1, segment_count + 1):
			_joints[i] = _joints[i - 1] + direction * segment_length
		return

	_joints[segment_count] = target
	for i in range(segment_count - 1, -1, -1):
		var direction_to_parent: Vector3 = _safe_direction(_joints[i] - _joints[i + 1], Vector3.DOWN)
		_joints[i] = _joints[i + 1] + direction_to_parent * segment_length

	_joints[0] = root
	for i in range(segment_count):
		var direction_to_child: Vector3 = _safe_direction(_joints[i + 1] - _joints[i], Vector3.DOWN)
		_joints[i + 1] = _joints[i] + direction_to_child * segment_length


func _draw_segments() -> void:
	for i in range(min(segment_count, _segments.size())):
		var start: Vector3 = _joints[i]
		var finish: Vector3 = _joints[i + 1]
		var delta: Vector3 = finish - start
		var length: float = delta.length()
		if length <= 0.001:
			continue

		var taper: float = float(i) / max(float(segment_count - 1), 1.0)
		var radius: float = base_radius * lerp(1.0, tip_radius_factor, taper)
		var segment: MeshInstance3D = _segments[i]
		segment.transform = Transform3D(_basis_from_y_axis(delta / length), (start + finish) * 0.5)
		segment.scale = Vector3(radius, length, radius)

	if _tip_node:
		var tip_radius: float = base_radius * tip_radius_factor * 1.35
		_tip_node.position = _joints[segment_count]
		_tip_node.scale = Vector3.ONE * tip_radius


func _basis_from_y_axis(y_axis: Vector3) -> Basis:
	var y: Vector3 = _safe_direction(y_axis, Vector3.DOWN)
	var seed: Vector3 = Vector3.FORWARD
	if absf(y.dot(seed)) > 0.92:
		seed = Vector3.RIGHT
	var x: Vector3 = seed.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	return Basis(x, y, z)


func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() < 0.0001:
		return fallback.normalized()
	return value.normalized()


func _normalized_state(state_name: String) -> String:
	var normalized: String = state_name.strip_edges().to_upper()
	if VALID_STATES.has(normalized):
		return normalized
	return "IDLE"


func _clear_generated_segments() -> void:
	for child in get_children():
		if child.get_meta(GENERATED_META, false):
			child.free()
	_segments.clear()
	_tip_node = null
