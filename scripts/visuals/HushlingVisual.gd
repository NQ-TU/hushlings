@tool
extends Node3D
class_name HushlingVisual

const TentacleIKChainScript := preload("res://scripts/visuals/TentacleIKChain.gd")
const GENERATED_META := "hushling_v4_generated"
const VALID_VISUAL_STATES := [
	"IDLE",
	"WANDER",
	"REGROUP",
	"OBSERVE",
	"FOLLOW",
	"FLEE",
	"STARTLED",
	"CONFIDENT",
]

@export_group("Binding")
@export var auto_bind_parent: bool = true
@export var read_agent_each_frame: bool = true

@export_group("Ocular Core")
@export_range(0.08, 0.42, 0.01) var eye_radius: float = 0.17:
	set(value):
		eye_radius = value
		_request_rebuild()
@export_range(0.01, 0.12, 0.01) var eye_depth: float = 0.038:
	set(value):
		eye_depth = value
		_request_rebuild()
@export_range(0.30, 1.2, 0.01) var iris_scale: float = 0.50:
	set(value):
		iris_scale = value
		_request_rebuild()
@export_range(0.15, 0.8, 0.01) var pupil_scale: float = 0.28:
	set(value):
		pupil_scale = value
		_request_rebuild()
@export_range(0.04, 0.35, 0.01) var back_core_depth: float = 0.115:
	set(value):
		back_core_depth = value
		_request_rebuild()

@export_group("Radial Body")
@export_range(6, 16, 1) var tendril_count: int = 10:
	set(value):
		tendril_count = value
		_request_rebuild()
@export_range(0.09, 0.42, 0.01) var attachment_radius: float = 0.17:
	set(value):
		attachment_radius = value
		_request_rebuild()
@export_range(3, 12, 1) var tendril_segments: int = 7:
	set(value):
		tendril_segments = value
		_request_rebuild()
@export_range(0.035, 0.22, 0.005) var tendril_segment_length: float = 0.078:
	set(value):
		tendril_segment_length = value
		_request_rebuild()
@export_range(0.006, 0.06, 0.001) var tendril_base_radius: float = 0.020:
	set(value):
		tendril_base_radius = value
		_request_rebuild()
@export_range(0.1, 0.8, 0.01) var tendril_tip_radius_factor: float = 0.30:
	set(value):
		tendril_tip_radius_factor = value
		_request_rebuild()
@export_range(0.0, 0.12, 0.005) var ring_depth_offset: float = 0.010:
	set(value):
		ring_depth_offset = value
		_request_rebuild()
@export_range(0.0, 0.55, 0.01) var front_ring_back_sweep: float = 0.12:
	set(value):
		front_ring_back_sweep = value
		_request_rebuild()
@export_group("Rear Tendril Ring")
@export var rear_tendril_ring_enabled: bool = true:
	set(value):
		rear_tendril_ring_enabled = value
		_request_rebuild()
@export_range(0.45, 1.1, 0.01) var rear_ring_radius_scale: float = 0.82:
	set(value):
		rear_ring_radius_scale = value
		_request_rebuild()
@export_range(0.0, 0.18, 0.005) var rear_ring_depth_offset: float = 0.075:
	set(value):
		rear_ring_depth_offset = value
		_request_rebuild()
@export_range(0.55, 1.25, 0.01) var rear_tendril_length_scale: float = 0.88:
	set(value):
		rear_tendril_length_scale = value
		_request_rebuild()
@export_range(0.45, 1.2, 0.01) var rear_tendril_radius_scale: float = 0.78:
	set(value):
		rear_tendril_radius_scale = value
		_request_rebuild()
@export_range(0.0, 0.5, 0.01) var rear_ring_angle_offset: float = 0.5:
	set(value):
		rear_ring_angle_offset = value
		_request_rebuild()
@export_range(0.0, 0.8, 0.01) var rear_ring_back_sweep: float = 0.34:
	set(value):
		rear_ring_back_sweep = value
		_request_rebuild()

@export_group("Materials")
@export var eye_color: Color = Color(0.84, 0.92, 0.88, 1.0):
	set(value):
		eye_color = value
		_request_rebuild()
@export var iris_color: Color = Color(0.34, 0.60, 0.68, 1.0):
	set(value):
		iris_color = value
		_request_rebuild()
@export var pupil_color: Color = Color(0.008, 0.008, 0.014, 1.0):
	set(value):
		pupil_color = value
		_request_rebuild()
@export var core_color: Color = Color(0.075, 0.045, 0.078, 1.0):
	set(value):
		core_color = value
		_request_rebuild()
