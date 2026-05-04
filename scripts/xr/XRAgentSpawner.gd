extends Node3D
class_name XRAgentSpawner

@export_group("Scene References")
@export var creature_root_path: NodePath = ^"../CreatureRoot"
@export var camera_path: NodePath = ^"../XROrigin3D/XRCamera3D"
@export var hushling_scene: PackedScene
@export var crawler_scene: PackedScene
@export var timid_profile: Resource
@export var bold_profile: Resource

@export_group("Spawn")
@export var spawn_on_ready: bool = true
@export var clear_existing_on_spawn: bool = true
@export var spawned_group: StringName = &"xr_spawned_agent"
@export var agent_debug_enabled: bool = false
@export_range(0.05, 2.0, 0.01) var hushling_scale: float = 0.32
@export var use_hushling_scale_variants: bool = true
@export_range(0.05, 2.0, 0.01) var small_hushling_scale: float = 0.1
@export_range(0.05, 2.0, 0.01) var medium_hushling_scale: float = 0.25
@export_range(0.05, 2.0, 0.01) var large_hushling_scale: float = 0.4
@export_range(0.0, 1.0, 0.01) var small_hushling_chance: float = 0.5
@export_range(0.0, 1.0, 0.01) var medium_hushling_chance: float = 0.25
@export_range(0.05, 2.0, 0.01) var crawler_scale: float = 0.4
@export var randomize_spawn_positions: bool = true
@export var hushling_count: int = 6
@export_range(0, 8, 1) var crawler_count: int = 1
@export_range(0.0, 3.0, 0.01) var min_player_spawn_distance: float = 0.65
@export_range(0.0, 3.0, 0.01) var min_agent_spawn_distance: float = 0.28
@export var hushling_offsets: Array[Vector3] = [
	Vector3(-0.32, -0.45, -1.35),
	Vector3(-0.04, -0.35, -1.48),
	Vector3(0.22, -0.51, -1.26),
]
@export var crawler_offset: Vector3 = Vector3(0.64, -0.48, -1.68)
@export var crawler_offsets: Array[Vector3] = [
	Vector3(0.64, -0.48, -1.68),
]

@export_group("XR Habitat")
@export var use_shared_home_bounds: bool = true
@export var habitat_follows_player: bool = true
@export var habitat_center_offset: Vector3 = Vector3(0.0, -0.45, 0.0)
@export var habitat_bounds_size: Vector3 = Vector3(2.2, 1.3, 2.2)
@export_range(0.0, 4.0, 0.01) var xr_habitat_tether_strength: float = 0.72

@export_group("XR Behaviour Tuning")
@export var apply_compact_xr_tuning: bool = true
@export_range(0.1, 5.0, 0.01) var xr_awareness_radius: float = 1.35
@export_range(0.1, 5.0, 0.01) var xr_observe_distance: float = 0.45
@export_range(0.05, 5.0, 0.01) var xr_interest_flee_radius: float = 0.62
@export_range(0.1, 5.0, 0.01) var xr_flee_safe_radius: float = 1.0
@export_range(0.1, 5.0, 0.01) var xr_regroup_radius: float = 1.35
@export_range(0.1, 5.0, 0.01) var xr_hushling_home_radius: float = 0.72
@export_range(0.1, 5.0, 0.01) var xr_crawler_home_radius: float = 0.55
@export_range(0.01, 2.0, 0.01) var xr_crawler_max_speed: float = 0.34
@export_range(0.01, 2.0, 0.01) var xr_crawler_max_force: float = 0.38

var _shared_home_position: Vector3 = Vector3.ZERO
var _spawned_world_positions: Array[Vector3] = []
var _spawn_sample_index: int = 0
var _spawn_sample_offset: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if spawn_on_ready:
		call_deferred("spawn_agents")


func _process(_delta: float) -> void:
	if not use_shared_home_bounds or not habitat_follows_player:
		return

	_shared_home_position = _offset_to_world(habitat_center_offset)
	_update_spawned_home_bounds()


func spawn_agents() -> void:
	var creature_root := get_node_or_null(creature_root_path) as Node3D
	if creature_root == null:
		push_warning("XRAgentSpawner could not find CreatureRoot at %s" % creature_root_path)
		return

	if clear_existing_on_spawn:
		_clear_spawned_agents(creature_root)

	_rng.randomize()
	_shared_home_position = _offset_to_world(habitat_center_offset)
	_spawned_world_positions.clear()
	_spawn_sample_index = 0
	_spawn_sample_offset = Vector3(_rng.randf(), _rng.randf(), _rng.randf())
	_spawn_hushlings(creature_root)
	_spawn_crawlers(creature_root)


func _clear_spawned_agents(creature_root: Node3D) -> void:
	for child in creature_root.get_children():
		if child is Node and child.is_in_group(spawned_group):
			child.queue_free()


