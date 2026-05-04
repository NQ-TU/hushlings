@tool
extends Node3D
class_name HushlingTentacleIKChain

const VALID_STATES := [
	"IDLE",
	"WANDER",
	"REGROUP",
	"OBSERVE",
	"FOLLOW",
	"FLEE",
	"STARTLED",
	"CONFIDENT",
]
const GENERATED_META := "hushling_ik_generated"

@export_group("Chain")
@export_storage var segment_count: int = 7:
	set(value):
		segment_count = max(value, 3)
		_rebuild_requested = true
@export_storage var segment_length: float = 0.13:
	set(value):
		segment_length = max(value, 0.03)
		_rebuild_requested = true
@export_storage var base_radius: float = 0.034:
	set(value):
		base_radius = max(value, 0.004)
@export_storage var tip_radius_factor: float = 0.30
@export_storage var rest_direction: Vector3 = Vector3.RIGHT
@export_storage var segment_material: Material
@export_storage var solver_iterations: int = 2

@export_group("Motion")
@export_storage var follow_speed: float = 4.8
@export_storage var trail_strength: float = 0.80
@export_storage var spread_strength: float = 0.92
@export_storage var curl_strength: float = 0.58
@export_storage var sway_amount: float = 0.055
@export_storage var sway_frequency: float = 0.44
@export_storage var movement_flail_strength: float = 0.36
@export_storage var movement_flail_frequency: float = 1.28
@export_storage var movement_flail_vertical: float = 0.34
@export_storage var rigid_base_segments: int = 2
@export_storage var base_rigidity: float = 0.78
@export_storage var distal_drag_bias: float = 0.42
@export_storage var turn_drag_strength: float = 0.55
@export_storage var rest_shape_strength: float = 0.28
@export_storage var inward_hook_guard: float = 0.62
@export_storage var phase: float = 0.0
@export_storage var auto_update: bool = true

@export_group("State")
@export_storage var visual_state: String = "WANDER"

var _joints: Array[Vector3] = []
var _segments: Array[MeshInstance3D] = []
var _tip_node: MeshInstance3D
var _smoothed_target: Vector3 = Vector3.ZERO
var _world_velocity: Vector3 = Vector3.ZERO
var _target_direction: Vector3 = Vector3.FORWARD
var _agent_trail_strength: float = 1.0
var _agent_spread_strength: float = 1.0
var _agent_sway_amount: float = 1.0
var _agent_follow_speed: float = 1.0
var _agent_curl_strength: float = 1.0
var _agent_turn_swing: float = 0.0
var _agent_flail_strength: float = 1.0
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
	cylinder_mesh.radial_segments = 8
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
	tip_mesh.radial_segments = 8
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
		target_direction: Vector3,
		state_name: String,
		agent_trail_strength: float,
		agent_spread_strength: float,
		agent_sway_amount: float,
		agent_follow_speed: float,
		agent_curl_strength: float,
		agent_turn_swing: float,
		agent_flail_strength: float = 1.0
) -> void:
	_world_velocity = world_velocity
	_target_direction = target_direction
	visual_state = _normalized_state(state_name)
	_agent_trail_strength = agent_trail_strength
	_agent_spread_strength = agent_spread_strength
	_agent_sway_amount = agent_sway_amount
	_agent_follow_speed = agent_follow_speed
	_agent_curl_strength = agent_curl_strength
	_agent_turn_swing = clamp(agent_turn_swing, -1.0, 1.0)
	_agent_flail_strength = max(agent_flail_strength, 0.0)


func animate(delta: float) -> void:
	if _joints.is_empty():
		_prepare_joints()

	_time += delta
	var desired_target: Vector3 = _compute_desired_target()
	var follow_alpha: float = 1.0 - exp(-max(follow_speed * _agent_follow_speed * _state_follow_speed, 0.01) * delta)
	_smoothed_target = _smoothed_target.lerp(desired_target, follow_alpha)
	_solve_fabrik(_smoothed_target)
	_apply_rigidity_profile()
	_draw_segments()


func _prepare_joints() -> void:
	_joints.clear()
	_joints.resize(segment_count + 1)

	var direction: Vector3 = _safe_direction(rest_direction, Vector3.RIGHT)
	for i in range(segment_count + 1):
		_joints[i] = direction * segment_length * float(i)

	_smoothed_target = _joints[segment_count]


