extends CharacterBody3D
class_name AGShip

## Anti-Gravity Ship Controller
## Designed to replicate the feel of Wipeout XL

# ============================================================================
# TUNING PARAMETERS
# ============================================================================

@export_group("Speed")
@export var max_speed := 80.0          # Top speed in units/sec
@export var acceleration := 25.0        # How quickly we reach max speed
@export var braking := 25.0             # Deceleration when braking
@export var drag := 0.3                 # Natural speed decay (air resistance)
@export var reverse_speed := 20.0       # Max reverse speed

@export_group("Steering")
@export var turn_rate := 1.8            # Base turning speed (radians/sec)
@export var turn_speed_falloff := 0.4   # How much speed reduces turn rate (0-1)
@export var grip := 0.92                # How much velocity follows facing (0-1)
@export var min_turn_speed := 5.0       # Minimum speed to allow turning

@export_group("Airbrakes")
@export var airbrake_turn_boost := 1.2  # Multiplier to turn rate when airbraking
@export var airbrake_drag := 0.985      # Speed multiplier per frame when airbraking
@export var airbrake_grip := 0.96       # Increased grip when airbraking

@export_group("Hover System")
@export var hover_height := 2.0         # Target height above ground
@export var hover_response := 0.25      # How rigidly we maintain height (0-1, higher = more locked)
@export var ground_conform_speed := 2.0 # How fast we align to ground normal (very slow for stability)
@export var max_ground_angle := 60.0    # Max slope we can hover over (degrees)

@export_group("Physics")
@export var gravity := 35.0             # Downward force when not grounded
@export var fall_gravity := 50.0        # Stronger gravity when falling
@export var mass := 1.0                 # Affects collision response
@export var wall_bounce := 0.7          # How much we bounce off walls (increased)
@export var wall_friction := 0.95       # Speed loss on wall contact (less aggressive)

@export_group("Visual Feedback")
@export var max_pitch := 15.0           # Degrees of pitch on accel/brake
@export var max_roll := 35.0            # Degrees of roll on turns
@export var visual_smooth := 8.0        # How smoothly visuals follow physics

@export_group("Engine Effects")
@export var engine_color := Color(0.2, 0.5, 1.0, 1.0)  # Engine glow color
@export var engine_intensity_idle := 0.5
@export var engine_intensity_thrust := 2.0

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var ship_mesh: Node3D = $ShipMesh
@onready var ray_center: RayCast3D = $Raycasts/Center
@onready var ray_front: RayCast3D = $Raycasts/Front
@onready var ray_back: RayCast3D = $Raycasts/Back
@onready var ray_left: RayCast3D = $Raycasts/Left
@onready var ray_right: RayCast3D = $Raycasts/Right

# Engine lights (created in code)
var engine_light_left: OmniLight3D
var engine_light_right: OmniLight3D

# ============================================================================
# STATE VARIABLES
# ============================================================================

var current_speed := 0.0                # Forward speed (can be negative)
var vertical_velocity := 0.0            # For when airborne
var ground_normal := Vector3.UP         # Averaged ground normal
var is_grounded := false                # Are we hovering over valid ground?
var current_height := 0.0               # Actual height above ground

# Input state
var throttle_input := 0.0               # -1 (brake) to 1 (accelerate)
var steer_input := 0.0                  # -1 (right) to 1 (left)
var airbrake_left := false
var airbrake_right := false

# Visual state
var visual_pitch := 0.0
var visual_roll := 0.0
var visual_hover_bob := 0.0

# Wall scraping state
var is_scraping_wall := false
var last_wall_normal := Vector3.ZERO

# Smoothed ground detection (anti-wobble)
var smoothed_ground_normal := Vector3.UP
var smoothed_height := 2.0
var smoothed_ground_point := Vector3.ZERO  # Track the actual ground position

# ============================================================================
# MAIN LOOPS
# ============================================================================

