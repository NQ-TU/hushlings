extends Area3D
class_name XRDebugToggleZone

@export_group("Debug Toggle")
@export var debug_enabled: bool = false
@export var hand_group: StringName = &"right_player_hand"
@export_range(0.1, 2.0, 0.01) var toggle_cooldown: float = 0.65

@export_group("Wrist Activation")
@export var reference_path: NodePath
@export_range(-1.0, 1.0, 0.01) var minimum_height_above_reference: float = -0.08

@export_group("Indicator")
@export var off_color: Color = Color(0.18, 0.72, 0.95, 0.72)
@export var on_color: Color = Color(0.45, 1.0, 0.65, 0.9)

var _cooldown_remaining: float = 0.0
var _indicator_material: StandardMaterial3D
var _reference: Node3D
var _is_active: bool = true


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_reference = get_node_or_null(reference_path) as Node3D
	var indicator := get_node_or_null(^"Indicator") as MeshInstance3D
	if indicator:
		var material := indicator.material_override as StandardMaterial3D
		_indicator_material = material.duplicate() if material else StandardMaterial3D.new()
		indicator.material_override = _indicator_material
	call_deferred("_apply_debug_enabled")
	_update_activation()
	_update_indicator()


func _process(delta: float) -> void:
	_cooldown_remaining = max(_cooldown_remaining - delta, 0.0)
	_update_activation()


func set_debug_enabled(value: bool) -> void:
	debug_enabled = value
	_apply_debug_enabled()
	_update_indicator()


func _on_area_entered(area: Area3D) -> void:
	_try_toggle(area)


func _try_toggle(node: Node) -> void:
	if not _is_active or _cooldown_remaining > 0.0 or node == null or not node.is_in_group(hand_group):
		return

	_cooldown_remaining = toggle_cooldown
	set_debug_enabled(not debug_enabled)


func _apply_debug_enabled() -> void:
	for debug_draw in get_tree().get_nodes_in_group(&"agent_debug_draw"):
		debug_draw.set(&"debug_enabled", debug_enabled)


func _update_activation() -> void:
	var active := _reference == null \
			or not is_instance_valid(_reference) \
			or global_position.y >= _reference.global_position.y + minimum_height_above_reference
	if active == _is_active:
		return

	_is_active = active
	visible = _is_active
	monitoring = _is_active


func _update_indicator() -> void:
	if _indicator_material == null:
		return

	var color: Color = on_color if debug_enabled else off_color
	_indicator_material.albedo_color = color
	_indicator_material.emission = Color(color.r, color.g, color.b, 1.0)
	_indicator_material.emission_energy_multiplier = 0.9 if debug_enabled else 0.35
