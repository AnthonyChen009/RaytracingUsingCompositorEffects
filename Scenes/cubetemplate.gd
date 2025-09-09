extends VBoxContainer

var CubeObj
var CubeInd: int
var mainScene
@onready var spins: Array[SpinBox] = [
	$HBoxContainer/XSlider,
	$HBoxContainer/YSlider,
	$HBoxContainer/ZSlider,
	$HBoxContainer2/XSliderS,
	$HBoxContainer2/YSliderS,
	$HBoxContainer2/ZSliderS,
	$HBoxContainer4/XSliderR,
	$HBoxContainer4/YSliderR,
	$HBoxContainer4/ZSliderR,
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
	if CubeObj == null:
		return
	$HBoxContainer/XSlider.get_line_edit().virtual_keyboard_type = 2
	$Label.text = "Cube: " + str(CubeObj.material_index + 1)
	
	$HBoxContainer/XSlider.value = CubeObj.position.x
	$HBoxContainer/YSlider.value = CubeObj.position.y
	$HBoxContainer/ZSlider.value = CubeObj.position.z
	
	$HBoxContainer2/XSliderS.value = CubeObj.size.x
	$HBoxContainer2/YSliderS.value = CubeObj.size.y
	$HBoxContainer2/ZSliderS.value = CubeObj.size.z
	
	$HBoxContainer4/XSliderR.value = CubeObj.rotation.x
	$HBoxContainer4/YSliderR.value = CubeObj.rotation.y
	$HBoxContainer4/ZSliderR.value = CubeObj.rotation.z
	
	$HBoxContainer3/MaterialSlider.value = CubeObj.material_index
	$HBoxContainer3/MaterialSlider.max_value = size



func _on_x_slider_value_changed(value: float) -> void:
	CubeObj.position.x = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_y_slider_value_changed(value: float) -> void:
	CubeObj.position.y = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_z_slider_value_changed(value: float) -> void:
	CubeObj.position.z = value
	if mainScene == null:
		return
	mainScene._updateScene()




func _on_material_slider_value_changed(value: float) -> void:
	CubeObj.material_index = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_x_slider_s_value_changed(value: float) -> void:
	CubeObj.size.x = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_y_slider_s_value_changed(value: float) -> void:
	CubeObj.size.y = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_z_slider_s_value_changed(value: float) -> void:
	CubeObj.size.z = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_x_slider_r_value_changed(value: float) -> void:
	CubeObj.rotation.x = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_y_slider_r_value_changed(value: float) -> void:
	CubeObj.rotation.y = value
	if mainScene == null:
		return
	mainScene._updateScene()


func _on_z_slider_r_value_changed(value: float) -> void:
	CubeObj.rotation.z = value
	if mainScene == null:
		return
	mainScene._updateScene()
