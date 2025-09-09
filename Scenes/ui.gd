extends Control

@onready var fps := $HBoxContainer/Padding/ColorRect/ScrollContainer/VBoxContainer/Main/FPSLabel
@onready var RenderTime := $HBoxContainer/Padding/ColorRect/ScrollContainer/VBoxContainer/Main/RenderLabel
var panel_opened = true
var following = false

func _ready() -> void:
	get_viewport().size_changed.connect(resize)

func _process(delta: float) -> void:
	RenderTime.text = "Last Render: %.3f ms" % (delta * 1000.0)
	if following:
		var resizer:Control = $BarResize
		resizer.position.y = get_global_mouse_position().y
		
		$HBoxContainer/Padding/ColorRect/ScrollContainer.custom_minimum_size.y = resizer.position.y
		$HBoxContainer/Padding/ColorRect/ScrollContainer.size.y = resizer.position.y
		$HBoxContainer/Padding/ColorRect/ScrollContainer2.position.y = resizer.position.y
		$HBoxContainer/Padding/ColorRect/ScrollContainer2.custom_minimum_size.y = get_viewport().get_visible_rect().size.y - resizer.position.y
		$HBoxContainer/Padding/ColorRect/ScrollContainer2.size.y = get_viewport().get_visible_rect().size.y - resizer.position.y

func resize():
	var resizer:Control = $BarResize
	resizer.position.y = get_viewport().get_visible_rect().size.y / 2
	
	$HBoxContainer/Padding/ColorRect/ScrollContainer.custom_minimum_size.y = resizer.position.y
	$HBoxContainer/Padding/ColorRect/ScrollContainer.size.y = resizer.position.y
	$HBoxContainer/Padding/ColorRect/ScrollContainer2.position.y = resizer.position.y
	$HBoxContainer/Padding/ColorRect/ScrollContainer2.custom_minimum_size.y = get_viewport().get_visible_rect().size.y - resizer.position.y
	$HBoxContainer/Padding/ColorRect/ScrollContainer2.size.y = get_viewport().get_visible_rect().size.y - resizer.position.y

func _physics_process(delta: float) -> void:
	fps.text = "FPS: " + str(Engine.get_frames_per_second())
	


func _on_button_pressed() -> void:
	if panel_opened:
		var tween = get_tree().create_tween()
		tween.tween_property(self, "position", Vector2(440, 0), 1).set_trans(Tween.TRANS_QUINT)
		$HBoxContainer/VBoxContainer/Button.text = "<"
		panel_opened = false
	else:
		var tween = get_tree().create_tween()
		tween.tween_property(self, "position", Vector2(0, 0), 1).set_trans(Tween.TRANS_QUINT)
		$HBoxContainer/VBoxContainer/Button.text = ">"
		panel_opened = true


func _on_bar_resize_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.get_button_index() == 1:
			following = !following


func _on_enable_rtx_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.
