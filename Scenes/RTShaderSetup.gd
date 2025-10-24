@tool
extends CompositorEffect
class_name RTSetupShader

@export var UpdateShader: bool = true:
	set(value):
		mutex.lock()
		UpdateShader = value
		shader_is_dirty = true
		mutex.unlock()



var rd: RenderingDevice
var shader: RID
var pipeline: RID

var mutex: Mutex = Mutex.new()
var shader_is_dirty: bool = true

var camera_moved = false
var last_projection_matrix:Projection
var last_inverse_view_matrix:Transform3D
var last_cam_transform: Transform3D
var last_camera_position:Vector3

var ray_buffer:RID
var accumulationBuffer:RID
var camera_data_buffer:RID
var sphere_buffer:RID
var cube_buffer:RID
var material_buffer:RID
var cam_change_buffer:RID
var camera_change_set:RID
var accum_uniform_set:RID
var material_uniform_set:RID
var sphere_uniform_set:RID
var cube_uniform_set:RID
var ray_uniform_set:RID
var camera_data_set:RID

var frame_index:int = 0

var rt_scene = Scene.new()

var ray_buffer_size
var last_size: Vector2 
var scene_changed = false
var accumulate: bool = true

@export var initialized: bool = false
@export var rays_per_pixel: int = 1
@export var max_bounces: int = 5

func _init():
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			rd.free_rid(shader)
			
func _check_shader() -> bool:
	if not rd:
		return false

	var new_shader_code: String = ""

	# Check if our shader is dirty.
	mutex.lock()
	if shader_is_dirty:
		var file := FileAccess.open("res://Shaders/RaytracingShader.glsl", FileAccess.READ)
		if file:
			new_shader_code = file.get_as_text()
			new_shader_code = new_shader_code.replace("#[compute]" , " ")
			file.close()
		else:
			print("no file")
		UpdateShader = false
		camera_moved = true
		shader_is_dirty = false
	mutex.unlock()

	# We don't have a (new) shader?
	if new_shader_code.is_empty():
		return pipeline.is_valid()

	# Apply template.
	#new_shader_code = template_shader.replace("#COMPUTE_CODE", new_shader_code);

	# Out with the old.
	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
		pipeline = RID()

	# In with the new.
	var shader_source: RDShaderSource = RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_source.source_compute = new_shader_code
	var shader_spirv: RDShaderSPIRV = rd.shader_compile_spirv_from_source(shader_source)

	if shader_spirv.compile_error_compute != "":
		push_error(shader_spirv.compile_error_compute)
		push_error("In: " + new_shader_code)
		return false

	shader = rd.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		return false

	pipeline = rd.compute_pipeline_create(shader)
	return pipeline.is_valid()


func matrix_to_float32(transform: Transform3D) -> PackedFloat32Array:
	var basis : Basis = transform.basis
	var origin : Vector3 = transform.origin
	var mat := PackedFloat32Array([
		basis.x.x, basis.x.y, basis.x.z, 0.0,
		basis.y.x, basis.y.y, basis.y.z, 0.0,
		basis.z.x, basis.z.y, basis.z.z, 0.0,
		origin.x, origin.y, origin.z, 0.0
	])
	return mat

func has_camera_changed(projection_matrix: Projection, inverse_view_matrix: Transform3D, cam_transform: Transform3D, camera_position: Vector3) -> bool:
	if last_projection_matrix == null or last_projection_matrix != projection_matrix:
		return true
	if not inverse_view_matrix.is_equal_approx(last_inverse_view_matrix):
		return true
	if not cam_transform.is_equal_approx(last_cam_transform):
		return true
	if not camera_position.is_equal_approx(last_camera_position):
		return true
	return false

func projection_to_float32(proj: Projection) -> PackedFloat32Array:
	var arr := PackedFloat32Array()
	arr.append_array([
		proj.x.x, proj.x.y, proj.x.z, proj.x.w,  # Column 0
		proj.y.x, proj.y.y, proj.y.z, proj.y.w,  # Column 1
		proj.z.x, proj.z.y, proj.z.z, proj.z.w,  # Column 2
		proj.w.x, proj.w.y, proj.w.z, proj.w.w   # Column 3
	])
	return arr

func has_viewportsize_changed(s: Vector2) -> bool:
	return last_size != s


