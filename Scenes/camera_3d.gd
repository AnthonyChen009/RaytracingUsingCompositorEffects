# CameraRuntime.gd
extends Camera3D

@export var move_speed := 5.0			# Base speed
@export var fast_multiplier := 4.0		# Hold Shift while RMB for boost
@export var mouse_sensitivity := 0.003

var yaw := 0.0
var pitch := 0.0
var rmb_down := false

func _ready():
	# Mouse starts free
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	yaw = rotation.y
	pitch = rotation.x

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			rmb_down = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			rmb_down = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if rmb_down and event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
		rotation = Vector3(pitch, yaw, 0)

func _process(delta):
	if not rmb_down:
		return

	var speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_multiplier

	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		dir += transform.basis.x
	if Input.is_key_pressed(KEY_Q):
		dir -= transform.basis.y
	if Input.is_key_pressed(KEY_E):
		dir += transform.basis.y

	if dir != Vector3.ZERO:
		global_position += dir.normalized() * speed * delta
