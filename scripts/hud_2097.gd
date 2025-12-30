extends CanvasLayer

## Debug HUD showing real-time ship telemetry

@export var ship: AGShip2097

@onready var debug_label: Label = $DebugLabel

func _ready() -> void:
	# Create the debug label if it doesn't exist
	if not has_node("DebugLabel"):
		debug_label = Label.new()
		debug_label.name = "DebugLabel"
		add_child(debug_label)
	
	# Style the debug label
	debug_label.position = Vector2(20, 20)
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_label.add_theme_constant_override("shadow_offset_x", 1)
	debug_label.add_theme_constant_override("shadow_offset_y", 1)

func _process(_delta: float) -> void:
	if not ship:
		debug_label.text = "NO SHIP ASSIGNED"
		return
	
	var lines: Array[String] = []
	
	# === SPEED ===
	var speed = ship.velocity.length()
	var speed_ratio = speed / ship.max_speed * 100.0
	lines.append("═══ SPEED ═══")
	lines.append("Speed: %.1f / %.1f (%.0f%%)" % [speed, ship.max_speed, speed_ratio])
	lines.append("Velocity: (%.1f, %.1f, %.1f)" % [ship.velocity.x, ship.velocity.y, ship.velocity.z])
	lines.append("")
	
	# === HOVER / GROUND ===
	lines.append("═══ HOVER ═══")
	lines.append("Grounded: %s" % ("YES" if ship.is_grounded else "NO"))
	lines.append("Ground Distance: %.2f" % ship.ground_distance)
	lines.append("Target Height: %.2f" % ship.hover_height)
	var height_error = ship.hover_height - ship.ground_distance
	lines.append("Height Error: %+.2f" % height_error)
	lines.append("Time Airborne: %.2fs" % ship.time_since_grounded)
	lines.append("")
	
	# === TRACK ANGLE ===
	var track_normal = ship.current_track_normal
	var slope_angle = rad_to_deg(acos(track_normal.dot(Vector3.UP)))
	var slope_dir = Vector3(track_normal.x, 0, track_normal.z).normalized()
	lines.append("═══ TRACK ═══")
	lines.append("Track Normal: (%.2f, %.2f, %.2f)" % [track_normal.x, track_normal.y, track_normal.z])
	lines.append("Slope Angle: %.1f°" % slope_angle)
	
	# Calculate if going uphill or downhill
	var ship_forward = -ship.global_transform.basis.z
	var forward_flat = Vector3(ship_forward.x, 0, ship_forward.z).normalized()
	var slope_dot = forward_flat.dot(slope_dir)
	var slope_type = "FLAT"
	if slope_angle > 2.0:
		if slope_dot > 0.3:
			slope_type = "UPHILL"
		elif slope_dot < -0.3:
			slope_type = "DOWNHILL"
		else:
			slope_type = "BANKING"
	lines.append("Slope Type: %s" % slope_type)
	lines.append("")
	
	# === GRIP / HANDLING ===
	lines.append("═══ HANDLING ═══")
	lines.append("Base Grip: %.2f" % ship.grip)
	lines.append("Current Grip: %.2f" % ship.current_grip)
	var grip_ratio = ship.current_grip / ship.grip * 100.0
	lines.append("Grip Ratio: %.0f%%" % grip_ratio)
	lines.append("Airbraking: %s" % ("YES" if ship.is_airbraking else "NO"))
	if ship.is_airbraking:
		lines.append("  L: %.0f%%  R: %.0f%%" % [ship.airbrake_left * 100, ship.airbrake_right * 100])
	lines.append("")
	
	# === INPUT ===
	lines.append("═══ INPUT ═══")
	lines.append("Throttle: %+.2f" % ship.throttle_input)
	lines.append("Steering: %+.2f" % ship.steer_input)
	lines.append("Pitch Input: %+.2f" % ship.pitch_input)
	lines.append("")
	
	# === VISUAL STATE ===
	lines.append("═══ VISUALS ═══")
	lines.append("Visual Pitch: %+.1f°" % rad_to_deg(ship.visual_pitch))
	lines.append("Visual Roll: %+.1f°" % rad_to_deg(ship.visual_roll))
	lines.append("Accel Pitch: %+.1f°" % rad_to_deg(ship.visual_accel_pitch))
	lines.append("")
	
	# === SHIP ORIENTATION ===
	var ship_up = ship.global_transform.basis.y
	var ship_fwd = -ship.global_transform.basis.z
	lines.append("═══ ORIENTATION ═══")
	lines.append("Ship Up: (%.2f, %.2f, %.2f)" % [ship_up.x, ship_up.y, ship_up.z])
	lines.append("Ship Fwd: (%.2f, %.2f, %.2f)" % [ship_fwd.x, ship_fwd.y, ship_fwd.z])
	
	# Calculate actual pitch and roll of physics body
	var body_pitch = rad_to_deg(asin(-ship_fwd.y))
	var body_roll = rad_to_deg(asin(ship_up.x))
	lines.append("Body Pitch: %+.1f°" % body_pitch)
	lines.append("Body Roll: %+.1f°" % body_roll)
	lines.append("")
	
	# === POSITION ===
	var pos = ship.global_position
	lines.append("═══ POSITION ═══")
	lines.append("World Pos: (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z])
	
	debug_label.text = "\n".join(lines)
