extends Camera3D
class_name AGCamera2097

## WipEout 2097 Style Chase Camera

@export var ship: AGShip2097

@export_group("Position")
@export var base_offset := Vector3(0, 3.0, 8.0)  # Up and behind
@export var speed_zoom := 2.0                     # Extra distance at max speed
@export var follow_speed := 8.0                   # Position lerp speed

@export_group("Look")
@export var look_ahead := 0.1                     # Predict ahead based on velocity
@export var look_speed := 10.0                    # Rotation lerp speed

@export_group("Effects")
@export var base_fov := 65.0
@export var max_fov := 80.0

var shake_offset := Vector3.ZERO
var shake_intensity := 0.0

func _physics_process(delta: float) -> void:
	if not ship:
		return
	
	var speed_ratio = ship.get_speed_ratio()
	
	# Calculate camera offset with speed-based zoom
	var dynamic_offset = base_offset
	dynamic_offset.z += speed_zoom * speed_ratio
	
	# Transform offset to world space based on ship orientation
	# But use a smoothed/stable version of the ship's rotation
	var ship_basis = ship.global_transform.basis
	var target_pos = ship.global_position + ship_basis * dynamic_offset
	
	# Smooth follow
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	
	# Add shake
	global_position += shake_offset
	_update_shake(delta)
	
	# Look at ship with slight prediction
	var look_target = ship.global_position + ship.velocity * look_ahead
	
	# Smooth look
	var current_xform = global_transform
	var target_xform = current_xform.looking_at(look_target, Vector3.UP)
	global_transform = current_xform.interpolate_with(target_xform, look_speed * delta)
	
	# Dynamic FOV
	fov = lerp(base_fov, max_fov, speed_ratio)

func apply_shake(intensity: float) -> void:
	shake_intensity = max(shake_intensity, intensity)

func _update_shake(delta: float) -> void:
	if shake_intensity > 0.01:
		shake_offset = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			0
		) * shake_intensity
		shake_intensity *= 0.9  # Decay
	else:
		shake_offset = Vector3.ZERO
		shake_intensity = 0.0