@export var tendril_color: Color = Color(0.145, 0.055, 0.125, 1.0):
	set(value):
		tendril_color = value
		_request_rebuild()
@export var accent_color: Color = Color(0.68, 0.22, 0.42, 1.0):
	set(value):
		accent_color = value
		_request_rebuild()
@export_range(0.0, 5.0, 0.01) var eye_emission_strength: float = 1.05
@export_range(0.0, 3.0, 0.01) var accent_emission_strength: float = 0.45
@export_range(0.0, 1.0, 0.01) var core_emission_strength: float = 0.08

@export_group("Motion")
@export_range(0.5, 12.0, 0.1) var head_turn_response: float = 3.15
@export_range(0.0, 1.0, 0.01) var vertical_turn_influence: float = 0.70
@export_range(0.0, 0.25, 0.001) var minimum_facing_speed: float = 0.025
@export_range(0.0, 18.0, 0.1) var movement_lean_amount: float = 5.5
@export_range(0.0, 0.20, 0.001) var head_pulse_amount: float = 0.030
@export_range(0.05, 4.0, 0.01) var head_pulse_frequency: float = 0.44
@export_range(0.0, 0.12, 0.001) var drift_amplitude: float = 0.018
@export_range(0.05, 4.0, 0.01) var drift_frequency: float = 0.30
@export_range(0.1, 14.0, 0.1) var velocity_response: float = 4.0
@export_range(15.0, 720.0, 1.0) var visual_target_turn_degrees_per_second: float = 155.0
@export_range(0.0, 65.0, 1.0) var max_eye_lead_degrees: float = 28.0
@export_range(0.0, 45.0, 0.5) var max_bank_degrees: float = 16.0
@export_range(0.1, 18.0, 0.1) var bank_response: float = 6.0
@export_range(0.0, 4.0, 0.01) var tendril_trail_strength: float = 1.0
@export_range(0.0, 4.0, 0.01) var tendril_spread_strength: float = 1.0
@export_range(0.0, 4.0, 0.01) var tendril_sway_amount: float = 1.0
@export_range(0.0, 4.0, 0.01) var tendril_movement_flail_strength: float = 0.38
@export_range(0.1, 6.0, 0.01) var tendril_movement_flail_frequency: float = 1.28
@export_range(0.0, 1.0, 0.01) var tendril_movement_flail_vertical: float = 0.34
@export_range(0.1, 4.0, 0.01) var tendril_follow_speed: float = 0.86
@export_range(1, 4, 1) var tendril_solver_iterations: int = 2
@export_range(0, 4, 1) var tendril_rigid_base_segments: int = 2
@export_range(0.0, 1.0, 0.01) var tendril_base_rigidity: float = 0.78
@export_range(0.0, 2.0, 0.01) var tendril_distal_drag_bias: float = 0.42
@export_range(0.0, 2.0, 0.01) var tendril_turn_drag_strength: float = 0.55
@export_range(0.0, 1.0, 0.01) var tendril_rest_shape_strength: float = 0.28
@export_range(0.0, 1.0, 0.01) var tendril_inward_hook_guard: float = 0.62

@export_group("Emotion Mapping")
@export_range(0.0, 2.0, 0.01) var fear_curl_strength: float = 1.0
@export_range(0.0, 2.0, 0.01) var confidence_spread_strength: float = 0.75
@export_range(0.0, 2.0, 0.01) var curiosity_eye_strength: float = 0.58
@export_range(0.0, 0.12, 0.001) var loneliness_droop: float = 0.018

@export_group("Performance")
@export_range(0.0, 90.0, 1.0) var visual_update_rate_hz: float = 30.0

@export_group("Editor")
@export var build_on_ready: bool = true
@export var animate_in_editor: bool = false
@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if value:
			call_deferred("build_visual")

var _agent: Node
var _agent_properties: Dictionary = {}
var _state_name: String = "WANDER"
var _visual_state: String = "WANDER"
var _state_age: float = 0.0
var _desired_velocity: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _direction: Vector3 = Vector3.FORWARD
var _target_direction: Vector3 = Vector3.FORWARD
var _visual_target_direction: Vector3 = Vector3.FORWARD
var _fear: float = 0.0
var _confidence: float = 0.0
var _curiosity: float = 0.0
var _loneliness: float = 0.0
var _speed_reference: float = 0.48
var _animation_time: float = 0.0
var _motion_forward: Vector3 = Vector3.FORWARD
var _bank_angle: float = 0.0
var _turn_swing: float = 0.0
var _rebuild_requested: bool = false
var _visual_update_accumulator: float = 0.0

