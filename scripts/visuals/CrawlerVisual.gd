@tool
extends Node3D
class_name CrawlerVisual

const CrawlerAppendageIKChainScript := preload("res://scripts/visuals/CrawlerAppendageIKChain.gd")
const GENERATED_META := "crawler_v3_generated"
const STATE_IDLE := "IDLE"
const STATE_WANDER := "WANDER"
const STATE_FLEE := "FLEE"
const VALID_STATES := [
	STATE_IDLE,
	STATE_WANDER,
	"OBSERVE",
	STATE_FLEE,
	"STARTLED",
	"CONFIDENT",
]

@export_group("Binding")
@export var auto_bind_parent: bool = true
@export var read_agent_each_frame: bool = true

@export_group("Ribbon Body")
@export_range(5, 14, 1) var segment_count: int = 8:
	set(value):
		segment_count = max(value, 5)
		_request_rebuild()
@export_range(0.35, 1.4, 0.01) var body_length: float = 1.26:
	set(value):
		body_length = max(value, 0.1)
		_request_rebuild()
@export_range(0.05, 0.55, 0.005) var body_width: float = 0.30:
	set(value):
		body_width = max(value, 0.02)
		_request_rebuild()
@export_range(0.025, 0.25, 0.005) var body_height: float = 0.085:
	set(value):
		body_height = max(value, 0.01)
		_request_rebuild()
@export_range(0.04, 0.45, 0.005) var body_depth: float = 0.25:
	set(value):
		body_depth = max(value, 0.02)
		_request_rebuild()
@export_range(0.15, 0.9, 0.01) var tail_taper: float = 0.42:
	set(value):
		tail_taper = clamp(value, 0.15, 0.9)
		_request_rebuild()
@export_storage var initial_curve_amount: float = 0.06:
	set(value):
		initial_curve_amount = max(value, 0.0)
		_request_rebuild()

@export_group("Leading Sensor")
@export_storage var head_scale: Vector3 = Vector3(0.24, 0.12, 0.34):
	set(value):
		head_scale = value
		_request_rebuild()
@export_storage var sensor_slit_count: int = 5:
	set(value):
		sensor_slit_count = max(value, 2)
		_request_rebuild()
@export_storage var sensor_slit_width: float = 0.045:
	set(value):
		sensor_slit_width = max(value, 0.002)
		_request_rebuild()
@export_storage var sensor_slit_height: float = 0.014:
	set(value):
		sensor_slit_height = max(value, 0.002)
		_request_rebuild()

@export_group("Appendages")
@export_range(2, 8, 1) var sweeper_pairs: int = 4:
	set(value):
		sweeper_pairs = max(value, 2)
		_request_rebuild()
@export_storage var sweeper_segments: int = 5:
	set(value):
		sweeper_segments = max(value, 3)
		_request_rebuild()
@export_storage var sweeper_segment_length: float = 0.105:
	set(value):
		sweeper_segment_length = max(value, 0.02)
		_request_rebuild()
@export_storage var sweeper_radius: float = 0.023:
	set(value):
		sweeper_radius = max(value, 0.002)
		_request_rebuild()
@export_storage var feeler_segments: int = 6:
	set(value):
		feeler_segments = max(value, 3)
		_request_rebuild()
@export_storage var feeler_segment_length: float = 0.12:
	set(value):
		feeler_segment_length = max(value, 0.02)
		_request_rebuild()
@export_storage var feeler_radius: float = 0.016:
	set(value):
		feeler_radius = max(value, 0.002)
		_request_rebuild()

@export_group("Motion")
@export_range(0.0, 0.18, 0.001) var wave_amount: float = 0.075
@export_range(0.05, 3.0, 0.01) var wave_frequency: float = 0.48
@export_storage var follow_lag: float = 1.1
@export_range(0.0, 1.0, 0.01) var flee_tension_amount: float = 0.62
@export_storage var drift_amplitude: float = 0.035
@export_storage var drift_frequency: float = 0.34
@export_storage var body_pulse_amount: float = 0.035
@export_storage var pulse_frequency: float = 0.78
@export_range(0.0, 0.16, 0.001) var vertical_wave_amount: float = 0.065
@export_storage var body_lag_amount: float = 0.075
@export_storage var body_smoothing_speed: float = 3.8
@export_storage var spine_chain_follow_speed: float = 3.0
@export_range(0.5, 12.0, 0.1) var head_turn_response: float = 3.2
@export_storage var vertical_turn_influence: float = 0.65
@export_storage var minimum_facing_speed: float = 0.025
@export_storage var body_turn_follow_speed: float = 0.55
@export_storage var body_turn_lag_amount: float = 0.95
@export_storage var body_heading_follow_speed: float = 0.55
@export_storage var body_turn_distribution: float = 0.58
@export_range(0.0, 24.0, 0.1) var movement_lean_amount: float = 8.0
@export_range(0.0, 0.4, 0.001) var startled_curl_amount: float = 0.28
@export_range(0.1, 12.0, 0.1) var velocity_response: float = 1.55

