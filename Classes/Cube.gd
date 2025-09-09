class_name Cube

var position: Vector3
var size: Vector3
var rotation: Vector3
var material_index: int

func _init(pos: Vector3, size:Vector3, rot: Vector3, matInd: int) -> void:
	position = pos
	rotation = rot
	self.size = size
	material_index = matInd