var _pose_root: Node3D
var _eye_root: Node3D
var _core_root: Node3D
var _tendril_root: Node3D
var _accent_root: Node3D
var _tendrils: Array = []
var _eye_material: StandardMaterial3D
var _iris_material: StandardMaterial3D
var _pupil_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _tendril_material: StandardMaterial3D
var _accent_material: StandardMaterial3D


func _ready() -> void:
	if build_on_ready:
		build_visual()
	if auto_bind_parent and _agent == null:
		_try_bind_parent()
	set_process(not Engine.is_editor_hint() or animate_in_editor)


func _process(delta: float) -> void:
	if _rebuild_requested:
		build_visual()
	if Engine.is_editor_hint() and not animate_in_editor:
		return

	if auto_bind_parent and (_agent == null or not is_instance_valid(_agent)):
		_try_bind_parent()

	var visual_delta: float = _consume_visual_delta(delta)
	if visual_delta <= 0.0:
		return

	if read_agent_each_frame:
		_read_agent_values()

	_animation_time += visual_delta
	_state_age += visual_delta
	var previous_state: String = _visual_state
	_visual_state = _resolve_visual_state()
	if previous_state != _visual_state:
		_state_age = 0.0

	var velocity_alpha: float = 1.0 - exp(-velocity_response * visual_delta)
	_velocity = _velocity.lerp(_desired_velocity, velocity_alpha)
	_update_visual_target_direction(visual_delta)

	_update_head_motion(visual_delta)
	_update_eye_motion(visual_delta)
	_update_state_scale()
	_update_tendrils(visual_delta)


func bind_agent(agent: Node) -> void:
	_agent = agent
	_agent_properties.clear()
	if _agent == null:
		return

	for property in _agent.get_property_list():
		_agent_properties[StringName(property.get("name", ""))] = true


func _consume_visual_delta(delta: float) -> float:
	if visual_update_rate_hz <= 0.0:
		return delta

	_visual_update_accumulator += delta
	var step: float = 1.0 / visual_update_rate_hz
	if _visual_update_accumulator < step:
		return 0.0

	var consumed: float = min(_visual_update_accumulator, step * 2.0)
	_visual_update_accumulator = 0.0
	return consumed


func set_agent_state(state_name: String) -> void:
	_state_name = _normalized_agent_state(state_name)


func set_velocity(velocity: Vector3) -> void:
	_desired_velocity = velocity


func set_target_direction(direction: Vector3) -> void:
	_target_direction = _safe_direction(direction, _target_direction)
	if _visual_target_direction.length_squared() <= 0.0001:
		_visual_target_direction = _target_direction


func set_emotion(fear: float, confidence: float, curiosity: float, loneliness: float) -> void:
	_fear = clamp(fear, 0.0, 1.0)
	_confidence = clamp(confidence, 0.0, 1.0)
	_curiosity = clamp(curiosity, 0.0, 1.0)
	_loneliness = clamp(loneliness, 0.0, 1.0)


func build_visual() -> void:
	_rebuild_requested = false
	_pose_root = _ensure_root(self, "PoseRoot")
	_eye_root = _ensure_root(_pose_root, "EyeRoot")
	_core_root = _ensure_root(_pose_root, "CoreRoot")
	_tendril_root = _ensure_root(_pose_root, "TendrilRoot")
	_accent_root = _ensure_root(_pose_root, "AccentRoot")

	_clear_generated(_eye_root)
	_clear_generated(_core_root)
	_clear_generated(_tendril_root)
	_clear_generated(_accent_root)
	_tendrils.clear()

	_create_materials()
	_build_core()
	_build_eye()
	_build_tendrils()
	_build_accents()


func _try_bind_parent() -> void:
	var candidate: Node = get_parent()
	while candidate != null:
		if candidate.is_in_group(&"hushling") or _node_has_property(candidate, &"current_state"):
			bind_agent(candidate)
			return
		candidate = candidate.get_parent()


