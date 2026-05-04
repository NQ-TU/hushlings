extends Node3D
class_name PlayerInfluence

@export_group("Player Influence")
@export var is_observable_source: bool = true
@export var is_gaze_source: bool = true
@export_storage var is_hand_source: bool = false
@export_range(0.1, 10.0, 0.01) var gaze_range: float = 2.6
@export_range(1.0, 45.0, 0.5) var dead_center_gaze_degrees: float = 8.0


func _ready() -> void:
	if not is_in_group(&"player"):
		add_to_group(&"player")
	if is_hand_source and not is_in_group(&"player_hand"):
		add_to_group(&"player_hand")


func get_forward_direction() -> Vector3:
	return (-global_transform.basis.z).normalized()