func _ready() -> void:
	# Ensure raycasts are set up correctly
	_setup_raycasts()
	# Create engine glow lights
	_setup_engine_lights()
	# Initialize ground tracking to current position
	smoothed_ground_point = global_position - Vector3(0, hover_height, 0)
	smoothed_height = hover_height

func _setup_engine_lights() -> void:
	# Left engine light
	engine_light_left = OmniLight3D.new()
	engine_light_left.light_color = engine_color
	engine_light_left.light_energy = engine_intensity_idle
	engine_light_left.omni_range = 3.0
	engine_light_left.omni_attenuation = 1.5
	engine_light_left.position = Vector3(-0.8, 0, 1.5)
	add_child(engine_light_left)
	
	# Right engine light  
	engine_light_right = OmniLight3D.new()
	engine_light_right.light_color = engine_color
	engine_light_right.light_energy = engine_intensity_idle
	engine_light_right.omni_range = 3.0
	engine_light_right.omni_attenuation = 1.5
	engine_light_right.position = Vector3(0.8, 0, 1.5)
	add_child(engine_light_right)

func _physics_process(delta: float) -> void:
	_read_input()
	_update_ground_detection()
	_update_hover_physics(delta)
	_update_movement(delta)
	_update_visuals(delta)
	_update_engine_effects(delta)
	
	move_and_slide()
	
	# Handle wall collisions after move_and_slide
	_handle_wall_collisions()

# ============================================================================
# INPUT
# ============================================================================

func _read_input() -> void:
	throttle_input = Input.get_axis("brake", "accelerate")
	steer_input = Input.get_axis("steer_right", "steer_left")
	airbrake_left = Input.is_action_pressed("airbrake_left")
	airbrake_right = Input.is_action_pressed("airbrake_right")

# ============================================================================
# GROUND DETECTION
# ============================================================================

func _setup_raycasts() -> void:
	# Configure raycast lengths based on hover height
	var ray_length = hover_height * 3.0
	for ray in [ray_center, ray_front, ray_back, ray_left, ray_right]:
		if ray:
			ray.target_position = Vector3.DOWN * ray_length

func _update_ground_detection() -> void:
	var total_normal := Vector3.ZERO
	var total_point := Vector3.ZERO
	var total_distance := 0.0
	var hit_count := 0
	
	for ray in [ray_center, ray_front, ray_back, ray_left, ray_right]:
		if ray and ray.is_colliding():
			var hit_point = ray.get_collision_point()
			var hit_normal = ray.get_collision_normal()
			var distance = ray.global_position.distance_to(hit_point)
			
			# Check if slope is traversable
			var slope_angle = rad_to_deg(acos(hit_normal.dot(Vector3.UP)))
			if slope_angle <= max_ground_angle:
				total_normal += hit_normal
				total_point += hit_point
				total_distance += distance
				hit_count += 1
	
	if hit_count > 0:
		is_grounded = true
		var raw_normal = total_normal.normalized()
		var raw_height = total_distance / hit_count
		var raw_ground_point = total_point / hit_count
		
		# HEAVILY smooth everything to eliminate wobble
		# These low values (0.05-0.08) mean changes happen gradually over ~20 frames
		smoothed_ground_normal = smoothed_ground_normal.slerp(raw_normal, 0.05)
		smoothed_height = lerp(smoothed_height, raw_height, 0.08)
		smoothed_ground_point = smoothed_ground_point.lerp(raw_ground_point, 0.08)
		
		ground_normal = smoothed_ground_normal
		current_height = smoothed_height
	else:
		is_grounded = false
		ground_normal = ground_normal.slerp(Vector3.UP, 0.02)
		current_height = hover_height * 3.0

# ============================================================================
# HOVER PHYSICS
# ============================================================================

