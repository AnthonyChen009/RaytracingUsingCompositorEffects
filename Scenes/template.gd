extends VBoxContainer

var SphereObj
var sphereInd: int
var mainScene
@onready var spins: Array[SpinBox] = [
	$HBoxContainer/XSlider,
	$HBoxContainer/YSlider,
	$HBoxContainer/ZSlider,
	$HBoxContainer2/RadiusSlider,
	$HBoxContainer3/MaterialSlider,
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for sb in spins:
		var le := sb.get_line_edit()
		le.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		le.gui_input.connect(_on_le_gui_input.bind(le))
		le.text_changed.connect(_on_le_text_changed.bind(le, sb))

func _on_le_gui_input(event: InputEvent, le: LineEdit) -> void:
	if event is InputEventKey and event.pressed and !event.echo:
		if event.keycode in [KEY_BACKSPACE, KEY_DELETE, KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			return
		var ch := char(event.unicode)
		if ch >= "0" and ch <= "9":
			return
		if ch == "." and le.text.find(".") == -1:
			return
		if ch == "-" and le.caret_column == 0 and !le.text.begins_with("-"):
			return
		accept_event()

func _on_le_text_changed(t: String, le: LineEdit, sb: SpinBox) -> void:
	# Strip anything that isn't digits, one optional leading '-', and one '.'
	var keep := ""
	var has_dot := false
	for i in t.length():
		var c := t[i]
		if c >= "0" and c <= "9":
			keep += c
		elif c == "." and !has_dot:
			has_dot = true
			keep += c
		elif c == "-" and i == 0 and sb.min_value < 0.0 and !keep.begins_with("-"):
			keep += c
	if keep != t:
		var caret := le.caret_column
		le.text = keep
		le.caret_column = min(caret, keep.length())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func update_params(size: int):
	if SphereObj == null:
		return
	$HBoxContainer/XSlider.get_line_edit().virtual_keyboard_type = 2
	$Label.text = "Sphere: " + str(SphereObj.material_index + 1)
	$HBoxContainer/XSlider.value = SphereObj.position.x
	$HBoxContainer/YSlider.value = SphereObj.position.y
	$HBoxContainer/ZSlider.value = SphereObj.position.z
	$HBoxContainer2/RadiusSlider.value = SphereObj.radius
	$HBoxContainer3/MaterialSlider.value = SphereObj.material_index
	$HBoxContainer3/MaterialSlider.max_value = size



func _on_x_slider_value_changed(value: float) -> void:
	SphereObj.position.x = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_y_slider_value_changed(value: float) -> void:
	SphereObj.position.y = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_z_slider_value_changed(value: float) -> void:
	SphereObj.position.z = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_radius_slider_value_changed(value: float) -> void:
	SphereObj.radius = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_material_slider_value_changed(value: float) -> void:
	SphereObj.material_index = value
	if mainScene == null:
		return
	mainScene._updateScene()
