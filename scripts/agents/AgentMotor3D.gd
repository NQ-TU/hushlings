extends Node3D
class_name AgentMotor3D

const SteeringHelper := preload("res://scripts/steering/Steering.gd")

@export_group("Movement")
@export_range(0.01, 5.0, 0.01) var max_speed: float = 0.48
@export_range(0.01, 5.0, 0.01) var max_force: float = 0.42
@export_range(0.01, 20.0, 0.01) var mass: float = 1.0

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

var _elapsed_time: float = 0.0
var _wander_seed: float = 0.0


func _ready() -> void:
	home_position = global_position
	_wander_seed = _seed_from_name()
	current_wander_direction = _sample_wander_direction(0.0)
	direction = current_wander_direction
	target_direction = current_wander_direction


func _process(delta: float) -> void:
	_elapsed_time += delta
	_update_wander_direction(delta)
	_update_steering(delta)
	_apply_motion(delta)
	_update_facing(delta)


func _update_wander_direction(delta: float) -> void:
	target_direction = _sample_wander_direction(_elapsed_time)

	var alpha: float = 1.0 - exp(-wander_smoothing * delta)
	current_wander_direction = current_wander_direction.lerp(target_direction, alpha)
	current_wander_direction = _safe_direction(current_wander_direction, Vector3.FORWARD)
	direction = current_wander_direction


func _update_steering(delta: float) -> void:
	var wander_desired_velocity: Vector3 = current_wander_direction * max_speed * wander_strength
	var combined_desired_velocity: Vector3 = wander_desired_velocity

	var distance_from_home: float = global_position.distance_to(home_position)
	var tether_start: float = home_radius * 0.55
	if distance_from_home > tether_start:
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
	steering_force = SteeringHelper.limit_vector(desired_velocity - velocity, max_force)
	acceleration = steering_force / max(mass, 0.001)
	final_velocity = SteeringHelper.limit_vector(velocity + acceleration * delta, max_speed)


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