func _update_hover_physics(delta: float) -> void:
	if is_grounded:
		# LOCKED HOVER: Directly lerp to target height instead of spring-damper
		# This eliminates oscillation entirely
		var target_y = smoothed_ground_point.y + hover_height
		var height_diff = target_y - global_position.y
		
		# Smoothly move toward target height
		vertical_velocity = height_diff * hover_response / delta
		
		# Clamp to prevent extreme corrections
		vertical_velocity = clamp(vertical_velocity, -30.0, 30.0)
	else:
		# Falling - apply gravity
		var grav = fall_gravity if vertical_velocity < 0 else gravity
		vertical_velocity -= grav * delta
	
	# Apply vertical movement
	velocity.y = vertical_velocity

# ============================================================================
# MOVEMENT
# ============================================================================

func _update_movement(delta: float) -> void:
	# Get our facing direction (projected onto ground plane)
	var forward = -global_transform.basis.z
	var right = global_transform.basis.x
	
	# Project forward onto ground plane for movement
	if is_grounded:
		forward = forward.slide(ground_normal).normalized()
		right = right.slide(ground_normal).normalized()
	
	# === ACCELERATION ===
	if throttle_input > 0:
		current_speed = move_toward(current_speed, max_speed, acceleration * throttle_input * delta)
	elif throttle_input < 0:
		if current_speed > 0:
			# Braking
			current_speed = move_toward(current_speed, 0, braking * abs(throttle_input) * delta)
		else:
			# Reversing
			current_speed = move_toward(current_speed, -reverse_speed, acceleration * 0.5 * abs(throttle_input) * delta)
	else:
		# Natural drag
		current_speed = move_toward(current_speed, 0, drag * abs(current_speed) * delta + 5.0 * delta)
	
	# === STEERING ===
	var speed_factor = clamp(abs(current_speed) / max_speed, 0.0, 1.0)
	var effective_turn_rate = turn_rate * (1.0 - speed_factor * turn_speed_falloff)
	
	# Airbrake handling
	var current_grip = grip
	var turn_multiplier = 1.0
	
	if airbrake_left or airbrake_right:
		turn_multiplier = airbrake_turn_boost
		current_grip = airbrake_grip
		current_speed *= airbrake_drag
		
		# Airbrakes also add turning force in their direction
		if airbrake_left:
			steer_input = max(steer_input, 0.5)  # Force left turn
		if airbrake_right:
			steer_input = min(steer_input, -0.5)  # Force right turn
	
	# Only turn if we're moving
	if abs(current_speed) > min_turn_speed:
		var turn_amount = steer_input * effective_turn_rate * turn_multiplier * delta
		# Reverse steering when going backwards
		if current_speed < 0:
			turn_amount = -turn_amount
		rotate_y(turn_amount)
	
	# === VELOCITY CALCULATION ===
	# Get horizontal velocity
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	
	# Target velocity based on facing direction
	var target_velocity = forward * current_speed
	
	# Blend current velocity toward target (this creates the drift/grip feel)
	horizontal_velocity = horizontal_velocity.lerp(target_velocity, current_grip)
	
	# Apply to velocity (preserving vertical component)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	
	# === GROUND ALIGNMENT ===
	if is_grounded:
		var current_up = global_transform.basis.y
		var target_up = ground_normal
		var new_up = current_up.slerp(target_up, ground_conform_speed * delta)
		
		# Reconstruct basis with new up vector
		var new_forward = -global_transform.basis.z
		var new_right = new_forward.cross(new_up).normalized()
		new_forward = new_up.cross(new_right).normalized()
		
		global_transform.basis = Basis(new_right, new_up, -new_forward)

# ============================================================================
# VISUALS
# ============================================================================

