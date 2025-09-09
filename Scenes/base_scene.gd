extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var spheres = $Spheres.get_children()
var template = preload("res://Scenes/template.tscn")
var cube_template = preload("res://Scenes/cubetemplate.tscn")
@onready var sphere_properties_panel = $Camera3D/UI/HBoxContainer/Padding/ColorRect/ScrollContainer2/SpherePropPanel
@onready var options_panel = $Camera3D/UI/HBoxContainer/Padding/ColorRect/ScrollContainer/VBoxContainer/Main
@onready var color_picker: ColorPickerButton = $Camera3D/UI/HBoxContainer/Padding/ColorRect/ScrollContainer/VBoxContainer/Main/HBoxContainer2/ColorPickerButton
var sphere_container_size: int = 0
var cube_container_size: int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#print(RenderingServer.get_current_rendering_driver_name())
	for sphere: RtSphere in spheres:
		if sphere.visible:
			sphere_container_size += 1
	for cube : RtCube in $Cubes.get_children():
		if cube.visible:
			cube_container_size += 1
			
	if Engine.is_editor_hint():
		pass
	else:
		var sphere_ind: int = 0
		var cube_ind: int = 0
		for sphere: RtSphere in spheres:
			if sphere.visible:
				sphere.material_index = sphere_ind
				var instance = template.instantiate()
				instance.SphereObj = sphere
				sphere_properties_panel.add_child(instance)
				instance.update_params(sphere_container_size - 1)
				instance.mainScene = self
				instance.visible = true
				sphere_ind += 1
		for cube : RtCube in $Cubes.get_children():
			if cube.visible:
				cube.material_index = sphere_ind + cube_ind
				var instance = cube_template.instantiate()
				instance.CubeObj = cube
				sphere_properties_panel.add_child(instance)
				instance.update_params(sphere_container_size + cube_container_size - 1)
				instance.mainScene = self
				instance.visible = true
				cube_ind += 1
		_updateScene()
		
		options_panel.objRef = camera.compositor.compositor_effects[0]
		
		camera.compositor.compositor_effects[0].initialized = true

func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	pass

func srgb_to_linear_ch(x: float) -> float:
	if x <= 0.04045:
		return x / 12.92
	else:
		return pow((x + 0.055) / 1.055, 2.4)

func srgb_to_linear(c: Color) -> Color:
	return Color(
		srgb_to_linear_ch(c.r),
		srgb_to_linear_ch(c.g),
		srgb_to_linear_ch(c.b),
		c.a
	)



func _updateScene():
	var spheresArray: Array[Sphere] = []
	var cubesArray: Array[Cube] = []
	var new_Scene: Scene = Scene.new()
	var materials: Array[RTMaterial] = []
	
	for sphere: RtSphere in spheres:
		if sphere.visible:
			spheresArray.append(Sphere.new(sphere.position, sphere.radius, sphere.material_index))
			materials.append(RTMaterial.new(
				Vector3(
					srgb_to_linear_ch(sphere.mesh.material.albedo_color.r),
					srgb_to_linear_ch(sphere.mesh.material.albedo_color.g),
					srgb_to_linear_ch(sphere.mesh.material.albedo_color.b)
					),
				sphere.mesh.material.roughness,
				sphere.mesh.material.metallic,
				Vector3(srgb_to_linear_ch(sphere.mesh.material.emission.r), 
						srgb_to_linear_ch(sphere.mesh.material.emission.g), 
						srgb_to_linear_ch(sphere.mesh.material.emission.b)),
				sphere.mesh.material.emission_energy_multiplier, sphere.specular_probability)
			)
	for cube : RtCube in $Cubes.get_children():
		if cube.visible:
			cubesArray.append(Cube.new(cube.position, cube.size, cube.rotation, cube.material_index))
			materials.append(RTMaterial.new(
				Vector3(
					srgb_to_linear_ch(cube.mesh.material.albedo_color.r),
					srgb_to_linear_ch(cube.mesh.material.albedo_color.g),
					srgb_to_linear_ch(cube.mesh.material.albedo_color.b)
					),
				cube.mesh.material.roughness,
				cube.mesh.material.metallic,
				Vector3(srgb_to_linear_ch(cube.mesh.material.emission.r), 
						srgb_to_linear_ch(cube.mesh.material.emission.g), 
						srgb_to_linear_ch(cube.mesh.material.emission.b)),
				cube.mesh.material.emission_energy_multiplier, cube.specular_probability)
			)
	
	new_Scene.spheres = spheresArray
	new_Scene.cubes = cubesArray
	new_Scene.materials = materials
	new_Scene.sky_color = Vector3(srgb_to_linear_ch(color_picker.color.r), srgb_to_linear_ch(color_picker.color.g), srgb_to_linear_ch(color_picker.color.b))
	camera.compositor.compositor_effects[0].scene_changed = true
	camera.compositor.compositor_effects[0].rt_scene = new_Scene


func _on_color_picker_button_color_changed(color: Color) -> void:
	_updateScene()