@export_group("Turn Limits")
@export_storage var head_turn_degrees_per_second: float = 95.0
@export_storage var max_body_step_turn_degrees: float = 13.0
@export_storage var max_body_total_turn_degrees: float = 58.0
@export_storage var max_segment_yaw_degrees: float = 18.0
@export_storage var max_segment_pitch_degrees: float = 12.0
@export_storage var max_bank_angle_degrees: float = 16.0

@export_group("Appendage Motion")
@export_range(0.0, 4.0, 0.01) var appendage_trail_strength: float = 1.0
@export_range(0.0, 4.0, 0.01) var appendage_sweep_strength: float = 0.9
@export_range(0.0, 4.0, 0.01) var appendage_probe_strength: float = 1.0
@export_range(0.1, 4.0, 0.01) var appendage_follow_speed: float = 0.76

@export_group("Materials")
@export var ribbon_color: Color = Color(0.055, 0.065, 0.09, 1.0):
	set(value):
		ribbon_color = value
		_request_rebuild()
@export var underside_color: Color = Color(0.085, 0.045, 0.075, 1.0):
	set(value):
		underside_color = value
		_request_rebuild()
@export var appendage_color: Color = Color(0.12, 0.055, 0.105, 1.0):
	set(value):
		appendage_color = value
		_request_rebuild()
@export var sensor_color: Color = Color(0.56, 0.90, 0.84, 1.0):
	set(value):
		sensor_color = value
		_request_rebuild()
@export var ridge_color: Color = Color(0.16, 0.10, 0.15, 1.0):
	set(value):
		ridge_color = value
		_request_rebuild()
@export_storage var body_emission_strength: float = 0.04:
	set(value):
		body_emission_strength = value
		_request_rebuild()
@export_range(0.0, 5.0, 0.01) var sensor_emission_strength: float = 1.35:
	set(value):
		sensor_emission_strength = value
		_request_rebuild()
@export_storage var appendage_emission_strength: float = 0.08:
	set(value):
		appendage_emission_strength = value
		_request_rebuild()

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
var _state_name: String = STATE_WANDER
var _desired_velocity: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _direction: Vector3 = Vector3.FORWARD
var _target_direction: Vector3 = Vector3.FORWARD
var _motion_forward: Vector3 = Vector3.FORWARD
var _time: float = 0.0
var _state_age: float = 0.0
var _speed_reference: float = 0.26
var _rebuild_requested: bool = false

var _pose_root: Node3D
var _spine_root: Node3D
var _sensor_root: Node3D
var _appendage_root: Node3D
var _spine_segments: Array[Node3D] = []
var _spine_visuals: Array[MeshInstance3D] = []
var _appendages: Array[Node3D] = []
var _base_segment_positions: Array[Vector3] = []
var _base_segment_scales: Array[Vector3] = []
var _smoothed_segment_positions: Array[Vector3] = []
var _smoothed_segment_rotations: Array[Vector3] = []
var _smoothed_segment_scales: Array[Vector3] = []
var _smoothed_visual_scales: Array[Vector3] = []
var _chain_world_positions: Array[Vector3] = []
var _chain_lead_direction: Vector3 = Vector3.BACK

var _ribbon_material: StandardMaterial3D
var _underside_material: StandardMaterial3D
var _appendage_material: StandardMaterial3D
var _sensor_material: StandardMaterial3D
var _ridge_material: StandardMaterial3D


func _ready() -> void:
	if build_on_ready:
		build_visual()
	if auto_bind_parent and _agent == null:
		_try_bind_parent()
	set_process(true)


func _process(delta: float) -> void:
	if _rebuild_requested:
		build_visual()
	if Engine.is_editor_hint() and not animate_in_editor:
		return

	if auto_bind_parent and (_agent == null or not is_instance_valid(_agent)):
		_try_bind_parent()

	if read_agent_each_frame:
		_read_agent_values()

	_time += delta
	_state_age += delta
	var velocity_alpha: float = 1.0 - exp(-velocity_response * delta)
	_velocity = _velocity.lerp(_desired_velocity, velocity_alpha)

	_update_pose_motion(delta)
	_update_ribbon_body(delta)
	_update_appendages(delta)


func bind_agent(agent: Node) -> void:
	_agent = agent
	_agent_properties.clear()
	if _agent == null:
		return

	for property in _agent.get_property_list():
		_agent_properties[StringName(property.get("name", ""))] = true


