extends RefCounted
class_name PlayerPerception

const AgentPerceptionHelper := preload("res://scripts/perception/AgentPerception.gd")


static func hand_from_feeler_result(result: Dictionary, player_hand_group: StringName) -> Node3D:
	if not bool(result.get("hit", false)):
		return null

	var collider := result.get("collider", null) as Node3D
	if collider == null or not collider.is_in_group(player_hand_group):
		return null

	return collider


static func find_direct_gaze_source(
	observer: Node3D,
	player_group: StringName,
	player_hand_group: StringName,
	default_gaze_range: float,
	default_gaze_degrees: float,
	los_collision_mask: int,
	los_end_margin: float
) -> Node3D:
	if observer == null or not observer.is_inside_tree():
		return null

	var nearest_source: Node3D
	var nearest_distance_sq: float = INF
	for candidate in observer.get_tree().get_nodes_in_group(player_group):
		var source := candidate as Node3D
		if source == null or source.is_in_group(player_hand_group):
			continue
		if not _is_gaze_source(source):
			continue

		var gaze_range: float = _read_float(source, &"gaze_range", default_gaze_range)
		var distance_sq: float = observer.global_position.distance_squared_to(source.global_position)
		if distance_sq > gaze_range * gaze_range or distance_sq > nearest_distance_sq:
			continue

		var gaze_degrees: float = _read_float(
			source,
			&"dead_center_gaze_degrees",
			default_gaze_degrees
		)
		if not _is_source_looking_at(source, observer, gaze_degrees):
			continue
		if not AgentPerceptionHelper.has_line_of_sight(
			source,
			observer,
			los_collision_mask,
			Vector3.ZERO,
			Vector3.ZERO,
			los_end_margin
		):
			continue

		nearest_source = source
		nearest_distance_sq = distance_sq

	return nearest_source


static func flee_velocity(
	agent_position: Vector3,
	flee_target: Node3D,
	fallback_direction: Vector3,
	max_speed: float,
	speed_scale: float = 1.0
) -> Vector3:
	if not is_instance_valid(flee_target):
		return Vector3.ZERO

	var away_from_target: Vector3 = agent_position - flee_target.global_position
	return _safe_direction(away_from_target, fallback_direction) * max_speed * speed_scale


static func _is_gaze_source(source: Node3D) -> bool:
	var value: Variant = source.get(&"is_gaze_source")
	if value is bool:
		return value
	return true


static func _is_source_looking_at(source: Node3D, target: Node3D, gaze_degrees: float) -> bool:
	var to_target: Vector3 = target.global_position - source.global_position
	if to_target.length_squared() <= 0.0001:
		return true

	var dot_to_target: float = clamp(_get_forward(source).dot(to_target.normalized()), -1.0, 1.0)
	var gaze_threshold: float = cos(deg_to_rad(gaze_degrees * 0.5))
	return dot_to_target >= gaze_threshold


static func _get_forward(source: Node3D) -> Vector3:
	if source.has_method(&"get_forward_direction"):
		var forward_value: Variant = source.call(&"get_forward_direction")
		if forward_value is Vector3 and forward_value.length_squared() > 0.0001:
			return forward_value.normalized()

	return (-source.global_transform.basis.z).normalized()


static func _read_float(node: Node, property_name: StringName, fallback: float) -> float:
	var value: Variant = node.get(property_name)
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback


static func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		return fallback.normalized()
	return value.normalized()
