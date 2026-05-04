extends RefCounted
class_name AgentPerception


static func nearest_in_group(
	observer: Node3D,
	group_name: StringName,
	radius: float,
	exclude_self: bool = true
) -> Node3D:
	if observer == null or not observer.is_inside_tree():
		return null

	var nearest: Node3D
	var nearest_distance_sq: float = radius * radius
	for candidate in observer.get_tree().get_nodes_in_group(group_name):
		var candidate_node := candidate as Node3D
		if candidate_node == null:
			continue
		if exclude_self and candidate_node == observer:
			continue

		var distance_sq: float = observer.global_position.distance_squared_to(candidate_node.global_position)
		if distance_sq <= nearest_distance_sq:
			nearest = candidate_node
			nearest_distance_sq = distance_sq

	return nearest


static func distance_to_or_negative(observer: Node3D, target: Node3D) -> float:
	if observer == null or target == null:
		return -1.0
	return observer.global_position.distance_to(target.global_position)


static func has_line_of_sight(
	observer: Node3D,
	target: Node3D,
	collision_mask: int,
	start_offset: Vector3 = Vector3.ZERO,
	target_offset: Vector3 = Vector3.ZERO,
	end_margin: float = 0.04,
	ignored_groups: Array = []
) -> bool:
	if observer == null or target == null:
		return false
	if not observer.is_inside_tree():
		return false
	if collision_mask == 0:
		return true

	var origin: Vector3 = observer.global_position + start_offset
	var target_position: Vector3 = target.global_position + target_offset
	var to_target: Vector3 = target_position - origin
	var distance: float = to_target.length()
	if distance <= 0.0001:
		return true

	var direction: Vector3 = to_target / distance
	var clipped_end: Vector3 = target_position - direction * min(max(end_margin, 0.0), distance * 0.45)
	var exclude_rids: Array[RID] = _build_exclude_rids(observer, target)
	var space_state := observer.get_world_3d().direct_space_state
	for _step in range(8):
		var query := PhysicsRayQueryParameters3D.create(origin, clipped_end)
		query.collision_mask = collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = exclude_rids

		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			return true

		var collider := hit.get("collider") as Node
		if not _is_in_any_group(collider, ignored_groups):
			return false
		if collider is CollisionObject3D:
			exclude_rids.append((collider as CollisionObject3D).get_rid())
		else:
			return true

	return false


static func is_target_in_fov(observer: Node3D, target: Node3D, fov_degrees: float) -> bool:
	if observer == null or target == null:
		return false
	if fov_degrees >= 359.0:
		return true

	var to_target: Vector3 = target.global_position - observer.global_position
	if to_target.length_squared() <= 0.0001:
		return true

	var dot_to_target: float = clamp(get_forward(observer).dot(to_target.normalized()), -1.0, 1.0)
	var fov_threshold: float = cos(deg_to_rad(fov_degrees * 0.5))
	return dot_to_target >= fov_threshold


static func get_forward(agent: Node3D) -> Vector3:
	var direction_value: Variant = agent.get(&"direction")
	if direction_value is Vector3 and direction_value.length_squared() > 0.0001:
		return direction_value.normalized()

	return (-agent.global_transform.basis.z).normalized()


static func _build_exclude_rids(observer: Node3D, target: Node3D) -> Array[RID]:
	var exclude_rids: Array[RID] = []
	if observer is CollisionObject3D:
		exclude_rids.append((observer as CollisionObject3D).get_rid())
	if target is CollisionObject3D:
		exclude_rids.append((target as CollisionObject3D).get_rid())
	return exclude_rids


static func _is_in_any_group(node: Node, group_names: Array) -> bool:
	if node == null:
		return false

	for group_name in group_names:
		if node.is_in_group(group_name):
			return true

	return false