func set_velocity(velocity: Vector3) -> void:
	_desired_velocity = velocity


func set_target_direction(direction: Vector3) -> void:
	_target_direction = _safe_direction(direction, _target_direction)


func set_agent_state(state_name: String) -> void:
	var normalized: String = _normalized_state(state_name)
	if normalized != _state_name:
		_state_age = 0.0
	_state_name = normalized


func set_visual_state(state_name: String) -> void:
	set_agent_state(state_name)


func build_visual() -> void:
	_rebuild_requested = false
	_pose_root = _ensure_root(self, "PoseRoot")
	_spine_root = _ensure_root(_pose_root, "SpineRoot")
	_sensor_root = _ensure_root(_pose_root, "SensorRoot")
	_appendage_root = _ensure_root(_pose_root, "AppendageRoot")

	_clear_generated(_spine_root)
	_clear_generated(_sensor_root)
	_clear_generated(_appendage_root)
	_spine_segments.clear()
	_spine_visuals.clear()
	_appendages.clear()

	_create_materials()
	_build_spine()
	_build_appendages()
	_cache_segment_defaults()


func _build_spine() -> void:
	var ribbon_mesh := _sphere_mesh(12, 6)
	var ridge_mesh := BoxMesh.new()
	ridge_mesh.size = Vector3.ONE
	var underside_mesh := BoxMesh.new()
	underside_mesh.size = Vector3.ONE
	var spacing: float = body_length / max(float(segment_count - 1), 1.0)

	for i in range(segment_count):
		var t: float = float(i) / max(float(segment_count - 1), 1.0)
		var taper: float = lerp(1.0, tail_taper, t)
		var segment := Node3D.new()
		segment.name = "RibbonSegment%02d" % i
		segment.position = Vector3(
			sin(t * PI * 1.2) * initial_curve_amount,
			-sin(t * PI) * body_height * 0.32,
			float(i) * spacing
		)
		_add_generated_child(_spine_root, segment)
		_spine_segments.append(segment)

		var plate := MeshInstance3D.new()
		plate.name = "RibbonPlate"
		plate.mesh = ribbon_mesh
		plate.scale = Vector3(
			body_width * taper,
			body_height * lerp(1.0, 0.72, t),
			body_depth * lerp(1.0, 0.70, t)
		)
		plate.material_override = _ribbon_material
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_generated_child(segment, plate)
		_spine_visuals.append(plate)

		var underside := MeshInstance3D.new()
		underside.name = "UndersideFold"
		underside.mesh = underside_mesh
		underside.position = Vector3(0.0, -body_height * 1.05, 0.03)
		underside.scale = Vector3(body_width * 0.62 * taper, body_height * 0.28, body_depth * 0.70)
		underside.material_override = _underside_material
		underside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_generated_child(segment, underside)

		var ridge := MeshInstance3D.new()
		ridge.name = "DorsalRidge"
		ridge.mesh = ridge_mesh
		ridge.position = Vector3(0.0, body_height * 1.02, -body_depth * 0.04)
		ridge.scale = Vector3(body_width * 0.12 * taper, body_height * 0.25, body_depth * 0.95)
		ridge.material_override = _ridge_material
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_generated_child(segment, ridge)

		if i == 0:
			_build_leading_head(segment)


func _build_leading_head(parent_segment: Node3D) -> void:
	var head_mesh := _sphere_mesh(14, 7)
	var slit_mesh := BoxMesh.new()
	slit_mesh.size = Vector3.ONE
	var head_offset := Vector3(0.0, 0.035, -0.17)

	var head := MeshInstance3D.new()
	head.name = "LeadingHusk"
	head.mesh = head_mesh
	head.position = head_offset
	head.rotation = Vector3(deg_to_rad(-7.0), 0.0, 0.0)
	head.scale = head_scale
	head.material_override = _ribbon_material
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated_child(parent_segment, head)

	var sensor_socket := Node3D.new()
	sensor_socket.name = "SensorSlits"
	sensor_socket.position = head_offset + Vector3(0.0, head_scale.y * 0.25, -head_scale.z * 0.72)
	_add_generated_child(parent_segment, sensor_socket)

	for i in range(sensor_slit_count):
		var t: float = float(i) / max(float(sensor_slit_count - 1), 1.0)
		var x: float = lerp(-head_scale.x * 0.46, head_scale.x * 0.46, t)
		var y: float = sin(t * PI) * sensor_slit_height * 1.4
		var slit := MeshInstance3D.new()
		slit.name = "SensorSlit%02d" % i
		slit.mesh = slit_mesh
		slit.position = Vector3(x, y, 0.0)
		slit.rotation = Vector3(0.0, 0.0, deg_to_rad(lerp(10.0, -10.0, t)))
		slit.scale = Vector3(sensor_slit_width * lerp(0.7, 1.2, sin(t * PI)), sensor_slit_height, sensor_slit_height * 0.8)
		slit.material_override = _sensor_material
		slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_generated_child(sensor_socket, slit)