func _compute_desired_target() -> Vector3:
	var state: String = _normalized_state(visual_state)
	var state_spread: float = 0.88
	var state_trail: float = 0.55
	var state_sway: float = 0.70
	var state_reach: float = 0.96
	var state_forward_cup: float = 0.10
	var state_follow: float = 1.0
	var state_target_pull: float = 0.0
	var state_turn_drag: float = 0.85
	var state_flail: float = _state_flail_scale(state)
	var curl_inward: bool = false

	match state:
		"IDLE":
			state_spread = 0.78
			state_trail = 0.28
			state_sway = 0.55
			state_reach = 0.94
			state_turn_drag = 0.45
		"WANDER":
			state_spread = 0.92
			state_trail = 0.82
			state_sway = 0.70
			state_reach = 0.98
			state_forward_cup = 0.15
			state_turn_drag = 0.95
		"REGROUP":
			state_spread = 0.96
			state_trail = 0.32
			state_sway = 0.38
			state_reach = 0.98
			state_target_pull = 0.35
			state_follow = 0.86
			state_turn_drag = 0.75
		"OBSERVE":
			state_spread = 1.02
			state_trail = 0.14
			state_sway = 0.16
			state_reach = 0.99
			state_forward_cup = 0.04
			state_target_pull = 0.24
			state_follow = 0.70
			state_turn_drag = 0.38
		"FOLLOW":
			state_spread = 0.90
			state_trail = 1.28
			state_sway = 0.62
			state_reach = 0.98
			state_forward_cup = 0.18
			state_target_pull = 0.14
			state_follow = 1.18
			state_turn_drag = 1.05
		"FLEE":
			state_spread = 0.44
			state_trail = 1.42
			state_sway = 0.28
			state_reach = 0.98
			state_forward_cup = -0.08
			state_follow = 1.55
			state_turn_drag = 1.25
		"STARTLED":
			state_spread = 0.08
			state_trail = 0.10
			state_sway = 0.08
			state_reach = 0.38
			state_target_pull = 0.18
			state_follow = 2.0
			state_turn_drag = 0.22
			curl_inward = true
		"CONFIDENT":
			state_spread = 1.22
			state_trail = 0.28
			state_sway = 0.30
			state_reach = 0.99
			state_forward_cup = 0.08
			state_follow = 0.74
			state_turn_drag = 0.62

	_state_follow_speed = state_follow

	var radial_outward: Vector3 = _radial_outward()
	var outward: Vector3 = _rest_outward(radial_outward)
	var tangent: Vector3 = _ring_tangent(radial_outward)

	var local_velocity: Vector3 = global_transform.basis.inverse() * _world_velocity
	local_velocity.y *= 0.65
	var local_target: Vector3 = global_transform.basis.inverse() * _target_direction
	var speed_factor: float = clamp(local_velocity.length() / 1.25, 0.0, 1.0)
	var total_length: float = segment_length * float(segment_count)
	var wave: float = sin(_time * TAU * sway_frequency + phase)
	var secondary_wave: float = cos(_time * TAU * sway_frequency * 0.57 + phase * 1.61)
	var flail_factor: float = clamp(speed_factor + absf(_agent_turn_swing) * 0.55, 0.0, 1.0)
	var flail_amount: float = movement_flail_strength * _agent_flail_strength * state_flail * flail_factor

	var target_vector: Vector3 = outward * spread_strength * _agent_spread_strength * state_spread
	target_vector += Vector3.BACK * state_forward_cup
	target_vector += _safe_direction(local_target, Vector3.FORWARD) * state_target_pull

	if local_velocity.length_squared() > 0.0001:
		target_vector += -local_velocity.normalized() * trail_strength * _agent_trail_strength * state_trail * speed_factor

	target_vector += -tangent \
			* _agent_turn_swing \
			* turn_drag_strength \
			* state_turn_drag \
			* (0.35 + speed_factor * 0.65)
	target_vector += tangent * wave * sway_amount * _agent_sway_amount * state_sway
	target_vector += Vector3.FORWARD * secondary_wave * sway_amount * _agent_sway_amount * state_sway * 0.38
	if flail_amount > 0.001:
		var velocity_direction: Vector3 = _safe_direction(local_velocity, Vector3.FORWARD)
		var velocity_cross: Vector3 = velocity_direction.cross(outward)
		if velocity_cross.length_squared() <= 0.0001:
			velocity_cross = tangent
		velocity_cross = velocity_cross.normalized()

		var flail_wave: float = sin(_time * TAU * movement_flail_frequency + phase * 1.37)
		var cross_wave: float = cos(_time * TAU * movement_flail_frequency * 0.71 + phase * 2.11)
		var vertical_wave: float = sin(_time * TAU * movement_flail_frequency * 1.73 + phase * 0.83)
		var flail_direction: Vector3 = _safe_direction(
			tangent * flail_wave + velocity_cross * cross_wave * 0.55 + Vector3.UP * vertical_wave * movement_flail_vertical,
			tangent
		)
		target_vector += flail_direction * flail_amount
		target_vector += -velocity_direction * absf(cross_wave) * flail_amount * 0.18

	var curl_amount: float = curl_strength * _agent_curl_strength
	if curl_inward:
		target_vector = -radial_outward * curl_amount + Vector3.BACK * 0.24 + tangent * wave * 0.06
	elif curl_amount > 0.05:
		var curl_target: Vector3 = _safe_direction(-radial_outward + Vector3.BACK * 0.18, outward)
		target_vector = target_vector.lerp(curl_target, clamp(curl_amount * 0.22, 0.0, 0.85))

	return _safe_direction(target_vector, outward) * total_length * state_reach


