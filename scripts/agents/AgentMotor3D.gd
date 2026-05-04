extends Node3D
class_name AgentMotor3D

const SteeringHelper := preload("res://scripts/steering/Steering.gd")

@export_group("Movement")
@export_range(0.01, 5.0, 0.01) var max_speed: float = 0.48
@export_range(0.01, 5.0, 0.01) var max_force: float = 0.42
@export_range(0.01, 20.0, 0.01) var mass: float = 1.0

@export_group("Turn Inertia")
@export var turn_rate_limit_enabled: bool = false
@export_range(15.0, 720.0, 1.0) var max_turn_degrees_per_second: float = 150.0

@export_group("Facing")
@export var face_movement_direction: bool = true
@export_range(0.1, 16.0, 0.1) var rotation_response: float = 3.6

var direction: Vector3 = Vector3.FORWARD
var target_direction: Vector3 = Vector3.FORWARD
var requested_direction: Vector3 = Vector3.FORWARD
var turn_pressure: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var acceleration: Vector3 = Vector3.ZERO
var desired_velocity: Vector3 = Vector3.ZERO
var steering_force: Vector3 = Vector3.ZERO
var final_velocity: Vector3 = Vector3.ZERO


func apply_desired_velocity(input_desired_velocity: Vector3, delta: float) -> void:
	var requested_velocity: Vector3 = SteeringHelper.limit_vector(input_desired_velocity, max_speed)
	if requested_velocity.length_squared() > 0.0001:
		requested_direction = requested_velocity.normalized()

	desired_velocity = _apply_turn_rate_limit(requested_velocity, delta)
	if desired_velocity.length_squared() > 0.0001:
		target_direction = desired_velocity.normalized()
		direction = target_direction
	else:
		turn_pressure = 0.0

	steering_force = SteeringHelper.limit_vector(desired_velocity - velocity, max_force)
	acceleration = steering_force / max(mass, 0.001)
	final_velocity = SteeringHelper.limit_vector(velocity + acceleration * delta, max_speed)

	velocity = final_velocity
	global_position += velocity * delta
	_update_facing(delta)


func stop_motion() -> void:
	velocity = Vector3.ZERO
	acceleration = Vector3.ZERO
	desired_velocity = Vector3.ZERO
	steering_force = Vector3.ZERO
	final_velocity = Vector3.ZERO
	turn_pressure = 0.0


func _update_facing(delta: float) -> void:
	if not face_movement_direction:
		return

	if velocity.length_squared() <= 0.0001:
		return

	var facing_direction: Vector3 = direction if turn_rate_limit_enabled else velocity.normalized()
	var target_basis: Basis = _basis_from_forward(facing_direction)
	var rotation_alpha: float = 1.0 - exp(-rotation_response * delta)
	var current_quat: Quaternion = global_transform.basis.get_rotation_quaternion()
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()
	var next_basis: Basis = Basis(current_quat.slerp(target_quat, rotation_alpha)).orthonormalized()

	var next_transform: Transform3D = global_transform
	next_transform.basis = next_basis
	global_transform = next_transform


func _apply_turn_rate_limit(input_desired_velocity: Vector3, delta: float) -> Vector3:
	if not turn_rate_limit_enabled:
		turn_pressure = 0.0
		return input_desired_velocity
	if delta <= 0.0 or input_desired_velocity.length_squared() <= 0.0001:
		turn_pressure = 0.0
		return input_desired_velocity

	var target_heading: Vector3 = input_desired_velocity.normalized()
	var current_heading: Vector3 = direction
	current_heading = _safe_direction(current_heading, target_heading)

	var angle_to_target: float = current_heading.angle_to(target_heading)
	var max_turn: float = deg_to_rad(max_turn_degrees_per_second) * delta
	if angle_to_target <= max_turn or angle_to_target <= 0.0001:
		turn_pressure = 0.0
		return input_desired_velocity

	var limited_heading: Vector3 = _rotate_direction_toward(current_heading, target_heading, max_turn)
	turn_pressure = clamp(angle_to_target / PI, 0.0, 1.0)
	return limited_heading * input_desired_velocity.length()


func _rotate_direction_toward(current: Vector3, target: Vector3, max_angle: float) -> Vector3:
	var axis: Vector3 = current.cross(target)
	if axis.length_squared() <= 0.0001:
		axis = _orthogonal_axis(current)
	else:
		axis = axis.normalized()

	return current.rotated(axis, max_angle).normalized()


func _orthogonal_axis(direction_value: Vector3) -> Vector3:
	var axis: Vector3 = Vector3.UP.cross(direction_value)
	if axis.length_squared() <= 0.0001:
		axis = Vector3.RIGHT.cross(direction_value)
	if axis.length_squared() <= 0.0001:
		return Vector3.UP
	return axis.normalized()


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


func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		return fallback.normalized()
	return value.normalized()


func _make_instance_seed() -> float:
	var seed_text: String = "%s:%s" % [name, str(get_instance_id())]
	var seed_value: int = abs(hash(seed_text)) % 10000
	return float(seed_value) / 10000.0 * TAU