func _read_agent_values() -> void:
	if _agent == null or not is_instance_valid(_agent):
		return

	var state_value: Variant = _get_agent_property(&"current_state", _state_name)
	if typeof(state_value) == TYPE_STRING or typeof(state_value) == TYPE_STRING_NAME:
		set_agent_state(String(state_value))

	var velocity_value: Variant = _get_agent_property(&"velocity", _desired_velocity)
	if typeof(velocity_value) == TYPE_VECTOR3:
		set_velocity(velocity_value)

	var direction_value: Variant = _get_agent_property(&"direction", _direction)
	if typeof(direction_value) == TYPE_VECTOR3:
		_direction = _safe_direction(direction_value, _direction)

	var target_direction_value: Variant = _get_agent_property(&"target_direction", _target_direction)
	if typeof(target_direction_value) == TYPE_VECTOR3:
		set_target_direction(target_direction_value)

	var fear_value: Variant = _get_agent_property(&"fear", _fear)
	var confidence_value: Variant = _get_agent_property(&"confidence", _confidence)
	var curiosity_value: Variant = _get_agent_property(&"curiosity", _curiosity)
	var loneliness_value: Variant = _get_agent_property(&"loneliness", _loneliness)
	set_emotion(
		_float_or(fear_value, _fear),
		_float_or(confidence_value, _confidence),
		_float_or(curiosity_value, _curiosity),
		_float_or(loneliness_value, _loneliness)
	)

	var max_speed_value: Variant = _get_agent_property(&"max_speed", _speed_reference)
	_speed_reference = max(_float_or(max_speed_value, _speed_reference), 0.01)


func _build_core() -> void:
	var mesh := _sphere_mesh(18, 9)

	var back_core := MeshInstance3D.new()
	back_core.name = "OcularBackCore"
	back_core.mesh = mesh
	back_core.position = Vector3(0.0, 0.0, back_core_depth)
	back_core.scale = Vector3(eye_radius * 0.92, eye_radius * 0.92, back_core_depth)
	back_core.material_override = _core_material
	back_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated_child(_core_root, back_core)

	var rear_depth: float = ring_depth_offset
	if rear_tendril_ring_enabled:
		rear_depth = max(rear_depth, rear_ring_depth_offset)
	var root_depth: float = (ring_depth_offset + rear_depth) * 0.5
	var root_depth_span: float = max(absf(rear_depth - ring_depth_offset) * 0.72, back_core_depth * 0.54, 0.045)

	var inner_core := MeshInstance3D.new()
	inner_core.name = "TendrilRootMass"
	inner_core.mesh = mesh
	inner_core.position = Vector3(0.0, 0.0, root_depth)
	inner_core.scale = Vector3(attachment_radius * 0.78, attachment_radius * 0.78, root_depth_span)
	inner_core.material_override = _core_material
	inner_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated_child(_core_root, inner_core)

	var collar_mesh := _sphere_mesh(10, 5)
	_build_socket_ring("Front", collar_mesh, tendril_count, attachment_radius, ring_depth_offset, tendril_base_radius, 0.0)
	if rear_tendril_ring_enabled:
		_build_socket_ring(
			"Rear",
			collar_mesh,
			tendril_count,
			attachment_radius * rear_ring_radius_scale,
			rear_ring_depth_offset,
			tendril_base_radius * rear_tendril_radius_scale,
			rear_ring_angle_offset
		)


func _build_eye() -> void:
	var eye_mesh := _sphere_mesh(24, 12)

	var sclera := MeshInstance3D.new()
	sclera.name = "EyeSclera"
	sclera.mesh = eye_mesh
	sclera.position = Vector3.ZERO
	sclera.scale = Vector3(eye_radius, eye_radius, eye_depth)
	sclera.material_override = _eye_material
	sclera.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated_child(_eye_root, sclera)

	var iris := MeshInstance3D.new()
	iris.name = "Iris"
	iris.mesh = eye_mesh
	iris.position = Vector3(0.0, 0.0, -eye_depth * 1.05)
	iris.scale = Vector3(eye_radius * iris_scale, eye_radius * iris_scale, eye_depth * 0.25)
	iris.material_override = _iris_material
	iris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated_child(_eye_root, iris)

	var pupil := MeshInstance3D.new()
	pupil.name = "Pupil"
	pupil.mesh = eye_mesh
	pupil.position = Vector3(0.0, 0.0, -eye_depth * 1.36)
	pupil.scale = Vector3(eye_radius * pupil_scale, eye_radius * pupil_scale, eye_depth * 0.14)
	pupil.material_override = _pupil_material
	pupil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated_child(_eye_root, pupil)


func _build_tendrils() -> void:
	_build_tendril_ring("Front", tendril_count, attachment_radius, ring_depth_offset, 1.0, 1.0, 0.0, 0.0, front_ring_back_sweep)
	if rear_tendril_ring_enabled:
		_build_tendril_ring(
			"Rear",
			tendril_count,
			attachment_radius * rear_ring_radius_scale,
			rear_ring_depth_offset,
			rear_tendril_length_scale,
			rear_tendril_radius_scale,
			rear_ring_angle_offset,
			0.37,
			rear_ring_back_sweep
		)


