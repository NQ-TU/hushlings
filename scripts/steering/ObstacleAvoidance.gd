extends RefCounted
class_name ObstacleAvoidance

const AgentPerceptionHelper := preload("res://scripts/perception/AgentPerception.gd")


static func calculate(
	agent: Node3D,
	input_velocity: Vector3,
	feeler_length: float,
	feeler_angle_degrees: float,
	collision_mask: int,
	max_speed: float,
	exclude: Array = []
) -> Dictionary:
	var result: Dictionary = {
		"force": Vector3.ZERO,
		"hit": false,
		"hit_position": Vector3.ZERO,
		"hit_normal": Vector3.ZERO,
		"collider": null,
	}
	if agent == null or not agent.is_inside_tree() or feeler_length <= 0.0 or max_speed <= 0.0:
		return result

	var forward: Vector3 = _safe_direction(input_velocity, AgentPerceptionHelper.get_forward(agent))
	var right_axis: Vector3 = forward.cross(Vector3.UP)
	if right_axis.length_squared() <= 0.0001:
		right_axis = Vector3.RIGHT
	else:
		right_axis = right_axis.normalized()

	var angle: float = deg_to_rad(feeler_angle_degrees)
	var directions: Array[Vector3] = [
		forward,
		Quaternion(Vector3.UP, angle) * forward,
		Quaternion(Vector3.UP, -angle) * forward,
		Quaternion(right_axis, angle) * forward,
		Quaternion(right_axis, -angle) * forward,
	]
	var space_state: PhysicsDirectSpaceState3D = agent.get_world_3d().direct_space_state
	var origin: Vector3 = agent.global_position
	var combined_force: Vector3 = Vector3.ZERO
	var nearest_hit_distance: float = INF

	var ray_exclude: Array[RID] = _build_exclude_rids(agent, exclude)

	for direction in directions:
		var end_position: Vector3 = origin + direction.normalized() * feeler_length
		var query := PhysicsRayQueryParameters3D.create(origin, end_position)
		query.collision_mask = collision_mask
		query.exclude = ray_exclude
		query.collide_with_areas = true
		query.collide_with_bodies = true

		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			continue

		var hit_position: Vector3 = hit.get("position", end_position)
		var hit_normal: Vector3 = _safe_direction(hit.get("normal", -direction), -direction)
		var hit_distance: float = origin.distance_to(hit_position)
		var closeness: float = 1.0 - clamp(hit_distance / feeler_length, 0.0, 1.0)
		combined_force += hit_normal * max(closeness, 0.08)

		if hit_distance < nearest_hit_distance:
			nearest_hit_distance = hit_distance
			result["hit"] = true
			result["hit_position"] = hit_position
			result["hit_normal"] = hit_normal
			result["collider"] = hit.get("collider", null)

	if combined_force.length_squared() > 0.0001:
		result["force"] = combined_force.normalized() * max_speed

	return result


static func _build_exclude_rids(agent: Node3D, exclude: Array) -> Array[RID]:
	var exclude_rids: Array[RID] = []
	if agent is CollisionObject3D:
		exclude_rids.append((agent as CollisionObject3D).get_rid())

	for item in exclude:
		if item is RID:
			exclude_rids.append(item)
		elif item is CollisionObject3D:
			exclude_rids.append((item as CollisionObject3D).get_rid())

	return exclude_rids


static func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		return fallback.normalized()
	return value.normalized()
