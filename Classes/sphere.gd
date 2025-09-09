class_name Sphere

var position: Vector3
var radius: float
var material_index: int

func _init(pos: Vector3, rad:float, matInd: int) -> void:
	position = pos
	self.radius = rad
	material_index = matInd