func _build_socket_ring(
		ring_name: String,
		collar_mesh: SphereMesh,
		count: int,
		radius: float,
		depth: float,
		socket_radius: float,
		angle_offset_fraction: float
) -> void:
	for i in range(count):
		var angle: float = TAU * (float(i) + angle_offset_fraction) / float(count)
		var collar := MeshInstance3D.new()
		collar.name = "%sTendrilSocket%02d" % [ring_name, i]
		collar.mesh = collar_mesh
		collar.position = Vector3(cos(angle) * radius, sin(angle) * radius, depth)
		collar.rotation = Vector3(0.0, 0.0, angle)
		collar.scale = Vector3(socket_radius * 2.2, socket_radius * 1.4, socket_radius * 1.15)
		collar.material_override = _core_material
		collar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_generated_child(_core_root, collar)


func _build_tendril_ring(
		ring_name: String,
		count: int,
		radius: float,
		depth: float,
		length_scale: float,
		radius_scale: float,
		angle_offset_fraction: float,
		phase_offset: float,
		back_sweep: float
) -> void:
	for i in range(count):
		var angle: float = TAU * (float(i) + angle_offset_fraction) / float(count)
		var outward := Vector3(cos(angle), sin(angle), 0.0)
		var rest_direction: Vector3 = _safe_direction(outward + Vector3.BACK * back_sweep, outward)
		var variation: float = fmod(float(i) * 0.37, 1.0)
		var chain: Node3D = TentacleIKChainScript.new()
		chain.name = "%sTendril%02d" % [ring_name, i]
		chain.position = outward * radius + Vector3(0.0, 0.0, depth)
		chain.set(&"segment_count", tendril_segments)
		chain.set(&"segment_length", tendril_segment_length * length_scale * lerp(0.90, 1.18, variation))
		chain.set(&"base_radius", tendril_base_radius * radius_scale * lerp(0.88, 1.12, fmod(float(i) * 0.51, 1.0)))
		chain.set(&"tip_radius_factor", tendril_tip_radius_factor)
		chain.set(&"rest_direction", rest_direction)
		chain.set(&"phase", float(i) * 0.71 + phase_offset)
		chain.set(&"segment_material", _tendril_material)
		chain.set(&"movement_flail_strength", tendril_movement_flail_strength)
		chain.set(&"movement_flail_frequency", tendril_movement_flail_frequency)
		chain.set(&"movement_flail_vertical", tendril_movement_flail_vertical)
		chain.set(&"solver_iterations", tendril_solver_iterations)
		chain.set(&"rigid_base_segments", tendril_rigid_base_segments)
		chain.set(&"base_rigidity", tendril_base_rigidity)
		chain.set(&"distal_drag_bias", tendril_distal_drag_bias)
		chain.set(&"turn_drag_strength", tendril_turn_drag_strength)
		chain.set(&"rest_shape_strength", tendril_rest_shape_strength)
		chain.set(&"inward_hook_guard", tendril_inward_hook_guard)
		chain.set(&"auto_update", false)
		_add_generated_child(_tendril_root, chain)
		chain.call(&"build_chain")
		_tendrils.append(chain)


func _build_accents() -> void:
	var mesh := _sphere_mesh(8, 4)
	for i in range(tendril_count):
		if i % 2 != 0:
			continue
		var angle: float = TAU * float(i) / float(tendril_count)
		var accent := MeshInstance3D.new()
		accent.name = "RadialGlow%02d" % i
		accent.mesh = mesh
		accent.position = Vector3(cos(angle) * attachment_radius * 0.62, sin(angle) * attachment_radius * 0.62, -eye_depth * 0.18)
		accent.scale = Vector3.ONE * max(tendril_base_radius * 0.58, 0.01)
		accent.material_override = _accent_material
		accent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_generated_child(_accent_root, accent)


func _update_visual_target_direction(delta: float) -> void:
	if _target_direction.length_squared() <= 0.0001:
		return
	if _visual_target_direction.length_squared() <= 0.0001:
		_visual_target_direction = _target_direction
		return

	var max_turn: float = deg_to_rad(visual_target_turn_degrees_per_second) * delta
	_visual_target_direction = _rotate_direction_toward(
		_visual_target_direction.normalized(),
		_target_direction.normalized(),
		max_turn
	)