func _build_appendages() -> void:
	if _spine_segments.is_empty():
		return

	var front_segment := _spine_segments[0]
	_add_appendage(front_segment, "LeftProbe", "FEELER", -1.0, Vector3(-body_width * 0.46, -body_height * 0.18, -body_depth * 0.34), feeler_segments, feeler_segment_length, feeler_radius, Vector3.LEFT * 0.45 + Vector3.FORWARD)
	_add_appendage(front_segment, "RightProbe", "FEELER", 1.0, Vector3(body_width * 0.46, -body_height * 0.18, -body_depth * 0.34), feeler_segments, feeler_segment_length, feeler_radius, Vector3.RIGHT * 0.45 + Vector3.FORWARD)

	for pair_index in range(sweeper_pairs):
		var source_index: int = clamp(1 + pair_index * 2, 1, segment_count - 1)
		var segment := _spine_segments[source_index]
		var t: float = float(source_index) / max(float(segment_count - 1), 1.0)
		var local_width: float = body_width * lerp(1.0, tail_taper, t)
		var chain_length: float = sweeper_segment_length * lerp(1.15, 0.84, t)
		var radius: float = sweeper_radius * lerp(1.12, 0.78, t)
		_add_appendage(segment, "LeftSweeper%02d" % pair_index, "SWEEPER", -1.0, Vector3(-local_width * 0.58, -body_height * 0.42, -body_depth * 0.08), sweeper_segments, chain_length, radius, Vector3.LEFT + Vector3.BACK * 0.18)
		_add_appendage(segment, "RightSweeper%02d" % pair_index, "SWEEPER", 1.0, Vector3(local_width * 0.58, -body_height * 0.42, -body_depth * 0.08), sweeper_segments, chain_length, radius, Vector3.RIGHT + Vector3.BACK * 0.18)

	var tail_segment := _spine_segments[segment_count - 1]
	_add_appendage(tail_segment, "LeftTailStabilizer", "STABILIZER", -1.0, Vector3(-body_width * tail_taper * 0.42, -body_height * 0.30, body_depth * 0.18), max(3, sweeper_segments - 1), sweeper_segment_length * 0.9, sweeper_radius * 0.72, Vector3.LEFT + Vector3.BACK * 0.75)
	_add_appendage(tail_segment, "RightTailStabilizer", "STABILIZER", 1.0, Vector3(body_width * tail_taper * 0.42, -body_height * 0.30, body_depth * 0.18), max(3, sweeper_segments - 1), sweeper_segment_length * 0.9, sweeper_radius * 0.72, Vector3.RIGHT + Vector3.BACK * 0.75)


func _add_appendage(
		parent_segment: Node3D,
		appendage_name: String,
		role: String,
		side: float,
		offset: Vector3,
		chain_segments: int,
		chain_length: float,
		radius: float,
		rest: Vector3
) -> void:
	var chain: Node3D = CrawlerAppendageIKChainScript.new()
	chain.name = appendage_name
	chain.position = offset
	chain.set(&"behavior_role", role)
	chain.set(&"side_sign", side)
	chain.set(&"segment_count", chain_segments)
	chain.set(&"segment_length", chain_length)
	chain.set(&"base_radius", radius)
	chain.set(&"tip_radius_factor", 0.28 if role == "FEELER" else 0.36)
	chain.set(&"rest_direction", rest.normalized())
	chain.set(&"downward_bias", 0.16 if role == "FEELER" else 0.34)
	chain.set(&"phase", float(_appendages.size()) * 0.63)
	chain.set(&"segment_material", _appendage_material)
	chain.set(&"auto_update", false)
	_add_generated_child(parent_segment, chain)
	chain.call(&"build_chain")
	_appendages.append(chain)


