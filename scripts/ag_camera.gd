extends Camera3D
class_name AGCamera

## Wipeout-style chase camera with dynamic FOV and smooth tracking

@export_group("Target")
@export var target: Node3D
@export var ship: AGShip  # Reference to get speed data

@export_group("Position")
@export var base_distance := 8.0        # Distance behind ship
@export var base_height := 3.0          # Height above ship
@export var look_ahead := 2.0           # How far ahead of ship to look

@export_group("Smoothing")
@export var position_smooth := 6.0      # Position lerp speed
@export var rotation_smooth := 8.0      # Rotation lerp speed
@export var height_smooth := 4.0        # Vertical position smoothing

@export_group("Speed Effects")
@export var speed_distance_add := 3.0   # Extra distance at max speed
@export var speed_height_add := 1.0     # Extra height at max speed
@export var base_fov := 65.0            # FOV at rest
@export var max_fov := 85.0             # FOV at max speed

@export_group("Shake")
@export var shake_amount := 0.1         # Camera shake intensity
@export var shake_speed := 25.0         # Shake frequency

# Internal state
var target_position := Vector3.ZERO
var current_offset := Vector3.ZERO
var shake_time := 0.0
var smoothed_target_pos := Vector3.ZERO  # Smoothed tracking position

func _ready() -> void:
	# Try to auto-find ship if not set
	if not ship and target:
		var parent = target.get_parent()
		if parent is AGShip:
			ship = parent
	
	# Initialize smoothed position
	if target:
		smoothed_target_pos = target.global_position

func _physics_process(delta: float) -> void:
	if not target:
		return
	
	# Smooth the target position to reduce wobble
	smoothed_target_pos = smoothed_target_pos.lerp(target.global_position, 10.0 * delta)
	
	var speed_factor := 0.0
	if ship:
		speed_factor = clamp(abs(ship.current_speed) / ship.max_speed, 0.0, 1.0)
	
	# Calculate dynamic offsets based on speed
	var dynamic_distance = base_distance + (speed_distance_add * speed_factor)
	var dynamic_height = base_height + (speed_height_add * speed_factor)
	
	# Get target's forward direction (use ship basis, not mesh)
	var target_forward := -Vector3.FORWARD
	if ship:
		target_forward = -ship.global_transform.basis.z
	elif target:
		target_forward = -target.global_transform.basis.z
	
	# Flatten forward vector for more stable camera
	target_forward.y = 0
	target_forward = target_forward.normalized()
	
	# Calculate ideal camera position (behind and above target)
	var ideal_pos = smoothed_target_pos
	ideal_pos += target_forward * -dynamic_distance  # Behind
	ideal_pos += Vector3.UP * dynamic_height  # Above (use world up for stability)
	
	# Smooth position (horizontal faster than vertical for stability)
	var current_pos = global_position
	var new_pos = Vector3.ZERO
	new_pos.x = lerp(current_pos.x, ideal_pos.x, position_smooth * delta)
	new_pos.z = lerp(current_pos.z, ideal_pos.z, position_smooth * delta)
	new_pos.y = lerp(current_pos.y, ideal_pos.y, height_smooth * delta)
	
	# Add camera shake based on speed
	shake_time += delta * shake_speed
	var shake = Vector3.ZERO
	if speed_factor > 0.5:
		var shake_intensity = (speed_factor - 0.5) * 2.0 * shake_amount
		shake.x = sin(shake_time * 1.1) * shake_intensity
		shake.y = sin(shake_time * 0.9) * shake_intensity * 0.5
	
	global_position = new_pos + shake
	
	# Look at smoothed point ahead of ship
	var look_target = smoothed_target_pos + target_forward * look_ahead
	
	# Smooth look rotation
	var current_rot = global_transform
	var target_look = global_transform.looking_at(look_target, Vector3.UP)
	global_transform = current_rot.interpolate_with(target_look, rotation_smooth * delta)
	
	# Dynamic FOV
	fov = lerp(base_fov, max_fov, speed_factor * speed_factor)  # Quadratic for more impact at high speed
