extends Node3D
class_name AgentAudioEmitter

const MIN_VOLUME_DB := -80.0

@export_group("Target")
@export var target_path: NodePath
@export_enum("Auto", "Hushling", "Crawler") var agent_kind: String = "Auto"
@export var audio_enabled: bool = true

@export_group("Streams")
@export var movement_loop_stream: AudioStream
@export var group_murmur_stream: AudioStream
@export var flee_stream: AudioStream
@export var startled_stream: AudioStream

@export_group("3D Range")
@export_range(0.05, 6.0, 0.01) var max_hear_distance: float = 1.15
@export_range(0.01, 2.0, 0.01) var unit_size: float = 0.28
@export var audio_bus: StringName = &"Master"

@export_group("Movement Loop")
@export_range(-80.0, 12.0, 0.1) var movement_volume_db: float = -24.0
@export_range(-80.0, 12.0, 0.1) var idle_volume_db: float = -34.0
@export_range(0.1, 3.0, 0.01) var movement_pitch_scale: float = 1.0
@export_range(0.1, 3.0, 0.01) var idle_pitch_scale: float = 0.72
@export_range(0.0, 1.0, 0.01) var movement_speed_volume_influence: float = 0.45

@export_group("Group Murmur")
@export_range(2, 12, 1) var group_murmur_min_group_size: int = 3
@export_range(-80.0, 12.0, 0.1) var group_murmur_volume_db: float = -29.0
@export_range(0.1, 3.0, 0.01) var group_murmur_pitch_scale: float = 0.92
@export_range(1.0, 40.0, 0.1) var group_murmur_release_speed: float = 18.0

@export_group("One Shots")
@export_range(-80.0, 12.0, 0.1) var flee_volume_db: float = -18.0
@export_range(0.1, 3.0, 0.01) var flee_pitch_scale: float = 1.0
@export_range(0.0, 2.0, 0.01) var one_shot_cooldown: float = 0.18

@export_group("Variation")
@export_range(0.0, 0.4, 0.01) var pitch_variation: float = 0.08
@export_range(1.0, 24.0, 0.1) var volume_fade_speed: float = 8.0

@export_group("Performance")
@export_range(0.0, 0.5, 0.01) var audio_update_interval: float = 0.08

var _target: Node
var _property_names: Dictionary = {}
var _movement_player: AudioStreamPlayer3D
var _group_player: AudioStreamPlayer3D
var _flee_player: AudioStreamPlayer3D
var _last_state: String = ""
var _one_shot_cooldown_remaining: float = 0.0
var _pitch_variation_scale: float = 1.0
var _audio_update_accumulator: float = 0.0


func _ready() -> void:
	_resolve_target()
	_pitch_variation_scale = _make_pitch_variation()
	_movement_player = _create_player("MovementLoop", movement_loop_stream, true)
	_group_player = _create_player("GroupMurmur", group_murmur_stream, true)
	_flee_player = _create_player("FleeOneShot", null, false)


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_resolve_target()
	if _target == null:
		return

	var audio_delta: float = _consume_audio_delta(delta)
	if audio_delta <= 0.0:
		return

	_one_shot_cooldown_remaining = maxf(0.0, _one_shot_cooldown_remaining - audio_delta)
	var state: String = _read_string(&"current_state", "WANDER")
	var kind: String = _resolved_agent_kind()

	_update_movement_loop(state, audio_delta)
	_update_group_murmur(kind, state, audio_delta)
	_update_one_shots(state)
	_last_state = state


func _create_player(player_name: String, stream_value: AudioStream, loop_player: bool) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = player_name
	player.stream = stream_value
	player.volume_db = MIN_VOLUME_DB
	player.bus = audio_bus
	player.unit_size = unit_size
	player.max_distance = max_hear_distance
	player.autoplay = false
	add_child(player)
	if loop_player and audio_enabled and stream_value != null:
		player.play()
	return player


func _consume_audio_delta(delta: float) -> float:
	if audio_update_interval <= 0.0:
		return delta

	_audio_update_accumulator += delta
	if _audio_update_accumulator < audio_update_interval:
		return 0.0

	var consumed: float = min(_audio_update_accumulator, audio_update_interval * 2.0)
	_audio_update_accumulator = 0.0
	return consumed


func _update_movement_loop(state: String, delta: float) -> void:
	if _movement_player.stream != movement_loop_stream:
		_movement_player.stream = movement_loop_stream

	var target_volume: float = MIN_VOLUME_DB
	var target_pitch: float = movement_pitch_scale
	if audio_enabled and movement_loop_stream != null:
		if state == "IDLE":
			target_volume = idle_volume_db
			target_pitch = idle_pitch_scale
		elif state == "FLEE" or state == "STARTLED":
			target_volume = idle_volume_db - 6.0
			target_pitch = movement_pitch_scale * 1.08
		else:
			target_volume = movement_volume_db + _speed_factor() * movement_speed_volume_influence * 8.0
			target_pitch = movement_pitch_scale

	_ensure_looping(_movement_player, target_volume)
	_movement_player.pitch_scale = target_pitch * _pitch_variation_scale
	_fade_player(_movement_player, target_volume, delta)