func _apply_rigidity_profile() -> void:
	if _joints.size() < 2:
		return

	var radial_outward: Vector3 = _radial_outward()
	var outward: Vector3 = _rest_outward(radial_outward)
	var local_velocity: Vector3 = global_transform.basis.inverse() * _world_velocity
	local_velocity.y *= 0.65
	var speed_factor: float = clamp(local_velocity.length() / 1.25, 0.0, 1.0)
	var drag_direction: Vector3 = Vector3.ZERO
	if local_velocity.length_squared() > 0.0001:
		drag_direction = -local_velocity.normalized()
	var tangent: Vector3 = _ring_tangent(radial_outward)
	var turn_drag_direction: Vector3 = -tangent * _agent_turn_swing
	var flail_factor: float = clamp(speed_factor + absf(_agent_turn_swing) * 0.55, 0.0, 1.0)
	var flail_amount: float = movement_flail_strength \
			* _agent_flail_strength \
			* _state_flail_scale(visual_state) \
			* flail_factor
	var curl_amount: float = curl_strength * _agent_curl_strength

	var state_drag_scale: float = 1.0
	var state_turn_drag_scale: float = 1.0
	var state_base_scale: float = 1.0
	var state_rest_scale: float = 1.0
	match _normalized_state(visual_state):
		"FLEE":
			state_drag_scale = 1.08
			state_turn_drag_scale = 1.18
			state_base_scale = 1.12
			state_rest_scale = 0.82
		"STARTLED":
			state_drag_scale = 0.22
			state_turn_drag_scale = 0.18
			state_base_scale = 1.35
			state_rest_scale = 0.18
		"OBSERVE":
			state_drag_scale = 0.35
			state_turn_drag_scale = 0.35
			state_base_scale = 1.18
			state_rest_scale = 1.15
		"FOLLOW":
			state_drag_scale = 1.12
			state_turn_drag_scale = 1.05
			state_rest_scale = 0.86

	var base_count: int = max(rigid_base_segments, 0)
	var total_length: float = segment_length * float(segment_count)
	var rest_shape_amount: float = rest_shape_strength * state_rest_scale * (1.0 - clamp(curl_amount * 0.42, 0.0, 0.75))
	for i in range(1, segment_count + 1):
		var along: float = float(i) / float(segment_count)
		var base_profile: float = 0.0
		if base_count > 0 and i <= base_count:
			base_profile = 1.0 - float(i - 1) / float(base_count)

		var stiffness: float = clamp(base_rigidity * state_base_scale * base_profile, 0.0, 1.0)
		var rest_position: Vector3 = _rest_position_for_joint(i, along, outward)
		var rest_profile: float = rest_shape_amount * lerp(0.35, 1.0, 1.0 - along)
		var rest_alpha: float = max(stiffness, rest_profile)
		_joints[i] = _joints[i].lerp(rest_position, clamp(rest_alpha, 0.0, 1.0))

		var flexible_profile: float = pow(along, 1.8) * (1.0 - stiffness)
		if drag_direction.length_squared() > 0.0001:
			_joints[i] += drag_direction \
					* distal_drag_bias \
					* _agent_trail_strength \
					* state_drag_scale \
					* speed_factor \
					* total_length \
					* 0.16 \
					* flexible_profile
		if absf(_agent_turn_swing) > 0.001:
			_joints[i] += turn_drag_direction \
					* distal_drag_bias \
					* turn_drag_strength \
					* state_turn_drag_scale \
					* total_length \
					* 0.20 \
					* flexible_profile
		if flail_amount > 0.001:
			var joint_phase: float = phase + along * 1.9
			var tip_wave: float = sin(_time * TAU * movement_flail_frequency * 1.17 + joint_phase)
			var vertical_wave: float = cos(_time * TAU * movement_flail_frequency * 0.93 + joint_phase * 1.31)
			_joints[i] += (tangent * tip_wave + Vector3.UP * vertical_wave * movement_flail_vertical) \
					* flail_amount \
					* total_length \
					* 0.08 \
					* flexible_profile

	_guard_against_inward_hook(radial_outward, curl_amount)
	_enforce_lengths_from_root()