func _spawn_hushlings(creature_root: Node3D) -> void:
	if hushling_scene == null:
		push_warning("XRAgentSpawner has no Hushling scene assigned")
		return

	var count: int = max(0, hushling_count) if randomize_spawn_positions else hushling_offsets.size()
	for index in range(count):
		var hushling := hushling_scene.instantiate() as Node3D
		if hushling == null:
			continue

		hushling.name = "HushlingAgent%d" % (index + 1)
		hushling.add_to_group(spawned_group)
		hushling.scale = Vector3.ONE * _sample_hushling_scale()
		hushling.position = creature_root.to_local(_get_hushling_spawn_position(index))
		_configure_hushling_before_ready(hushling, index)
		hushling.ready.connect(Callable(self, "_configure_hushling_after_ready").bind(hushling), CONNECT_ONE_SHOT)
		creature_root.add_child(hushling)


func _spawn_crawlers(creature_root: Node3D) -> void:
	if crawler_scene == null:
		push_warning("XRAgentSpawner has no Crawler scene assigned")
		return

	var count: int = crawler_count if randomize_spawn_positions else _fixed_crawler_count()
	for index in range(count):
		var crawler := crawler_scene.instantiate() as Node3D
		if crawler == null:
			continue

		crawler.name = "CrawlerAgent%d" % (index + 1)
		crawler.add_to_group(spawned_group)
		crawler.scale = Vector3.ONE * crawler_scale
		crawler.position = creature_root.to_local(_get_crawler_spawn_position(index))
		_apply_agent_debug_enabled(crawler)
		crawler.ready.connect(Callable(self, "_configure_crawler_after_ready").bind(crawler), CONNECT_ONE_SHOT)
		creature_root.add_child(crawler)


func _configure_hushling_before_ready(hushling: Node3D, index: int) -> void:
	var is_bold := index % 2 == 1
	_set_if_property(hushling, &"profile", bold_profile if is_bold else timid_profile)
	_set_if_property(hushling, &"visual_variant", "Bold" if is_bold else "Timid")
	_set_if_property(hushling, &"agent_debug_enabled", agent_debug_enabled)


func _configure_hushling_after_ready(hushling: Node3D) -> void:
	if not is_instance_valid(hushling):
		return

	if apply_compact_xr_tuning:
		_set_if_property(hushling, &"awareness_radius", xr_awareness_radius)
		_set_if_property(hushling, &"observe_distance", xr_observe_distance)
		_set_if_property(hushling, &"interest_flee_radius", xr_interest_flee_radius)
		_set_if_property(hushling, &"flee_safe_radius", xr_flee_safe_radius)
		_set_if_property(hushling, &"regroup_radius", xr_regroup_radius)
		_set_if_property(hushling, &"home_radius", xr_hushling_home_radius)

	if use_shared_home_bounds:
		_apply_shared_home_bounds(hushling)
	else:
		_set_if_property(hushling, &"use_home_bounds", false)
		_set_if_property(hushling, &"home_position", hushling.global_position)


func _configure_crawler_after_ready(crawler: Node3D) -> void:
	if not is_instance_valid(crawler):
		return

	_apply_agent_debug_enabled(crawler)

	if apply_compact_xr_tuning:
		_set_if_property(crawler, &"home_radius", xr_crawler_home_radius)
		_set_if_property(crawler, &"max_speed", xr_crawler_max_speed)
		_set_if_property(crawler, &"max_force", xr_crawler_max_force)

	if use_shared_home_bounds:
		_apply_shared_home_bounds(crawler)
	else:
		_set_if_property(crawler, &"use_home_bounds", false)
		_set_if_property(crawler, &"home_position", crawler.global_position)


func _apply_agent_debug_enabled(agent: Node) -> void:
	_set_if_property(agent, &"agent_debug_enabled", agent_debug_enabled)

	var debug_draw := agent.get_node_or_null("AgentDebugDraw")
	if debug_draw:
		debug_draw.set(&"debug_enabled", agent_debug_enabled)


func _apply_shared_home_bounds(agent: Node) -> void:
	_set_if_property(agent, &"use_home_bounds", true)
	_set_if_property(agent, &"home_bounds_size", habitat_bounds_size)
	_set_if_property(agent, &"home_tether_strength", xr_habitat_tether_strength)
	_set_if_property(agent, &"home_position", _shared_home_position)


func _update_spawned_home_bounds() -> void:
	var creature_root := get_node_or_null(creature_root_path) as Node3D
	if creature_root == null:
		return

	for child in creature_root.get_children():
		if child is Node and child.is_in_group(spawned_group):
			_apply_shared_home_bounds(child)


func _get_hushling_spawn_position(index: int) -> Vector3:
	if randomize_spawn_positions:
		return _sample_spawn_position()

	return _offset_to_world(hushling_offsets[index])