func _update_group_murmur(kind: String, state: String, delta: float) -> void:
	if _group_player.stream != group_murmur_stream:
		_group_player.stream = group_murmur_stream

	var target_volume: float = MIN_VOLUME_DB
	var group_audio_active: bool = (
		audio_enabled
		and kind == "Hushling"
		and group_murmur_stream != null
		and state != "FLEE"
		and state != "STARTLED"
	)
	if group_audio_active:
		var group_size: int = _read_int(&"debug_neighbour_count", 0) + 1
		if group_size >= group_murmur_min_group_size:
			var confidence: float = _read_float(&"confidence", 0.0)
			var group_factor: float = clamp(
				float(group_size - group_murmur_min_group_size + 1) / 4.0,
				0.0,
				1.0
			)
			target_volume = group_murmur_volume_db + maxf(group_factor, confidence) * 5.0

	var fade_speed: float = volume_fade_speed if target_volume > MIN_VOLUME_DB + 0.1 else group_murmur_release_speed
	_ensure_looping(_group_player, target_volume)
	_group_player.pitch_scale = group_murmur_pitch_scale * _pitch_variation_scale
	_fade_player(_group_player, target_volume, delta, fade_speed)


func _update_one_shots(state: String) -> void:
	if not audio_enabled or state == _last_state or _one_shot_cooldown_remaining > 0.0:
		return

	if state == "STARTLED" and startled_stream != null:
		_play_one_shot(startled_stream, flee_volume_db, flee_pitch_scale * 1.08)
	elif state == "FLEE" and flee_stream != null:
		_play_one_shot(flee_stream, flee_volume_db, flee_pitch_scale)


func _play_one_shot(stream_value: AudioStream, volume: float, pitch: float) -> void:
	_flee_player.stop()
	_flee_player.stream = stream_value
	_flee_player.volume_db = volume
	_flee_player.pitch_scale = pitch * _pitch_variation_scale
	_flee_player.bus = audio_bus
	_flee_player.unit_size = unit_size
	_flee_player.max_distance = max_hear_distance
	_flee_player.play()
	_one_shot_cooldown_remaining = one_shot_cooldown


func _ensure_looping(player: AudioStreamPlayer3D, target_volume: float) -> void:
	if target_volume <= MIN_VOLUME_DB + 0.1:
		return
	if player.stream != null and not player.playing:
		player.play()


func _fade_player(
	player: AudioStreamPlayer3D,
	target_volume: float,
	delta: float,
	fade_speed: float = -1.0
) -> void:
	var active_fade_speed: float = volume_fade_speed if fade_speed < 0.0 else fade_speed
	var alpha: float = 1.0 - exp(-active_fade_speed * delta)
	player.volume_db = lerpf(player.volume_db, target_volume, alpha)
	if player.volume_db <= MIN_VOLUME_DB + 0.5 and player.playing:
		player.stop()


func _speed_factor() -> float:
	var velocity: Vector3 = _read_vector(&"velocity", Vector3.ZERO)
	var max_speed: float = maxf(_read_float(&"max_speed", 0.4), 0.001)
	return clamp(velocity.length() / max_speed, 0.0, 1.0)


func _resolved_agent_kind() -> String:
	if agent_kind != "Auto":
		return agent_kind
	if _target != null and _target.is_in_group(&"hushling"):
		return "Hushling"
	if _target != null and _target.is_in_group(&"interest_entity"):
		return "Crawler"
	return "Agent"


func _resolve_target() -> void:
	_target = null
	if target_path != NodePath():
		_target = get_node_or_null(target_path)
	if _target == null:
		_target = get_parent()

	_property_names.clear()
	if _target != null:
		for property in _target.get_property_list():
			_property_names[StringName(property.get("name", ""))] = true


func _has_property(property_name: StringName) -> bool:
	return _property_names.has(property_name)


func _read_string(property_name: StringName, fallback: String) -> String:
	if _target == null or not _has_property(property_name):
		return fallback
	return str(_target.get(property_name))


func _read_int(property_name: StringName, fallback: int) -> int:
	if _target == null or not _has_property(property_name):
		return fallback
	return int(_target.get(property_name))


func _read_float(property_name: StringName, fallback: float) -> float:
	if _target == null or not _has_property(property_name):
		return fallback
	return float(_target.get(property_name))


func _read_vector(property_name: StringName, fallback: Vector3) -> Vector3:
	if _target == null or not _has_property(property_name):
		return fallback
	var value: Variant = _target.get(property_name)
	return value if value is Vector3 else fallback


func _make_pitch_variation() -> float:
	if pitch_variation <= 0.0:
		return 1.0

	var seed_value: int = abs(hash("%s:%s" % [name, str(get_instance_id())])) % 1000
	var t: float = float(seed_value) / 999.0
	return 1.0 + lerpf(-pitch_variation, pitch_variation, t)
