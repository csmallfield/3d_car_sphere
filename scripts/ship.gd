extends RigidBody3D

# Where to place the car mesh relative to the sphere
var sphere_offset = Vector3.DOWN
# Engine power
var acceleration = 35.0
# Turn amount, in degrees
var steering = 19.0
# How quickly the car turns
var turn_speed = 4.0
# Below this speed, the car doesn't turn
var turn_stop_limit = 0.75

# Variables for input values
var speed_input = 0
var turn_input = 0
var body_tilt = 35

@export var hover_height = 1

@onready var ship_mesh: Node3D = $shipTest
@onready var body_mesh: Node3D = $shipTest/ship01  # ← Verify this path!
@onready var ground_ray: RayCast3D = $shipTest/RayCast3D


func _ready():
	body_mesh.position.y = hover_height

func _physics_process(delta):
	ship_mesh.position = position + sphere_offset
	if ground_ray.is_colliding():
		apply_central_force(-ship_mesh.global_transform.basis.z * speed_input)

func _process(delta):
	if not ground_ray.is_colliding():
		return
	speed_input = Input.get_axis("brake", "accelerate") * acceleration
	turn_input = Input.get_axis("steer_right", "steer_left") * deg_to_rad(steering)
	
	# rotate ship mesh
	if linear_velocity.length() > turn_stop_limit:
		var new_basis = ship_mesh.global_transform.basis.rotated(ship_mesh.global_transform.basis.y, turn_input)
		ship_mesh.global_transform.basis = ship_mesh.global_transform.basis.slerp(new_basis, turn_speed * delta)
		ship_mesh.global_transform = ship_mesh.global_transform.orthonormalized()
		var t = -turn_input * linear_velocity.length() / body_tilt
		body_mesh.rotation.z = lerp(body_mesh.rotation.z, t, 5.0 * delta)
		
		# Ground alignment must be INSIDE the velocity check
		if ground_ray.is_colliding():
			var n = ground_ray.get_collision_normal()
			var xform = align_with_y(ship_mesh.global_transform, n)
			ship_mesh.global_transform = ship_mesh.global_transform.interpolate_with(xform, 10.0 * delta)
		
func align_with_y(xform, new_y):
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform.orthonormalized()
