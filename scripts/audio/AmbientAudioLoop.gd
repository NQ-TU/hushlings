extends AudioStreamPlayer
class_name AmbientAudioLoop

@export var audio_enabled: bool = true
@export_range(-80.0, 12.0, 0.1) var target_volume_db: float = -28.0
@export_range(0.1, 12.0, 0.1) var fade_speed: float = 3.0


func _ready() -> void:
	autoplay = false
	volume_db = -80.0


func _process(delta: float) -> void:
	var target_volume: float = target_volume_db if audio_enabled and stream != null else -80.0
	volume_db = lerpf(volume_db, target_volume, 1.0 - exp(-fade_speed * delta))

	if not audio_enabled or stream == null:
		if playing and volume_db <= -79.0:
			stop()
		return

	if not playing:
		play()
