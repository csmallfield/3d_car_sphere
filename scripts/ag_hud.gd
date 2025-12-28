extends CanvasLayer
class_name AGHUD

@export var ship: AGShip

@onready var speed_label: Label = $SpeedLabel

func _process(_delta: float) -> void:
	if ship:
		var speed_kmh = abs(ship.current_speed) * 3.6  # Convert to km/h feel
		speed_label.text = "%03d km/h" % int(speed_kmh)