func _update_visuals(delta: float) -> void:
	if not ship_mesh:
		return
	
	# Calculate target pitch (nose up on accel, down on brake)
	var target_pitch = -throttle_input * deg_to_rad(max_pitch)
	
	# Calculate target roll (lean into turns)
	var effective_steer = steer_input
	if airbrake_left:
		effective_steer = max(effective_steer, 0.7)
	elif airbrake_right:
		effective_steer = min(effective_steer, -0.7)
	
	var speed_roll_factor = clamp(abs(current_speed) / max_speed, 0.3, 1.0)
	var target_roll = effective_steer * deg_to_rad(max_roll) * speed_roll_factor
	
	# Smooth the visual rotation
	visual_pitch = lerp(visual_pitch, target_pitch, visual_smooth * delta)
	visual_roll = lerp(visual_roll, target_roll, visual_smooth * delta)
	
	# Subtle hover bob
	visual_hover_bob += delta * 3.0
	var bob_offset = sin(visual_hover_bob) * 0.05
	
	# Apply to mesh (local rotation relative to ship body)
	ship_mesh.rotation.x = visual_pitch
	ship_mesh.rotation.z = visual_roll
	ship_mesh.position.y = bob_offset

# ============================================================================
# DEBUG
# ============================================================================

func _get_debug_info() -> String:
	return "Speed: %.1f / %.1f\nGrounded: %s\nHeight: %.2f\nVVel: %.2f" % [
		current_speed, max_speed, is_grounded, current_height, vertical_velocity
	]

# ============================================================================
# WALL COLLISIONS
# ============================================================================

func _handle_wall_collisions() -> void:
	is_scraping_wall = false
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()
		
		# Check if this is a wall (mostly horizontal normal)
		if abs(normal.y) < 0.5:
			is_scraping_wall = true
			last_wall_normal = normal
			
			# Calculate impact severity based on angle of approach
			# Grazing = low penalty, head-on = high penalty
			var velocity_dir = velocity.normalized()
			var impact_dot = -velocity_dir.dot(normal)  # 0 = parallel, 1 = head-on
			impact_dot = clamp(impact_dot, 0.0, 1.0)
			
			# Scale friction by impact angle
			# Grazing (dot ~0): almost no speed loss
			# Head-on (dot ~1): significant speed loss
			var effective_friction = lerp(0.99, wall_friction, impact_dot)
			current_speed *= effective_friction
			
			# Minimum speed to prevent sticking
			if abs(current_speed) < 8.0:
				current_speed = sign(current_speed) * 8.0 if current_speed != 0 else 8.0
			
			# Push away from wall - stronger for head-on impacts
			var push_strength = lerp(5.0, 20.0, impact_dot)
			velocity += normal * push_strength
			
			# Bounce/deflect velocity
			var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
			var reflected = horizontal_vel.bounce(normal)
			var bounce_amount = lerp(0.1, wall_bounce, impact_dot)
			velocity.x = lerp(velocity.x, reflected.x, bounce_amount)
			velocity.z = lerp(velocity.z, reflected.z, bounce_amount)

# ============================================================================
# ENGINE EFFECTS
# ============================================================================

func _update_engine_effects(delta: float) -> void:
	# Calculate target intensity based on throttle and speed
	var speed_factor = clamp(abs(current_speed) / max_speed, 0.0, 1.0)
	var target_intensity = engine_intensity_idle
	
	if throttle_input > 0:
		target_intensity = lerp(engine_intensity_idle, engine_intensity_thrust, throttle_input)
	
	# Add extra glow at high speed
	target_intensity += speed_factor * 0.5
	
	# Smooth the intensity change
	if engine_light_left:
		engine_light_left.light_energy = lerp(
			engine_light_left.light_energy, 
			target_intensity, 
			8.0 * delta
		)
	if engine_light_right:
		engine_light_right.light_energy = lerp(
			engine_light_right.light_energy, 
			target_intensity, 
			8.0 * delta
		)
	
	# Flash on wall scrape
	if is_scraping_wall:
		var flash = 1.0 + sin(Time.get_ticks_msec() * 0.05) * 0.5
		if engine_light_left:
			engine_light_left.light_energy *= flash
		if engine_light_right:
			engine_light_right.light_energy *= flash