func _update_pose_motion(delta: float) -> void:
	if _pose_root == null:
		return

	var local_velocity: Vector3 = global_transform.basis.inverse() * _velocity
	local_velocity.y *= vertical_turn_influence
	var speed_factor: float = clamp(local_velocity.length() / max(_speed_reference, 0.01), 0.0, 1.0)
	var heading_speed: float = max(_velocity.length(), _desired_velocity.length() * 0.35)
	var heading_factor: float = clamp(heading_speed / max(_speed_reference, 0.01), 0.0, 1.0)
	var desired_world_forward: Vector3 = _target_direction
	if desired_world_forward.length_squared() <= 0.0001:
		desired_world_forward = _direction
	if heading_speed > minimum_facing_speed and desired_world_forward.length_squared() > 0.0001:
		var desired_local_forward: Vector3 = global_transform.basis.inverse() * desired_world_forward
		desired_local_forward.y *= vertical_turn_influence
		desired_local_forward = _safe_direction(desired_local_forward, _motion_forward)
		var head_turn_speed: float = deg_to_rad(head_turn_degrees_per_second) * lerp(0.18, 1.0, heading_factor)
		_motion_forward = _limit_direction_angle(desired_local_forward, _motion_forward, head_turn_speed * delta)

	var yaw_basis: Basis = _basis_from_forward(_motion_forward, _pose_root.transform.basis)
	var lean_angle: float = deg_to_rad(movement_lean_amount) * speed_factor
	var max_bank_angle: float = deg_to_rad(max_bank_angle_degrees)
	var roll_angle: float = deg_to_rad(movement_lean_amount * 0.22) * clamp(local_velocity.x / max(_speed_reference, 0.01), -1.0, 1.0)
	roll_angle = clamp(roll_angle, -max_bank_angle, max_bank_angle)
	var target_basis: Basis = yaw_basis * Basis(Vector3.RIGHT, lean_angle) * Basis(Vector3.FORWARD, roll_angle)
	var current_quat: Quaternion = _pose_root.transform.basis.get_rotation_quaternion()
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()
	var rotation_alpha: float = 1.0 - exp(-head_turn_response * delta)

	var transform: Transform3D = _pose_root.transform
	transform.basis = Basis(current_quat.slerp(target_quat, rotation_alpha)).orthonormalized()
	transform.origin = Vector3(0.0, sin(_time * TAU * drift_frequency) * drift_amplitude, -body_length * 0.5)
	_pose_root.transform = transform


func _update_ribbon_body(delta: float) -> void:
	if _spine_segments.is_empty():
		return

	var count: int = _spine_segments.size()
	var state: String = _visual_state()
	var local_velocity: Vector3 = _pose_root.global_transform.basis.inverse() * _velocity
	local_velocity.y *= 0.18
	var speed_factor: float = clamp(local_velocity.length() / max(_speed_reference, 0.01), 0.0, 1.0)
	var pulse: float = sin(_time * TAU * pulse_frequency) * body_pulse_amount
	var undulation_scale: float = 1.0
	var spacing_scale: float = 1.0
	var lag_scale: float = 1.0
	var turn_lag_scale: float = 1.0
	var sensor_brightness: float = 1.0
	var curl_scale: float = 0.0

	match state:
		"IDLE":
			undulation_scale = 0.34
			spacing_scale = 0.97
			lag_scale = 0.36
			turn_lag_scale = 0.62
			sensor_brightness = 0.82
		"WANDER":
			undulation_scale = lerp(0.52, 1.0, speed_factor)
			spacing_scale = 1.0
			lag_scale = 1.0
		"OBSERVE":
			undulation_scale = 0.12
			spacing_scale = 1.04
			lag_scale = 0.14
			turn_lag_scale = 0.42
			sensor_brightness = 1.55
		"FLEE":
			undulation_scale = 1.15
			spacing_scale = 0.88
			lag_scale = 1.62
			turn_lag_scale = 1.22
			sensor_brightness = 1.42
		"STARTLED":
			undulation_scale = 0.06
			spacing_scale = 0.54
			lag_scale = 0.08
			turn_lag_scale = 0.18
			sensor_brightness = 1.85
			curl_scale = max(0.0, 1.0 - _state_age / 0.38)
		"CONFIDENT":
			undulation_scale = 0.25
			spacing_scale = 1.10
			lag_scale = 0.32
			turn_lag_scale = 0.76
			sensor_brightness = 1.10

	var trail_direction: Vector3 = Vector3.ZERO
	if local_velocity.length_squared() > 0.0001:
		trail_direction = -local_velocity.normalized()

	var body_alpha: float = 1.0 - exp(-body_smoothing_speed * delta)
	if _smoothed_segment_positions.size() != count or _chain_world_positions.size() != count:
		_cache_segment_defaults()

	_update_spine_chain_positions(spacing_scale, delta)

	for i in range(count):
		var segment := _spine_segments[i]
		if not is_instance_valid(segment):
			continue

		var t: float = float(i) / max(float(count - 1), 1.0)
		var wave_phase: float = _time * TAU * wave_frequency + t * PI * follow_lag * 2.0
		var wave: float = sin(wave_phase)
		var counter_wave: float = cos(wave_phase * 0.72 + 0.6)
		var vertical_wave: float = sin(wave_phase - PI * 0.5)
		var lag: Vector3 = trail_direction * body_lag_amount * lag_scale * speed_factor * t
		var position: Vector3 = _spine_root.to_local(_chain_world_positions[i])

		position.x += wave * wave_amount * undulation_scale * lerp(0.15, 1.0, t)
		position.y += vertical_wave * vertical_wave_amount * undulation_scale * lerp(0.12, 1.0, t)
		position.y += counter_wave * body_pulse_amount * 0.24 * lerp(0.2, 1.0, t)
		position += lag

		if curl_scale > 0.0:
			var curl_angle: float = t * PI
			position.x += sin(curl_angle) * startled_curl_amount * curl_scale
			position.z *= lerp(1.0, 0.58, curl_scale)
			position.y += curl_scale * 0.08 * sin(curl_angle)

		var target_rotation: Vector3 = _segment_rotation_from_chain(i, vertical_wave, wave, undulation_scale, body_turn_lag_amount * turn_lag_scale)
		var target_scale: Vector3 = Vector3.ONE * (1.0 + pulse * lerp(0.35, 0.90, t))
		if state == "FLEE":
			target_scale.x *= 1.0 - flee_tension_amount * 0.10
			target_scale.y *= 1.0 - flee_tension_amount * 0.16
			target_scale.z *= 1.0 + flee_tension_amount * 0.14

		_smoothed_segment_positions[i] = _smoothed_segment_positions[i].lerp(position, body_alpha)
		_smoothed_segment_rotations[i] = _smoothed_segment_rotations[i].lerp(target_rotation, body_alpha)
		_smoothed_segment_scales[i] = _smoothed_segment_scales[i].lerp(target_scale, body_alpha)
		segment.position = _smoothed_segment_positions[i]
		segment.rotation = _smoothed_segment_rotations[i]
		segment.scale = _smoothed_segment_scales[i]

	for i in range(min(_spine_visuals.size(), _base_segment_scales.size())):
		var visual := _spine_visuals[i]
		if not is_instance_valid(visual):
			continue
		var t: float = float(i) / max(float(count - 1), 1.0)
		var base_scale: Vector3 = _base_segment_scales[i]
		var target_visual_scale := Vector3(
			base_scale.x * (1.0 + pulse * 0.24),
			base_scale.y * (1.0 - pulse * 0.18),
			base_scale.z * (1.0 + pulse * lerp(0.40, 0.12, t))
		)
		_smoothed_visual_scales[i] = _smoothed_visual_scales[i].lerp(target_visual_scale, body_alpha)
		visual.scale = _smoothed_visual_scales[i]

	_set_sensor_emphasis(sensor_brightness)