func _render_callback(p_effect_callback_type, p_render_data) -> void:
	if not initialized:
		return
	if accumulate:
		frame_index += 1
	else:
		frame_index = 1
	#print(frame_index)
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and _check_shader():
		# Get our render scene buffers object, this gives us access to our render buffers.
		# Note that implementation differs per renderer hence the need for the cast.
		var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
		var render_scene_data : RenderSceneDataRD = p_render_data.get_render_scene_data()
		if render_scene_buffers:
			# Get our render size, this is the 3D render resolution!
			var size = render_scene_buffers.get_internal_size()
			
			if size.x == 0 and size.y == 0:
				return

			# We can use a compute shader here.
			var x_groups = (size.x - 1) / 8 + 1
			var y_groups = (size.y - 1) / 8 + 1
			var z_groups = 1

			#var format := RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
			#var usage := RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
			#ray direction buffers
			var pixel_count: int = size.x * size.y
			var byte_size = pixel_count * 4 * 4
			
			var input_image = render_scene_buffers.get_color_layer(0)
			var uniform: RDUniform = RDUniform.new()
			uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			uniform.binding = 0
			uniform.add_id(input_image)
			var uniform_set = UniformSetCacheRD.get_cache(shader, 0, [ uniform ])
			
			#camera Data
			#var fov: float = render_scene_data.get_cam_projection().get_fov()
			#var aspect: float = render_scene_data.get_cam_projection().get_aspect()
			#var near: float = render_scene_data.get_cam_projection().get_z_near()
			#var far: float = render_scene_data.get_cam_projection().get_z_far()
			
			var projection_matrix: Projection = render_scene_data.get_cam_projection()
			var inverse_view_matrix:Transform3D = render_scene_data.get_cam_transform().affine_inverse()
			var cam_transform: Transform3D = render_scene_data.get_cam_transform()
			var camera_position:Vector3 = render_scene_data.get_cam_transform().origin

			
			#check if camera moved
			var viewport_changed: bool = has_viewportsize_changed(size)
			camera_moved = has_camera_changed(projection_matrix, inverse_view_matrix, cam_transform, camera_position)
			var camera_data_floats: PackedFloat32Array = PackedFloat32Array()
			
			#push Const
			var push_constant: PackedFloat32Array = PackedFloat32Array()
			push_constant.push_back(size.x)
			push_constant.push_back(size.y)
			push_constant.push_back(0.0)
			push_constant.push_back(0.0)
			push_constant.push_back(float(frame_index))
			push_constant.push_back(float(rt_scene.spheres.size()))
			push_constant.push_back(float(rt_scene.materials.size()))
			push_constant.push_back(float(rays_per_pixel))
			push_constant.push_back(float(max_bounces))
			push_constant.push_back(float(1 if (has_viewportsize_changed(size) or camera_moved or scene_changed) else 0))
			push_constant.push_back(0.0)
			push_constant.push_back(0.0)
			push_constant.push_back(rt_scene.sky_color.x)
			push_constant.push_back(rt_scene.sky_color.y)
			push_constant.push_back(rt_scene.sky_color.z)
			push_constant.push_back(rt_scene.cubes.size())
			
			
			
			
			var zeros := PackedByteArray()
			zeros.resize(byte_size)
			if has_viewportsize_changed(size):
				if accumulationBuffer.is_valid():
					rd.free_rid(accumulationBuffer)
				accumulationBuffer = rd.storage_buffer_create(byte_size)
				var accum_uniform := RDUniform.new()
				accum_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
				accum_uniform.binding = 0
				accum_uniform.add_id(accumulationBuffer)
				accum_uniform_set = UniformSetCacheRD.get_cache(shader, 5, [accum_uniform])
				
				
			if has_viewportsize_changed(size):
				if ray_buffer.is_valid():
					rd.free_rid(ray_buffer)
				ray_buffer = rd.storage_buffer_create(byte_size)
				ray_buffer_size = byte_size
				var ray_uniform := RDUniform.new()
				ray_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
				ray_uniform.binding = 0
				ray_uniform.add_id(ray_buffer)
				ray_uniform_set = UniformSetCacheRD.get_cache(shader, 2, [ray_uniform])
				

			if camera_moved:
				#camera Data
				camera_data_floats.append_array(projection_to_float32(projection_matrix))
				camera_data_floats.append_array(projection_to_float32(inverse_view_matrix))
				camera_data_floats.append_array(matrix_to_float32(cam_transform))
				camera_data_floats.append_array(PackedFloat32Array([camera_position.x, camera_position.y, camera_position.z, 0.0]))
				var camera_data_bytes = camera_data_floats.to_byte_array()
				if camera_data_buffer.is_valid():
					rd.free_rid(camera_data_buffer)
					
				camera_data_buffer = rd.storage_buffer_create(camera_data_bytes.size(), camera_data_bytes)
				var camera_data_uniform : RDUniform = RDUniform.new();
				camera_data_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
				camera_data_uniform.binding = 0
				camera_data_uniform.add_id(camera_data_buffer)
				camera_data_set = UniformSetCacheRD.get_cache(shader, 1, [ camera_data_uniform ])
			if scene_changed:
				var sphere_data := PackedFloat32Array()
				var cube_data := PackedFloat32Array()
				var material_data := PackedFloat32Array()
				
				for s in rt_scene.spheres:
					sphere_data.append_array([
					s.position.x, s.position.y, s.position.z,
					s.radius, float(s.material_index), 0.0, 0.0, 0.0
				])
				
				for c in rt_scene.cubes:
					cube_data.append_array([
						c.position.x, c.position.y, c.position.z, 0.0,
						c.size.x/2.0, c.size.y/2.0, c.size.z/2.0, 0.0,
						c.rotation.x, c.rotation.y, c.rotation.z,
						float(c.material_index)
					])
				
				for m:RTMaterial in rt_scene.materials:
					material_data.append_array([
					m.albedo.x, m.albedo.y, m.albedo.z, m.roughness,
					m.metallic, 0.0, 0.0, 0.0, 
					m.emission_color.x, m.emission_color.y, m.emission_color.z,
					m.emission_power, m.specular_probability, float(m.is_glass), m.ior, m.absorbtion_strength,
					m.absorbtion.x, m.absorbtion.y, m.absorbtion.z, 0.0
				])
				var sphere_data_byte_arr: PackedByteArray = sphere_data.to_byte_array()
				var cube_data_byte_arr: PackedByteArray = cube_data.to_byte_array()
				var material_data_byte_arr: PackedByteArray = material_data.to_byte_array()
				
				if sphere_buffer.is_valid():
					rd.free_rid(sphere_buffer)
				if sphere_data.is_empty():
					sphere_buffer = rd.storage_buffer_create(16)
				else:
					sphere_buffer = rd.storage_buffer_create(sphere_data_byte_arr.size(), sphere_data_byte_arr)
				var sphere_uniform := RDUniform.new()
				sphere_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
				sphere_uniform.binding = 0
				sphere_uniform.add_id(sphere_buffer)
				sphere_uniform_set = UniformSetCacheRD.get_cache(shader, 3, [sphere_uniform])
				
				if cube_buffer.is_valid():
					rd.free_rid(cube_buffer)
				if cube_data.is_empty():
					cube_buffer = rd.storage_buffer_create(16)
				else:
					cube_buffer = rd.storage_buffer_create(cube_data_byte_arr.size(), cube_data_byte_arr)
				var cube_uniform := RDUniform.new()
				cube_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
				cube_uniform.binding = 0
				cube_uniform.add_id(cube_buffer)
				cube_uniform_set = UniformSetCacheRD.get_cache(shader, 6, [cube_uniform])
				
				if material_buffer.is_valid():
					rd.free_rid(material_buffer)
				if material_data.is_empty():
					material_buffer = rd.storage_buffer_create(16)
				else:
					material_buffer = rd.storage_buffer_create(material_data_byte_arr.size(), material_data_byte_arr)
				var material_uniform := RDUniform.new()
				material_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
				material_uniform.binding = 0
				material_uniform.add_id(material_buffer)
				material_uniform_set = UniformSetCacheRD.get_cache(shader, 4, [material_uniform])
			# Run our compute shader.

			var compute_list:= rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
			rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
			rd.compute_list_bind_uniform_set(compute_list, camera_data_set, 1)
			rd.compute_list_bind_uniform_set(compute_list, ray_uniform_set, 2)
			rd.compute_list_bind_uniform_set(compute_list, sphere_uniform_set, 3)
			rd.compute_list_bind_uniform_set(compute_list, material_uniform_set, 4)
			rd.compute_list_bind_uniform_set(compute_list, accum_uniform_set, 5)
			rd.compute_list_bind_uniform_set(compute_list, cube_uniform_set, 6)

			rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
			rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
			rd.compute_list_end()
			
			if camera_moved or scene_changed or has_viewportsize_changed(size):
				frame_index = 0
				scene_changed = false
				camera_moved = false
				last_size = size
				#set
				last_projection_matrix = projection_matrix
				last_inverse_view_matrix = inverse_view_matrix
				last_cam_transform = cam_transform
				last_camera_position = camera_position

	
