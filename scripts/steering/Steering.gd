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


static func apply_home_box_tether(
	current_position: Vector3,
	home_position: Vector3,
	input_velocity: Vector3,
	max_speed: float,
	home_bounds_size: Vector3,
	home_tether_strength: float,
	tether_start_ratio: float = 0.72
) -> Vector3:
	if home_tether_strength <= 0.0 or max_speed <= 0.0:
		return input_velocity

	var half_extents: Vector3 = home_bounds_size * 0.5
	if half_extents.x <= 0.001 or half_extents.y <= 0.001 or half_extents.z <= 0.001:
		return input_velocity

	var offset: Vector3 = current_position - home_position
	var correction := Vector3(
		_axis_box_correction(offset.x, half_extents.x, tether_start_ratio),
		_axis_box_correction(offset.y, half_extents.y, tether_start_ratio),
		_axis_box_correction(offset.z, half_extents.z, tether_start_ratio)
	)
	if correction.length_squared() <= 0.0001:
		return input_velocity

	var tether_blend: float = clamp(correction.length(), 0.0, 1.0)
	var home_velocity: Vector3 = correction.normalized() * max_speed
	return input_velocity + home_velocity * tether_blend * home_tether_strength


static func is_outside_home_area(
	current_position: Vector3,
	home_position: Vector3,
	home_radius: float,
	use_home_bounds: bool,
	home_bounds_size: Vector3
) -> bool:
	if use_home_bounds:
		var half_extents: Vector3 = home_bounds_size * 0.5
		if half_extents.x <= 0.001 or half_extents.y <= 0.001 or half_extents.z <= 0.001:
			return false

		var offset: Vector3 = current_position - home_position
		return absf(offset.x) > half_extents.x \
				or absf(offset.y) > half_extents.y \
				or absf(offset.z) > half_extents.z

	if home_radius <= 0.0:
		return false

	return current_position.distance_to(home_position) > home_radius


static func is_inside_home_area(
	current_position: Vector3,
	home_position: Vector3,
	home_radius: float,
	use_home_bounds: bool,
	home_bounds_size: Vector3,
	inner_ratio: float
) -> bool:
	var ratio: float = clamp(inner_ratio, 0.1, 0.95)
	if use_home_bounds:
		var half_extents: Vector3 = home_bounds_size * 0.5 * ratio
		if half_extents.x <= 0.001 or half_extents.y <= 0.001 or half_extents.z <= 0.001:
			return true

		var offset: Vector3 = current_position - home_position
		return absf(offset.x) <= half_extents.x \
				and absf(offset.y) <= half_extents.y \
				and absf(offset.z) <= half_extents.z

	return current_position.distance_to(home_position) <= home_radius * ratio


static func home_return_direction(
	current_position: Vector3,
	home_position: Vector3,
	fallback_direction: Vector3,
	home_radius: float,
	use_home_bounds: bool,
	home_bounds_size: Vector3,
	inner_ratio: float
) -> Vector3:
	if use_home_bounds:
		var half_extents: Vector3 = home_bounds_size * 0.5 * clamp(inner_ratio, 0.1, 0.95)
		if half_extents.x > 0.001 and half_extents.y > 0.001 and half_extents.z > 0.001:
			var offset: Vector3 = current_position - home_position
			var correction := Vector3(
				_axis_inner_bounds_return(offset.x, half_extents.x),
				_axis_inner_bounds_return(offset.y, half_extents.y),
				_axis_inner_bounds_return(offset.z, half_extents.z)
			)
			if correction.length_squared() > 0.0001:
				return correction.normalized()

	var to_home: Vector3 = home_position - current_position
	return _safe_direction(to_home, fallback_direction)


static func _axis_box_correction(axis_offset: float, half_extent: float, tether_start_ratio: float) -> float:
	var start: float = half_extent * clamp(tether_start_ratio, 0.0, 0.98)
	var distance: float = abs(axis_offset)
	if distance <= start:
		return 0.0

	var pressure: float = clamp((distance - start) / max(half_extent - start, 0.001), 0.0, 1.0)
	return -sign(axis_offset) * pressure


static func _axis_inner_bounds_return(axis_offset: float, inner_extent: float) -> float:
	if absf(axis_offset) <= inner_extent:
		return 0.0

	return -sign(axis_offset)


static func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		return fallback.normalized()
	return value.normalized()