func _update_appendages(delta: float) -> void:
	if _appendages.is_empty():
		return

	var body_pulse: float = sin(_time * TAU * pulse_frequency) * body_pulse_amount
	var locomotion_phase: float = _time * TAU * wave_frequency * 0.45
	var trail_scale: float = appendage_trail_strength
	var sweep_scale: float = appendage_sweep_strength
	var probe_scale: float = appendage_probe_strength
	var follow_scale: float = appendage_follow_speed
	var state: String = _visual_state()

	match state:
		"IDLE":
			trail_scale *= 0.35
			sweep_scale *= 0.35
			probe_scale *= 0.72
		"OBSERVE":
			trail_scale *= 0.18
			sweep_scale *= 0.12
			probe_scale *= 1.55
			follow_scale *= 0.72
		"FLEE":
			trail_scale *= 1.85
			sweep_scale *= 1.65
			probe_scale *= 0.35
			follow_scale *= 1.55
		"STARTLED":
			trail_scale *= 0.12
			sweep_scale *= 0.08
			probe_scale *= 0.12
			follow_scale *= 2.0
		"CONFIDENT":
			trail_scale *= 0.42
			sweep_scale *= 0.28
			probe_scale *= 1.05
			follow_scale *= 0.78

	for appendage in _appendages:
		if not is_instance_valid(appendage):
			continue
		appendage.call(
			&"set_motion_context",
			_velocity,
			state,
			locomotion_phase,
			body_pulse,
			trail_scale,
			sweep_scale,
			probe_scale,
			follow_scale
		)
		appendage.call(&"animate", delta)


func _cache_segment_defaults() -> void:
	_base_segment_positions.clear()
	_base_segment_scales.clear()
	_smoothed_segment_positions.clear()
	_smoothed_segment_rotations.clear()
	_smoothed_segment_scales.clear()
	_smoothed_visual_scales.clear()
	_chain_world_positions.clear()

	for segment in _spine_segments:
		if is_instance_valid(segment):
			_base_segment_positions.append(segment.position)
			_smoothed_segment_positions.append(segment.position)
			_smoothed_segment_rotations.append(segment.rotation)
			_smoothed_segment_scales.append(segment.scale)
			_chain_world_positions.append(_spine_root.to_global(segment.position))

	if is_instance_valid(_spine_root):
		_chain_lead_direction = _safe_direction(_spine_root.global_transform.basis * Vector3.BACK, Vector3.BACK)

	for visual in _spine_visuals:
		if is_instance_valid(visual):
			_base_segment_scales.append(visual.scale)
			_smoothed_visual_scales.append(visual.scale)


