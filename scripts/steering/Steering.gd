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