func _update_bank(desired_local_forward: Vector3, speed_factor: float, delta: float) -> void:
	var turn_angle: float = _motion_forward.angle_to(desired_local_forward)
	var turn_sign: float = signf(_motion_forward.cross(desired_local_forward).dot(Vector3.UP))
	var bank_scale: float = 1.0
	if _visual_state == "FLEE":
		bank_scale = 1.35
	elif _visual_state == "OBSERVE" or _visual_state == "STARTLED":
		bank_scale = 0.35

	var turn_pressure: float = clamp(turn_angle / deg_to_rad(90.0), 0.0, 1.0)
	var target_bank: float = -turn_sign * deg_to_rad(max_bank_degrees) * turn_pressure * speed_factor * bank_scale
	var bank_alpha: float = 1.0 - exp(-bank_response * delta)
	_bank_angle = lerp(_bank_angle, target_bank, bank_alpha)

	var swing_motion_factor: float = max(speed_factor, 0.35)
	var target_turn_swing: float = turn_sign * turn_pressure * swing_motion_factor * bank_scale
	_turn_swing = lerp(_turn_swing, target_turn_swing, bank_alpha)


func _get_eye_target_direction() -> Vector3:
	var body_forward: Vector3 = global_transform.basis * _motion_forward
	body_forward = _safe_direction(body_forward, _direction)
	var raw_eye_target: Vector3 = _safe_direction(_visual_target_direction, body_forward)
	var max_eye_lead: float = deg_to_rad(max_eye_lead_degrees)
	if _visual_state == "STARTLED":
		max_eye_lead *= 1.25
	elif _visual_state == "FLEE":
		max_eye_lead *= 0.82

	return _rotate_direction_toward(body_forward, raw_eye_target, max_eye_lead)


func _update_head_motion(delta: float) -> void:
	if _pose_root == null:
		return

	var facing_velocity: Vector3 = _velocity
	facing_velocity.y *= vertical_turn_influence
	var speed_factor: float = clamp(facing_velocity.length() / _speed_reference, 0.0, 1.0)
	var desired_forward: Vector3 = _direction

	if _visual_state == "OBSERVE" or _visual_state == "STARTLED":
		desired_forward = _visual_target_direction
	elif facing_velocity.length_squared() > minimum_facing_speed * minimum_facing_speed:
		desired_forward = facing_velocity.normalized()

	var local_forward: Vector3 = global_transform.basis.inverse() * desired_forward
	if local_forward.length_squared() > 0.0001:
		var desired_local_forward: Vector3 = local_forward.normalized()
		_update_bank(desired_local_forward, speed_factor, delta)
		_motion_forward = _motion_forward.lerp(desired_local_forward, 1.0 - exp(-head_turn_response * delta)).normalized()
	else:
		_update_bank(_motion_forward, speed_factor, delta)

	var head_basis: Basis = _basis_from_forward(_motion_forward, _pose_root.transform.basis)
	var lean_angle: float = deg_to_rad(movement_lean_amount) * speed_factor
	var target_basis: Basis = head_basis * Basis(Vector3.FORWARD, _bank_angle) * Basis(Vector3.RIGHT, lean_angle)
	var current_quat: Quaternion = _pose_root.transform.basis.get_rotation_quaternion()
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()
	var rotation_alpha: float = 1.0 - exp(-head_turn_response * delta)

	var transform: Transform3D = _pose_root.transform
	transform.basis = Basis(current_quat.slerp(target_quat, rotation_alpha)).orthonormalized()
	transform.origin = Vector3(
		0.0,
		sin(_animation_time * TAU * drift_frequency) * drift_amplitude - _loneliness * loneliness_droop,
		0.0
	)
	_pose_root.transform = transform


func _update_eye_motion(delta: float) -> void:
	if _eye_root == null or _pose_root == null:
		return

	var eye_lock: float = 0.22 + _curiosity * 0.35
	if _visual_state == "OBSERVE" or _visual_state == "STARTLED":
		eye_lock = 1.0
	elif _visual_state == "REGROUP" or _visual_state == "FOLLOW":
		eye_lock = max(eye_lock, 0.45)

	var eye_target: Vector3 = _get_eye_target_direction()
	var local_target: Vector3 = _pose_root.global_transform.basis.inverse() * eye_target
	var target_basis: Basis = _basis_from_forward(_safe_direction(local_target, Vector3.FORWARD), _eye_root.transform.basis)
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()
	var current_quat: Quaternion = _eye_root.transform.basis.get_rotation_quaternion()
	var alpha: float = (1.0 - exp(-head_turn_response * 1.4 * delta)) * clamp(eye_lock, 0.0, 1.0)
	var transform: Transform3D = _eye_root.transform
	transform.basis = Basis(current_quat.slerp(target_quat, alpha)).orthonormalized()
	_eye_root.transform = transform