func _update_spine_chain_positions(spacing_scale: float, delta: float) -> void:
	if _chain_world_positions.is_empty() or _base_segment_positions.is_empty():
		return

	_chain_world_positions[0] = _spine_root.to_global(_base_segment_positions[0])
	var target_fallback_direction: Vector3 = (_spine_root.global_transform.basis * Vector3.BACK).normalized()
	var heading_alpha: float = 1.0 - exp(-body_heading_follow_speed * delta)
	_chain_lead_direction = _safe_direction(
		_chain_lead_direction.lerp(target_fallback_direction, heading_alpha),
		target_fallback_direction
	)
	var fallback_direction: Vector3 = _chain_lead_direction
	var count: int = min(_chain_world_positions.size(), _base_segment_positions.size())
	var max_step_turn: float = deg_to_rad(max_body_step_turn_degrees)
	var max_total_turn: float = deg_to_rad(max_body_total_turn_degrees)

	for i in range(1, count):
		var t: float = float(i) / max(float(count - 1), 1.0)
		var relaxed_total_turn: float = lerp(max_total_turn, PI, smoothstep(0.18, 1.0, t))
		var previous_position: Vector3 = _chain_world_positions[i - 1]
		var current_position: Vector3 = _chain_world_positions[i]
		var segment_spacing: float = _world_segment_spacing(i, spacing_scale)
		var current_direction: Vector3 = current_position - previous_position

		if current_direction.length_squared() < 0.0001:
			current_direction = fallback_direction
		else:
			current_direction = current_direction.normalized()

		var lead_direction: Vector3 = fallback_direction
		if i > 1:
			lead_direction = _safe_direction(
				_chain_world_positions[i - 1] - _chain_world_positions[i - 2],
				fallback_direction
			)
		current_direction = _limit_direction_angle(current_direction, lead_direction, max_step_turn)
		current_direction = _limit_direction_angle(current_direction, fallback_direction, relaxed_total_turn)

		var desired_position: Vector3 = previous_position + current_direction * segment_spacing
		var segment_follow_speed: float = lerp(spine_chain_follow_speed, body_turn_follow_speed, pow(t, body_turn_distribution))
		var segment_alpha: float = 1.0 - exp(-segment_follow_speed * delta)
		var blended_position: Vector3 = current_position.lerp(desired_position, segment_alpha)
		var constrained_direction: Vector3 = blended_position - previous_position

		if constrained_direction.length_squared() < 0.0001:
			constrained_direction = current_direction
		else:
			constrained_direction = constrained_direction.normalized()

		constrained_direction = _limit_direction_angle(constrained_direction, lead_direction, max_step_turn)
		constrained_direction = _limit_direction_angle(constrained_direction, fallback_direction, relaxed_total_turn)
		_chain_world_positions[i] = previous_position + constrained_direction * segment_spacing


func _world_segment_spacing(index: int, spacing_scale: float) -> float:
	if index <= 0 or index >= _base_segment_positions.size():
		return 0.001

	var current_base: Vector3 = _spine_root.to_global(_base_segment_positions[index])
	var previous_base: Vector3 = _spine_root.to_global(_base_segment_positions[index - 1])
	return max(current_base.distance_to(previous_base) * spacing_scale, 0.001)


func _segment_rotation_from_chain(index: int, vertical_wave: float, side_wave: float, undulation_scale: float, turn_strength: float) -> Vector3:
	var count: int = _chain_world_positions.size()
	if count <= 1:
		return Vector3.ZERO

	var current_local: Vector3 = _spine_root.to_local(_chain_world_positions[index])
	var tail_direction: Vector3 = Vector3.BACK

	if index < count - 1:
		var next_local: Vector3 = _spine_root.to_local(_chain_world_positions[index + 1])
		tail_direction = next_local - current_local
	elif index > 0:
		var previous_local: Vector3 = _spine_root.to_local(_chain_world_positions[index - 1])
		tail_direction = current_local - previous_local

	if tail_direction.length_squared() < 0.0001:
		tail_direction = Vector3.BACK
	else:
		tail_direction = tail_direction.normalized()

	var t: float = float(index) / max(float(count - 1), 1.0)
	var rotation_weight: float = clamp(turn_strength * lerp(0.42, 1.0, pow(t, body_turn_distribution)), 0.0, 1.2)
	var horizontal_length: float = Vector2(tail_direction.x, tail_direction.z).length()
	var chain_pitch: float = -atan2(tail_direction.y, max(horizontal_length, 0.001))
	var chain_yaw: float = atan2(tail_direction.x, tail_direction.z)
	var max_pitch: float = deg_to_rad(max_segment_pitch_degrees)
	var max_yaw: float = deg_to_rad(max_segment_yaw_degrees)
	var max_bank: float = deg_to_rad(max_bank_angle_degrees)
	var pitch: float = vertical_wave * 0.12 * undulation_scale + chain_pitch * rotation_weight
	var yaw: float = side_wave * 0.20 * undulation_scale + chain_yaw * rotation_weight
	var bank: float = side_wave * -0.18 * undulation_scale - chain_yaw * 0.22 * rotation_weight

	return Vector3(
		clamp(pitch, -max_pitch, max_pitch),
		clamp(yaw, -max_yaw, max_yaw),
		clamp(bank, -max_bank, max_bank)
	)


