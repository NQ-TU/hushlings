extends Node3D
class_name AgentMotor3D

const SteeringHelper := preload("res://scripts/steering/Steering.gd")

enum SteeringMode {
	WANDER,
	SEEK,
	ARRIVE,
	FLEE,
}

@export_group("Movement")
@export_range(0.01, 5.0, 0.01) var max_speed: float = 0.48
@export_range(0.01, 5.0, 0.01) var max_force: float = 0.42
@export_range(0.01, 20.0, 0.01) var mass: float = 1.0

@export_group("Steering Test Modes")
@export var steering_mode: SteeringMode = SteeringMode.WANDER
@export var enable_keyboard_mode_switching: bool = true
@export var seek_target_path: NodePath
@export var arrive_target_path: NodePath
@export var flee_threat_path: NodePath
@export_range(0.05, 5.0, 0.01) var arrive_slowing_radius: float = 0.8
@export var apply_home_tether_in_test_modes: bool = true

@export_group("Wander")
@export_range(0.0, 2.0, 0.01) var wander_strength: float = 0.86
@export_range(0.01, 3.0, 0.01) var wander_frequency: float = 0.18
@export_range(0.01, 10.0, 0.01) var wander_smoothing: float = 1.25
@export_range(0.0, 1.0, 0.01) var vertical_wander_amount: float = 0.24

@export_group("Home Tether")
@export_range(0.1, 10.0, 0.01) var home_radius: float = 1.25
@export_range(0.0, 4.0, 0.01) var home_tether_strength: float = 0.72

@export_group("Facing")
@export var face_movement_direction: bool = true
@export_range(0.1, 16.0, 0.1) var rotation_response: float = 3.6

var direction: Vector3 = Vector3.FORWARD
var target_direction: Vector3 = Vector3.FORWARD
var velocity: Vector3 = Vector3.ZERO
var acceleration: Vector3 = Vector3.ZERO
var desired_velocity: Vector3 = Vector3.ZERO
var steering_force: Vector3 = Vector3.ZERO
var final_velocity: Vector3 = Vector3.ZERO
var home_position: Vector3 = Vector3.ZERO
var current_wander_direction: Vector3 = Vector3.FORWARD
var current_state: String = "WANDER"
var debug_has_target: bool = false
var debug_target_position: Vector3 = Vector3.ZERO
var debug_target_name: String = ""

var _elapsed_time: float = 0.0
var _wander_seed: float = 0.0
var _seek_target: Node3D
var _arrive_target: Node3D
var _flee_threat: Node3D


func _ready() -> void:
	home_position = global_position
	_wander_seed = _seed_from_name()
	current_wander_direction = _sample_wander_direction(0.0)
	direction = current_wander_direction
	target_direction = current_wander_direction
	_resolve_target_nodes()


func _process(delta: float) -> void:
	_elapsed_time += delta
	_update_wander_direction(delta)
	_update_steering(delta)
	_apply_motion(delta)
	_update_facing(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not enable_keyboard_mode_switching:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
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
	current_state = _mode_to_string(steering_mode)


func _update_wander_direction(delta: float) -> void:
	target_direction = _sample_wander_direction(_elapsed_time)

	var alpha: float = 1.0 - exp(-wander_smoothing * delta)
	current_wander_direction = current_wander_direction.lerp(target_direction, alpha)
	current_wander_direction = _safe_direction(current_wander_direction, Vector3.FORWARD)
	direction = current_wander_direction


func _update_steering(delta: float) -> void:
	if _target_needs_resolve(seek_target_path, _seek_target) \
			or _target_needs_resolve(arrive_target_path, _arrive_target) \
			or _target_needs_resolve(flee_threat_path, _flee_threat):
		_resolve_target_nodes()

	current_state = _mode_to_string(steering_mode)
	var combined_desired_velocity: Vector3 = _calculate_mode_desired_velocity()
	var uses_home_tether: bool = steering_mode == SteeringMode.WANDER or apply_home_tether_in_test_modes

	var distance_from_home: float = global_position.distance_to(home_position)
	var tether_start: float = home_radius * 0.55
	if uses_home_tether and distance_from_home > tether_start:
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
		combined_desired_velocity += home_desired_velocity * tether_blend * home_tether_strength

	desired_velocity = SteeringHelper.limit_vector(combined_desired_velocity, max_speed)
	if desired_velocity.length_squared() > 0.0001:
		target_direction = desired_velocity.normalized()

	steering_force = SteeringHelper.limit_vector(desired_velocity - velocity, max_force)
	acceleration = steering_force / max(mass, 0.001)
	final_velocity = SteeringHelper.limit_vector(velocity + acceleration * delta, max_speed)


func _calculate_mode_desired_velocity() -> Vector3:
	_set_debug_target(null)

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
				return SteeringHelper.flee(global_position, _flee_threat.global_position, max_speed)
		SteeringMode.WANDER:
			return current_wander_direction * max_speed * wander_strength

	return current_wander_direction * max_speed * wander_strength


func _apply_motion(delta: float) -> void:
	velocity = final_velocity
	global_position += velocity * delta


func _update_facing(delta: float) -> void:
	if not face_movement_direction:
		return

	if velocity.length_squared() <= 0.0001:
		return

	var target_basis: Basis = _basis_from_forward(velocity.normalized())
	var rotation_alpha: float = 1.0 - exp(-rotation_response * delta)
	var current_quat: Quaternion = global_transform.basis.get_rotation_quaternion()
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()
	var next_basis: Basis = Basis(current_quat.slerp(target_quat, rotation_alpha)).orthonormalized()

	var next_transform: Transform3D = global_transform
	next_transform.basis = next_basis
	global_transform = next_transform


func _sample_wander_direction(time: float) -> Vector3:
	var phase: float = time * TAU * wander_frequency + _wander_seed
	var sample: Vector3 = Vector3(
		sin(phase * 0.83),
		sin(phase * 1.37 + 1.4) * vertical_wander_amount,
		cos(phase * 0.67 + 0.8)
	)

	return _safe_direction(sample, Vector3.FORWARD)


func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		return fallback.normalized()
	return value.normalized()


func _basis_from_forward(forward: Vector3) -> Basis:
	var z_axis: Vector3 = -_safe_direction(forward, Vector3.FORWARD)
	var up_axis: Vector3 = Vector3.UP
	var x_axis: Vector3 = up_axis.cross(z_axis)
	if x_axis.length_squared() <= 0.0001:
		x_axis = Vector3.RIGHT
	else:
		x_axis = x_axis.normalized()

	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()


func _seed_from_name() -> float:
	var seed_text: String = "%s:%s" % [name, str(get_instance_id())]
	var seed_value: int = abs(hash(seed_text)) % 10000
	return float(seed_value) / 10000.0 * TAU


func _resolve_target_nodes() -> void:
	_seek_target = _get_node3d_or_null(seek_target_path)
	_arrive_target = _get_node3d_or_null(arrive_target_path)
	_flee_threat = _get_node3d_or_null(flee_threat_path)


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


func _mode_to_string(mode: SteeringMode) -> String:
	match mode:
		SteeringMode.SEEK:
			return "SEEK"
		SteeringMode.ARRIVE:
			return "ARRIVE"
		SteeringMode.FLEE:
			return "FLEE"
		_:
			return "WANDER"
