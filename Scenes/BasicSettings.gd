extends Control

var acc: bool = true
var enb: bool = false
var bounces: int = 5
var rays: int = 1
var objRef
@onready var spins: Array[SpinBox] = [
	$RaysPerPixelSlider,
	$MaxBouncesSlider
]


func _on_accumulate_check_toggled(toggled_on: bool) -> void:
	acc = toggled_on
	update_vals()


func _on_rays_per_pixel_slider_value_changed(value: float) -> void:
	rays = value
	update_vals()


func _on_max_bounces_slider_value_changed(value: float) -> void:
	bounces = value
	update_vals()
	
func _on_enable_rtx_toggled(toggled_on: bool) -> void:
	enb = toggled_on
	update_vals()

func _on_v_sync_check_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func update_vals():
	if objRef == null:
		return
	
	objRef.enabled = enb
	objRef.accumulate = acc
	objRef.rays_per_pixel = rays
	objRef.max_bounces = bounces
	objRef.scene_changed = true

func _ready() -> void:
	enb = $EnableRtx.button_pressed
	
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
