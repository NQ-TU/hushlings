extends RefCounted
class_name Boids


static func separation(
	observer: Node3D,
	neighbours: Array,
	radius: float,
	max_speed: float,
	fallback_direction: Vector3 = Vector3.FORWARD,
	prediction_time: float = 0.0
) -> Vector3:
	if observer == null or radius <= 0.0001 or max_speed <= 0.0:
		return Vector3.ZERO

	var radius_sq: float = radius * radius
	var combined: Vector3 = Vector3.ZERO
	var count: int = 0
	var observer_velocity: Vector3 = _read_vector_property(observer, &"velocity")
	var observer_future_position: Vector3 = observer.global_position \
			+ observer_velocity * max(prediction_time, 0.0)
	for candidate in neighbours:
		var neighbour := candidate as Node3D
		if neighbour == null or neighbour == observer:
			continue

		var neighbour_velocity: Vector3 = _read_vector_property(neighbour, &"velocity")
		var current_offset: Vector3 = observer.global_position - neighbour.global_position
		var future_offset: Vector3 = observer_future_position \
				- (neighbour.global_position + neighbour_velocity * max(prediction_time, 0.0))
		var current_distance_sq: float = current_offset.length_squared()
		var future_distance_sq: float = future_offset.length_squared()
		var distance_sq: float = min(current_distance_sq, future_distance_sq)
		if distance_sq > radius_sq:
			continue

		var offset: Vector3 = future_offset if future_distance_sq <= current_distance_sq else current_offset
		var away_direction: Vector3
		var closeness: float
		if distance_sq <= 0.0001:
			away_direction = _safe_direction(fallback_direction, Vector3.FORWARD)
			closeness = 1.0
		else:
			var distance: float = sqrt(distance_sq)
			away_direction = offset / distance
			closeness = 1.0 - clamp(distance / radius, 0.0, 1.0)

		combined += away_direction * max(closeness, 0.05)
		count += 1

	if count == 0 or combined.length_squared() <= 0.0001:
		return Vector3.ZERO

	return combined.normalized() * max_speed


static func cohesion(
	observer: Node3D,
	neighbours: Array,
	radius: float,
	max_speed: float
) -> Vector3:
	if observer == null or radius <= 0.0001 or max_speed <= 0.0:
		return Vector3.ZERO

	var radius_sq: float = radius * radius
	var center: Vector3 = Vector3.ZERO
	var count: int = 0
	for candidate in neighbours:
		var neighbour := candidate as Node3D
		if neighbour == null or neighbour == observer:
			continue

		var distance_sq: float = observer.global_position.distance_squared_to(neighbour.global_position)
		if distance_sq > radius_sq:
			continue

		center += neighbour.global_position
		count += 1

	if count == 0:
		return Vector3.ZERO

	center /= float(count)
	var to_center: Vector3 = center - observer.global_position
	if to_center.length_squared() <= 0.0001:
		return Vector3.ZERO

	return to_center.normalized() * max_speed


static func alignment(
	observer: Node3D,
	neighbours: Array,
	radius: float,
	max_speed: float
) -> Vector3:
	if observer == null or radius <= 0.0001 or max_speed <= 0.0:
		return Vector3.ZERO

	var radius_sq: float = radius * radius
	var average_velocity: Vector3 = Vector3.ZERO
	var count: int = 0
	for candidate in neighbours:
		var neighbour := candidate as Node3D
		if neighbour == null or neighbour == observer:
			continue

		var distance_sq: float = observer.global_position.distance_squared_to(neighbour.global_position)
		if distance_sq > radius_sq:
			continue

		average_velocity += _read_vector_property(neighbour, &"velocity")
		count += 1

	if count == 0:
		return Vector3.ZERO

	average_velocity /= float(count)
	if average_velocity.length_squared() <= 0.0001:
		return Vector3.ZERO

	return average_velocity.normalized() * max_speed


static func neighbour_count(observer: Node3D, neighbours: Array, radius: float) -> int:
	if observer == null or radius <= 0.0001:
		return 0

	var radius_sq: float = radius * radius
	var count: int = 0
	for candidate in neighbours:
		var neighbour := candidate as Node3D
		if neighbour == null or neighbour == observer:
			continue

		if observer.global_position.distance_squared_to(neighbour.global_position) <= radius_sq:
			count += 1

	return count


static func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		return fallback.normalized()
	return value.normalized()


static func _read_vector_property(node: Node, property_name: StringName) -> Vector3:
	var value: Variant = node.get(property_name)
	if value is Vector3:
		return value
	return Vector3.ZERO