func _get_crawler_spawn_position(index: int) -> Vector3:
	if randomize_spawn_positions:
		return _sample_spawn_position()

	if crawler_offsets.is_empty():
		return _offset_to_world(crawler_offset)

	return _offset_to_world(crawler_offsets[index % crawler_offsets.size()])


func _fixed_crawler_count() -> int:
	if crawler_offsets.is_empty():
		return 1

	return crawler_offsets.size()


func _sample_hushling_scale() -> float:
	if not use_hushling_scale_variants:
		return hushling_scale

	var small_chance: float = clamp(small_hushling_chance, 0.0, 1.0)
	var medium_chance: float = clamp(medium_hushling_chance, 0.0, 1.0 - small_chance)
	var roll: float = _rng.randf()
	if roll < small_chance:
		return small_hushling_scale
	if roll < small_chance + medium_chance:
		return medium_hushling_scale
	return large_hushling_scale


func _sample_spawn_position() -> Vector3:
	var half_extents: Vector3 = habitat_bounds_size * 0.5
	if half_extents.x <= 0.001 or half_extents.y <= 0.001 or half_extents.z <= 0.001:
		return _shared_home_position

	var best_position: Vector3 = _shared_home_position
	var best_score: float = -INF
	for attempt in range(96):
		var local_offset := _sample_even_local_offset(_spawn_sample_index, half_extents)
		_spawn_sample_index += 1
		var world_position: Vector3 = _offset_to_world(habitat_center_offset + local_offset)
		if _is_valid_spawn_position(world_position):
			_spawned_world_positions.append(world_position)
			return world_position

		var score: float = _score_spawn_position(world_position)
		if score > best_score:
			best_score = score
			best_position = world_position

	_spawned_world_positions.append(best_position)
	return best_position


func _sample_even_local_offset(sample_index: int, half_extents: Vector3) -> Vector3:
	var x: float = _wrapped_halton(sample_index, 2, _spawn_sample_offset.x)
	var y: float = _wrapped_halton(sample_index, 3, _spawn_sample_offset.y)
	var z: float = _wrapped_halton(sample_index, 5, _spawn_sample_offset.z)
	return Vector3(
		(x * 2.0 - 1.0) * half_extents.x,
		(y * 2.0 - 1.0) * half_extents.y,
		(z * 2.0 - 1.0) * half_extents.z
	)


func _wrapped_halton(index: int, base: int, offset: float) -> float:
	return fposmod(_halton(index + 1, base) + offset, 1.0)


func _halton(index: int, base: int) -> float:
	var result: float = 0.0
	var fraction: float = 1.0 / float(base)
	var value: int = index
	while value > 0:
		result += float(value % base) * fraction
		value = int(value / base)
		fraction /= float(base)
	return result


func _score_spawn_position(world_position: Vector3) -> float:
	var score: float = INF
	if min_player_spawn_distance > 0.0:
		var player_position := _get_anchor_position()
		var horizontal_distance := Vector2(
			world_position.x - player_position.x,
			world_position.z - player_position.z
		).length()
		score = minf(score, horizontal_distance - min_player_spawn_distance)

	if min_agent_spawn_distance > 0.0:
		for other_position in _spawned_world_positions:
			score = minf(score, world_position.distance_to(other_position) - min_agent_spawn_distance)

	return score


func _is_valid_spawn_position(world_position: Vector3) -> bool:
	if min_player_spawn_distance > 0.0:
		var player_position := _get_anchor_position()
		var horizontal_distance := Vector2(
			world_position.x - player_position.x,
			world_position.z - player_position.z
		).length()
		if horizontal_distance < min_player_spawn_distance:
			return false

	if min_agent_spawn_distance > 0.0:
		for other_position in _spawned_world_positions:
			if world_position.distance_to(other_position) < min_agent_spawn_distance:
				return false

	return true


func _offset_to_world(offset: Vector3) -> Vector3:
	var anchor := get_node_or_null(camera_path) as Node3D
	if anchor == null:
		return global_transform * offset

	var forward := -anchor.global_transform.basis.z
	forward.y = 0.0
	forward = _safe_direction(forward, Vector3.FORWARD)

	var right := _safe_direction(forward.cross(Vector3.UP), Vector3.RIGHT)
	var basis := Basis(right, Vector3.UP, -forward)
	return Transform3D(basis, anchor.global_position) * offset


func _get_anchor_position() -> Vector3:
	var anchor := get_node_or_null(camera_path) as Node3D
	if anchor == null:
		return global_position

	return anchor.global_position


func _set_if_property(target: Object, property_name: StringName, value: Variant) -> void:
	if target == null:
		return

	for property in target.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			target.set(property_name, value)
			return


func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		return fallback.normalized()
	return value.normalized()