func _enforce_lengths_from_root() -> void:
	_joints[0] = Vector3.ZERO
	for i in range(segment_count):
		var direction_to_child: Vector3 = _safe_direction(_joints[i + 1] - _joints[i], rest_direction)
		_joints[i + 1] = _joints[i] + direction_to_child * segment_length


func _solve_fabrik(target: Vector3) -> void:
	var root: Vector3 = Vector3.ZERO
	var total_length: float = segment_length * float(segment_count)

	if target.length() >= total_length:
		var direction: Vector3 = _safe_direction(target, Vector3.RIGHT)
		_joints[0] = root
		for i in range(1, segment_count + 1):
			_joints[i] = _joints[i - 1] + direction * segment_length
		return

	for _iteration in range(max(solver_iterations, 1)):
		_joints[segment_count] = target
		for i in range(segment_count - 1, -1, -1):
			var direction_to_parent: Vector3 = _safe_direction(_joints[i] - _joints[i + 1], Vector3.RIGHT)
			_joints[i] = _joints[i + 1] + direction_to_parent * segment_length

		_joints[0] = root
		for i in range(segment_count):
			var direction_to_child: Vector3 = _safe_direction(_joints[i + 1] - _joints[i], Vector3.RIGHT)
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
	var y: Vector3 = _safe_direction(y_axis, Vector3.RIGHT)
	var seed: Vector3 = Vector3.FORWARD
	if abs(y.dot(seed)) > 0.92:
		seed = Vector3.UP
	var x: Vector3 = seed.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	return Basis(x, y, z)


func _radial_outward() -> Vector3:
	var rest: Vector3 = _safe_direction(rest_direction, Vector3.RIGHT)
	var radial := Vector3(rest.x, rest.y, 0.0)
	if radial.length_squared() <= 0.0001:
		return rest
	return radial.normalized()


func _rest_outward(radial_outward: Vector3) -> Vector3:
	return _safe_direction(rest_direction, radial_outward)


func _ring_tangent(radial_outward: Vector3) -> Vector3:
	var tangent: Vector3 = Vector3.FORWARD.cross(radial_outward)
	if tangent.length_squared() <= 0.0001:
		tangent = Vector3.UP
	return tangent.normalized()


func _rest_position_for_joint(
		index: int,
		along: float,
		rest_outward: Vector3
) -> Vector3:
	var distal_back_bias: float = 0.10 * along * along
	var rest_curve_direction: Vector3 = _safe_direction(rest_outward + Vector3.BACK * distal_back_bias, rest_outward)
	return rest_curve_direction * segment_length * float(index)


func _guard_against_inward_hook(radial_outward: Vector3, curl_amount: float) -> void:
	if inward_hook_guard <= 0.0 or _joints.size() < 3:
		return
	if _normalized_state(visual_state) == "STARTLED":
		return

	var curl_relax: float = 1.0 - clamp(curl_amount * 0.75, 0.0, 0.85)
	var guard_strength: float = inward_hook_guard * curl_relax
	if guard_strength <= 0.01:
		return

	for i in range(2, segment_count + 1):
		var along: float = float(i) / float(segment_count)
		var previous_projection: float = _joints[i - 1].dot(radial_outward)
		var current_projection: float = _joints[i].dot(radial_outward)
		var allowed_backtrack: float = segment_length * lerp(0.32, 0.10, along)
		var minimum_projection: float = previous_projection - allowed_backtrack
		if current_projection < minimum_projection:
			var correction: float = (minimum_projection - current_projection) * guard_strength * pow(along, 1.2)
			_joints[i] += radial_outward * correction


func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() < 0.0001:
		return fallback.normalized()
	return value.normalized()


func _normalized_state(state_name: String) -> String:
	var normalized: String = state_name.strip_edges().to_upper()
	if VALID_STATES.has(normalized):
		return normalized
	return "IDLE"


func _state_flail_scale(state_name: String) -> float:
	match _normalized_state(state_name):
		"IDLE":
			return 0.18
		"WANDER":
			return 0.90
		"REGROUP":
			return 0.62
		"OBSERVE":
			return 0.08
		"FOLLOW":
			return 1.15
		"FLEE":
			return 1.35
		"STARTLED":
			return 0.02
		"CONFIDENT":
			return 0.50
	return 0.65


func _clear_generated_segments() -> void:
	for child in get_children():
		if child.get_meta(GENERATED_META, false):
			child.free()
	_segments.clear()
	_tip_node = null