func _update_state_scale() -> void:
	var pulse: float = sin(_animation_time * TAU * head_pulse_frequency) * head_pulse_amount
	var speed_factor: float = clamp(_velocity.length() / _speed_reference, 0.0, 1.0)
	var eye_scale: float = 1.0 + _curiosity * curiosity_eye_strength * 0.24
	var eye_brightness: float = 1.0 + _curiosity * curiosity_eye_strength + _fear * 0.32
	var core_scale: float = 1.0 + pulse
	var tendril_scale: float = 1.0 + _confidence * 0.12 - _fear * 0.1
	var startled_jolt: float = 0.0

	match _visual_state:
		"IDLE":
			eye_brightness *= 0.86
			core_scale = 1.0 + pulse * 0.65
		"WANDER":
			core_scale = 1.0 + pulse
		"REGROUP":
			eye_scale += 0.03
			eye_brightness *= 1.08
			core_scale = 1.0 + pulse * 0.55
			tendril_scale += 0.05
		"OBSERVE":
			eye_scale += 0.12
			eye_brightness *= 1.65
			core_scale = 1.0 + pulse * 0.32
			tendril_scale += 0.04
		"FOLLOW":
			eye_scale += 0.04
			eye_brightness *= 1.12
			core_scale = 1.0 + pulse * 0.85 + speed_factor * 0.018
		"FLEE":
			eye_brightness *= 1.30
			core_scale = 1.0 + pulse * 1.25 + speed_factor * 0.035
			tendril_scale -= 0.08
		"STARTLED":
			startled_jolt = max(0.0, 1.0 - _state_age / 0.32)
			eye_scale += 0.08 + startled_jolt * 0.05
			eye_brightness *= 1.75
			core_scale = 0.88 - startled_jolt * 0.05
			tendril_scale = 0.74
		"CONFIDENT":
			eye_scale += 0.04
			eye_brightness *= 1.16
			core_scale = 1.03 + pulse * 0.45
			tendril_scale += 0.12

	if _core_root:
		_core_root.scale = Vector3.ONE * core_scale
	if _tendril_root:
		_tendril_root.scale = Vector3.ONE * tendril_scale
	_set_eye_emphasis(eye_scale, eye_brightness)


func _update_tendrils(delta: float) -> void:
	var trail_scale: float = tendril_trail_strength
	var spread_scale: float = tendril_spread_strength * (1.0 + _confidence * confidence_spread_strength)
	var sway_scale: float = tendril_sway_amount * (1.0 - _loneliness * 0.35)
	var follow_scale: float = tendril_follow_speed
	var curl_scale: float = _fear * fear_curl_strength
	var flail_scale: float = 1.0 + _fear * 0.12 - _loneliness * 0.10

	match _visual_state:
		"IDLE":
			trail_scale *= 0.35
			spread_scale *= 0.82
			sway_scale *= 0.70
			flail_scale *= 0.80
		"REGROUP":
			trail_scale *= 0.42
			spread_scale *= 1.04
			sway_scale *= 0.42
			follow_scale *= 0.88
			flail_scale *= 0.88
		"OBSERVE":
			trail_scale *= 0.18
			spread_scale *= 1.10
			sway_scale *= 0.22
			follow_scale *= 0.72
			flail_scale *= 0.75
		"FOLLOW":
			trail_scale *= 1.45
			spread_scale *= 0.92
			sway_scale *= 0.72
			follow_scale *= 1.22
			flail_scale *= 1.08
		"FLEE":
			trail_scale *= 1.45
			spread_scale *= 0.62
			sway_scale *= 0.36
			follow_scale *= 1.45
			curl_scale += 0.42
			flail_scale *= 1.12
		"STARTLED":
			trail_scale *= 0.12
			spread_scale *= 0.28
			sway_scale *= 0.12
			follow_scale *= 1.85
			curl_scale += 0.9
			flail_scale *= 0.60
		"CONFIDENT":
			trail_scale *= 0.38
			spread_scale *= 1.25
			sway_scale *= 0.36
			follow_scale *= 0.76
			flail_scale *= 0.90

	for tendril in _tendrils:
		if not is_instance_valid(tendril):
			continue
		tendril.call(
			&"set_motion_context",
			_velocity,
			_visual_target_direction,
			_visual_state,
			trail_scale,
			spread_scale,
			sway_scale,
			follow_scale,
			curl_scale,
			_turn_swing,
			flail_scale
		)
		tendril.call(&"animate", delta)


