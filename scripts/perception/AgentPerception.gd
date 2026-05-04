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
