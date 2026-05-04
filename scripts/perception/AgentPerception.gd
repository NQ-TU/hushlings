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
	end_margin: float = 0.04
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
	var query := PhysicsRayQueryParameters3D.create(origin, clipped_end)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = _build_exclude_rids(observer, target)

	return observer.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func _build_exclude_rids(observer: Node3D, target: Node3D) -> Array[RID]:
	var exclude_rids: Array[RID] = []
	if observer is CollisionObject3D:
		exclude_rids.append((observer as CollisionObject3D).get_rid())
	if target is CollisionObject3D:
		exclude_rids.append((target as CollisionObject3D).get_rid())
	return exclude_rids