func _limit_direction_angle(direction: Vector3, reference: Vector3, max_angle: float) -> Vector3:
	var safe_reference: Vector3 = _safe_direction(reference, Vector3.BACK)
	var safe_direction: Vector3 = _safe_direction(direction, safe_reference)
	var angle: float = safe_reference.angle_to(safe_direction)
	if angle <= max_angle:
		return safe_direction

	var axis: Vector3 = safe_reference.cross(safe_direction)
	if axis.length_squared() < 0.0001:
		axis = safe_reference.cross(Vector3.UP)
		if axis.length_squared() < 0.0001:
			axis = safe_reference.cross(Vector3.RIGHT)

	return safe_reference.rotated(axis.normalized(), max_angle).normalized()


func _try_bind_parent() -> void:
	var candidate: Node = get_parent()
	while candidate != null:
		if candidate.is_in_group(&"interest_entity") or _node_has_property(candidate, &"current_state"):
			bind_agent(candidate)
			return
		candidate = candidate.get_parent()


func _read_agent_values() -> void:
	if _agent == null or not is_instance_valid(_agent):
		return

	var state_value: Variant = _get_agent_property(&"current_state", _state_name)
	if typeof(state_value) == TYPE_STRING or typeof(state_value) == TYPE_STRING_NAME:
		set_agent_state(String(state_value))

	var idle_value: Variant = _get_agent_property(&"debug_is_idle", false)
	if typeof(idle_value) == TYPE_BOOL and bool(idle_value):
		set_agent_state(STATE_IDLE)

	var hand_flee_value: Variant = _get_agent_property(&"debug_player_hand_flee_active", false)
	if typeof(hand_flee_value) == TYPE_BOOL and bool(hand_flee_value):
		set_agent_state(STATE_FLEE)

	var velocity_value: Variant = _get_agent_property(&"velocity", _desired_velocity)
	if typeof(velocity_value) == TYPE_VECTOR3:
		set_velocity(velocity_value)

	var direction_value: Variant = _get_agent_property(&"direction", _direction)
	if typeof(direction_value) == TYPE_VECTOR3:
		_direction = _safe_direction(direction_value, _direction)

	var target_direction_value: Variant = _get_agent_property(&"target_direction", _target_direction)
	if typeof(target_direction_value) == TYPE_VECTOR3:
		set_target_direction(target_direction_value)

	var max_speed_value: Variant = _get_agent_property(&"max_speed", _speed_reference)
	if typeof(max_speed_value) == TYPE_FLOAT or typeof(max_speed_value) == TYPE_INT:
		_speed_reference = max(float(max_speed_value), 0.01)


func _visual_state() -> String:
	if VALID_STATES.has(_state_name):
		return _state_name
	return STATE_WANDER


func _normalized_state(state_name: String) -> String:
	var normalized: String = state_name.strip_edges().to_upper()
	if VALID_STATES.has(normalized):
		return normalized
	return STATE_WANDER


func _set_sensor_emphasis(brightness_factor: float) -> void:
	if _sensor_material:
		_sensor_material.emission_energy_multiplier = sensor_emission_strength * brightness_factor
	if _ridge_material:
		_ridge_material.emission_energy_multiplier = max(0.02, body_emission_strength * brightness_factor * 0.5)


func _create_materials() -> void:
	_ribbon_material = _make_material(ribbon_color, sensor_color, body_emission_strength, 0.88)
	_underside_material = _make_material(underside_color, sensor_color, body_emission_strength * 0.4, 0.92)
	_appendage_material = _make_material(appendage_color, sensor_color, appendage_emission_strength, 0.86)
	_sensor_material = _make_material(sensor_color, sensor_color, sensor_emission_strength, 0.38)
	_ridge_material = _make_material(ridge_color, sensor_color, body_emission_strength * 0.6, 0.84)


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


func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		return fallback.normalized()
	return value.normalized()
