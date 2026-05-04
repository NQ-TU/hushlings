extends RefCounted
class_name Steering


static func seek(current_position: Vector3, target_position: Vector3, max_speed: float) -> Vector3:
	var to_target: Vector3 = target_position - current_position
	if to_target.length_squared() <= 0.0001:
		return Vector3.ZERO

	return to_target.normalized() * max_speed


static func flee(current_position: Vector3, threat_position: Vector3, max_speed: float) -> Vector3:
	var away_from_threat: Vector3 = current_position - threat_position
	if away_from_threat.length_squared() <= 0.0001:
		return Vector3.FORWARD * max_speed

	return away_from_threat.normalized() * max_speed


static func arrive(
	current_position: Vector3,
	target_position: Vector3,
	max_speed: float,
	slowing_radius: float
) -> Vector3:
	var to_target: Vector3 = target_position - current_position
	var distance: float = to_target.length()
	if distance <= 0.0001:
		return Vector3.ZERO

	var target_speed: float = max_speed
	if slowing_radius > 0.0001:
		target_speed = max_speed * clamp(distance / slowing_radius, 0.0, 1.0)

	return to_target / distance * target_speed


static func limit_vector(value: Vector3, max_length: float) -> Vector3:
	if max_length <= 0.0:
		return Vector3.ZERO

	if value.length_squared() > max_length * max_length:
		return value.normalized() * max_length

	return value


static func apply_home_tether(
	current_position: Vector3,
	home_position: Vector3,
	input_velocity: Vector3,
	max_speed: float,
	home_radius: float,
	home_tether_strength: float
) -> Vector3:
	if home_radius <= 0.0 or home_tether_strength <= 0.0:
		return input_velocity

	var distance_from_home: float = current_position.distance_to(home_position)
	var tether_start: float = home_radius * 0.55
	if distance_from_home <= tether_start:
		return input_velocity

	var tether_blend: float = clamp(
		(distance_from_home - tether_start) / max(home_radius - tether_start, 0.001),
		0.0,
		1.0
	)
	var home_velocity: Vector3 = arrive(current_position, home_position, max_speed, home_radius)
	return input_velocity + home_velocity * tether_blend * home_tether_strength