func _set_eye_emphasis(scale_factor: float, brightness_factor: float) -> void:
	if _eye_root:
		_eye_root.scale = Vector3.ONE * scale_factor

	if _eye_material:
		_eye_material.emission_energy_multiplier = eye_emission_strength * brightness_factor
	if _iris_material:
		_iris_material.emission_energy_multiplier = eye_emission_strength * 0.38 * brightness_factor
	if _accent_material:
		_accent_material.emission_energy_multiplier = accent_emission_strength * brightness_factor


func _resolve_visual_state() -> String:
	if _state_name == "IDLE":
		return "IDLE"
	if _state_name == "WANDER" and _confidence > 0.58 and _fear < 0.28:
		return "CONFIDENT"
	if VALID_VISUAL_STATES.has(_state_name):
		return _state_name
	return "WANDER"


func _normalized_agent_state(state_name: String) -> String:
	var normalized: String = state_name.strip_edges().to_upper()
	if normalized == "":
		return "WANDER"
	if normalized == "IDLE":
		return "IDLE"
	if VALID_VISUAL_STATES.has(normalized):
		return normalized
	return "WANDER"


func _create_materials() -> void:
	_eye_material = _make_material(eye_color, eye_color, eye_emission_strength, 0.36)
	_iris_material = _make_material(iris_color, iris_color, eye_emission_strength * 0.38, 0.42)
	_pupil_material = _make_material(pupil_color, pupil_color, 0.05, 0.6)
	_core_material = _make_material(core_color, accent_color, core_emission_strength, 0.88)
	_tendril_material = _make_material(tendril_color, accent_color, 0.12, 0.86)
	_accent_material = _make_material(accent_color, accent_color, accent_emission_strength, 0.48)


func _make_material(
		albedo: Color,
		emission_color: Color,
		emission_strength: float,
		roughness: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = 0.0
	material.emission_enabled = emission_strength > 0.0
	material.emission = emission_color
	material.emission_energy_multiplier = emission_strength
	return material


func _sphere_mesh(radial_segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	return mesh


func _ensure_root(parent: Node, root_name: String) -> Node3D:
	var existing := parent.get_node_or_null(root_name) as Node3D
	if existing:
		return existing

	var root := Node3D.new()
	root.name = root_name
	parent.add_child(root)
	return root


func _add_generated_child(parent: Node, child: Node) -> void:
	child.set_meta(GENERATED_META, true)
	parent.add_child(child)


func _clear_generated(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child.get_meta(GENERATED_META, false):
			child.free()


func _request_rebuild() -> void:
	_rebuild_requested = true
	if Engine.is_editor_hint() and is_inside_tree():
		call_deferred("build_visual")


func _node_has_property(node: Node, property_name: StringName) -> bool:
	for property in node.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


func _get_agent_property(property_name: StringName, fallback: Variant) -> Variant:
	if _agent == null or not _agent_properties.has(property_name):
		return fallback
	return _agent.get(property_name)


func _float_or(value: Variant, fallback: float) -> float:
	var value_type: int = typeof(value)
	if value_type == TYPE_FLOAT or value_type == TYPE_INT:
		return float(value)
	return fallback


func _basis_from_forward(forward_direction: Vector3, current_basis: Basis) -> Basis:
	var forward: Vector3 = forward_direction
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()

	var z_axis: Vector3 = -forward
	var up_axis: Vector3 = Vector3.UP
	var x_axis: Vector3 = up_axis.cross(z_axis)
	if x_axis.length_squared() < 0.0001:
		x_axis = current_basis.x
		if x_axis.length_squared() < 0.0001:
			x_axis = Vector3.RIGHT
	else:
		x_axis = x_axis.normalized()

	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()


func _rotate_direction_toward(current: Vector3, target: Vector3, max_angle: float) -> Vector3:
	var current_direction: Vector3 = _safe_direction(current, target)
	var target_direction: Vector3 = _safe_direction(target, current_direction)
	var angle: float = current_direction.angle_to(target_direction)
	if angle <= max_angle or angle <= 0.0001:
		return target_direction

	var axis: Vector3 = current_direction.cross(target_direction)
	if axis.length_squared() <= 0.0001:
		axis = _orthogonal_axis(current_direction)
	else:
		axis = axis.normalized()

	return current_direction.rotated(axis, max_angle).normalized()


func _orthogonal_axis(direction_value: Vector3) -> Vector3:
	var axis: Vector3 = Vector3.UP.cross(direction_value)
	if axis.length_squared() <= 0.0001:
		axis = Vector3.RIGHT.cross(direction_value)
	if axis.length_squared() <= 0.0001:
		return Vector3.UP
	return axis.normalized()


func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() < 0.0001:
		return fallback.normalized()
	return value.normalized()
