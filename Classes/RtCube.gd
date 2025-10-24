@tool
class_name RtCube extends MeshInstance3D

@export var size: Vector3 = Vector3(1.0, 1.0, 1.0) : set = _set_size
@export var material_index: int = 0

@export var albedo: Color = Color(1, 1, 1, 1) : set = _set_albedo
@export_range(0.0, 1.0, 0.001) var roughness: float = 0.5 : set = _set_roughness
@export_range(0.0, 1.0, 0.001) var metallic: float = 0.0 : set = _set_metallic
@export var emission_color: Color = Color(1, 1, 1, 1) : set = _set_emission_color
@export_range(0.0, 1000000.0, 0.001) var emission_power: float = 0.0 : set = _set_emission_power
@export_range(0.0, 1.0, 0.001) var specular_probability: float = 0
@export_range(1.0, 3.0, 0.01) var ior: float = 1.0
@export var is_glass: bool = false
@export var absorbtion: Color = Color(0, 0, 0, 1) : set = _set_emission_color
@export var absorbtion_power: float = 1.0


var _mat: StandardMaterial3D
var cube: BoxMesh

func _init() -> void:
	_mat = StandardMaterial3D.new()
	_ensure_mesh()
	_apply_material()
	_apply_params()

func _ensure_mesh() -> void:
	if cube == null:
		cube = BoxMesh.new()
		cube.resource_local_to_scene = true
		mesh = cube
		mesh.material = _mat

func _apply_params() -> void:
	if cube == null:
		return
	cube.size = size
	mesh = cube


func _apply_material() -> void:
	if _mat == null:
		return
	_mat.albedo_color = albedo
	_mat.roughness = clamp(roughness, 0.0, 1.0)
	_mat.metallic = clamp(metallic, 0.0, 1.0)
	_mat.emission_enabled = emission_power > 0.0 or (emission_color.r != 0.0 or emission_color.g != 0.0 or emission_color.b != 0.0)
	_mat.emission = emission_color
	_mat.emission_energy_multiplier = max(emission_power, 0.0)

func _set_albedo(v: Color) -> void:
	albedo = v
	_apply_material()

func _set_roughness(v: float) -> void:
	roughness = clamp(v, 0.0, 1.0)
	_apply_material()

func _set_metallic(v: float) -> void:
	metallic = clamp(v, 0.0, 1.0)
	_apply_material()

func _set_emission_color(v: Color) -> void:
	emission_color = v
	_apply_material()

func _set_emission_power(v: float) -> void:
	emission_power = max(v, 0.0)
	_apply_material()

func _set_size(v: Vector3):
	size = v
	_apply_params()
