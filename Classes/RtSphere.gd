@tool
class_name RtSphere extends MeshInstance3D

@export_range(0.001, 1000.0, 0.001) var radius := 1.0 : set = _set_radius
@export_range(3, 256, 1) var rings := 32 : set = _set_rings         # vertical slices
@export_range(3, 256, 1) var radial_segments := 64 : set = _set_rad  # around the equator

@export var albedo: Color = Color(1, 1, 1, 1) : set = _set_albedo
@export_range(0.0, 1.0, 0.001) var roughness: float = 0.5 : set = _set_roughness
@export_range(0.0, 1.0, 0.001) var metallic: float = 0.0 : set = _set_metallic
@export var emission_color: Color = Color(1, 1, 1, 1) : set = _set_emission_color
@export var emission_power: float = 0.0 : set = _set_emission_power
@export_range(0.0, 1.0, 0.001) var specular_probability: float = 0

@export var material_index: int = 0
var sphere_index

var _mat: StandardMaterial3D
var _sphere: SphereMesh

func _init() -> void:
	_mat = StandardMaterial3D.new()
	_ensure_mesh()
	_apply_material()
	_apply_params()

func _ensure_mesh() -> void:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.resource_local_to_scene = true
		mesh = _sphere
		mesh.material = _mat

func _set_radius(v: float) -> void:
	radius = max(0.0, v); _ensure_mesh(); _apply_params()

func _set_rings(v: int) -> void:
	rings = clamp(v, 3, 256); _ensure_mesh(); _apply_params()

func _set_rad(v: int) -> void:
	radial_segments = clamp(v, 3, 256); _ensure_mesh(); _apply_params()

func _apply_params() -> void:
	if _sphere == null:
		return
	_sphere.radius = radius
	_sphere.height = radius * 2.0
	_sphere.rings = rings
	_sphere.radial_segments = radial_segments
	mesh = _sphere

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
