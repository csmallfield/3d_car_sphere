extends Camera3D

@export var lerp_speed = 3.0
@export var offset = Vector3.ZERO
@export var target : Node
@export var max_distance = 13.0  # Add this - maximum allowed distance from ship

func _physics_process(delta):
	if !target:
		return
	var target_pos = target.global_transform.translated_local(offset)
	global_transform = global_transform.interpolate_with(target_pos, lerp_speed * delta)
	
	# Clamp the camera distance
	var distance = global_position.distance_to(target.global_position)
	if distance > max_distance:
		var direction = (target.global_position - global_position).normalized()
		global_position = target.global_position - direction * max_distance
	
	look_at(target.global_position, Vector3.UP)
