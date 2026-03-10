extends Node3D

var xr_interface: XRInterface
@onready var world_environment: WorldEnvironment = $WorldEnvironment

func _ready() -> void:
	xr_interface = XRServer.primary_interface

	if not xr_interface or not xr_interface.is_initialized():
		push_error("OpenXR not initialized")
		return

	print("OpenXR initialised successfully")

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.physics_ticks_per_second = 90
	get_viewport().use_xr = true

	if world_environment.environment == null:
		world_environment.environment = Environment.new()

	get_viewport().transparent_bg = true
	world_environment.environment.background_mode = Environment.BG_COLOR
	world_environment.environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR

	if not _enable_passthrough():
		push_error("Passthrough could not be enabled")

func _enable_passthrough() -> bool:
	if xr_interface and xr_interface.is_passthrough_supported():
		return xr_interface.start_passthrough()

	var modes = xr_interface.get_supported_environment_blend_modes()
	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
		xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
		return true

	return false
