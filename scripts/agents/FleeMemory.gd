extends RefCounted
class_name FleeMemory

var target: Node3D
var time_remaining: float = 0.0


func trigger(source: Node3D, duration: float) -> void:
	target = source
	time_remaining = max(duration, 0.0)


func clear() -> void:
	target = null
	time_remaining = 0.0


func update(delta: float, owner_position: Vector3, clear_distance: float) -> void:
	if time_remaining <= 0.0:
		clear()
		return

	time_remaining = max(time_remaining - delta, 0.0)
	if is_instance_valid(target) and owner_position.distance_to(target.global_position) >= clear_distance:
		time_remaining = 0.0
	if time_remaining <= 0.0:
		clear()


func is_active() -> bool:
	return time_remaining > 0.0 and is_instance_valid(target)
