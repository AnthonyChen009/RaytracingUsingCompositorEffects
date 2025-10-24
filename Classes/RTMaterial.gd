class_name RTMaterial

var albedo: Vector3
var roughness: float
var metallic: float
var emission_color: Vector3
var emission_power: float
var specular_probability: float
var is_glass: bool = false
var ior: float
var absorbtion: Vector3
var absorbtion_strength: float

func _init(al: Vector3 = Vector3(1, 1, 1), rough: float = 0.5, metal: float = 0.0, 
			emission_col: Vector3 = Vector3(0, 0, 0), emission_pow: float = 0.0,
			spec_prob: float = 0.0, is_glass_mat: bool = false, indexOfRefract: float = 1.0,
			absorb: Vector3 = Vector3(0, 0, 0), absorb_strength: float = 0.0):
	albedo = al
	roughness = rough
	metallic = metal
	emission_color = emission_col
	emission_power = emission_pow
	specular_probability = spec_prob
	is_glass = is_glass_mat
	ior = indexOfRefract
	absorbtion = absorb
	absorbtion_strength = absorb_strength
