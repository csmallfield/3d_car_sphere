extends CanvasLayer
class_name PauseMenu

## In-game pause menu

signal resume_requested
signal restart_requested
signal quit_requested

var title_label: Label
var resume_button: Button
var restart_button: Button
var quit_button: Button

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_create_ui()
	_connect_signals()

func _create_ui() -> void:
	# Panel container
	var panel: PanelContainer
	if not has_node("PanelContainer"):
		panel = PanelContainer.new()
		panel.name = "PanelContainer"
		add_child(panel)
	else:
		panel = $PanelContainer
	
	panel.position = Vector2(1920/2 - 250, 1080/2 - 200)
	panel.size = Vector2(500, 400)
	
	# VBox for content
	var vbox: VBoxContainer
	if not panel.has_node("VBoxContainer"):
		vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		panel.add_child(vbox)
	else:
		vbox = panel.get_node("VBoxContainer")
	
	vbox.add_theme_constant_override("separation", 20)
	
	# Title
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "PAUSED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer1)
	
	# Buttons
	resume_button = _create_pause_button("RESUME", vbox)
	restart_button = _create_pause_button("RESTART", vbox)
	quit_button = _create_pause_button("QUIT TO MENU", vbox)

func _create_pause_button(text: String, parent: Control) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(400, 50)
	button.add_theme_font_size_override("font_size", 24)
	parent.add_child(button)
	return button

func _connect_signals() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC key
		if visible:
			_on_resume_pressed()
		else:
			show_pause()

func show_pause() -> void:
	visible = true
	RaceManager.pause_race()

func hide_pause() -> void:
	visible = false
	RaceManager.resume_race()

func _on_resume_pressed() -> void:
	hide_pause()
	resume_requested.emit()

func _on_restart_pressed() -> void:
	hide_pause()
	restart_requested.emit()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	hide_pause()
	quit_requested.emit()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
