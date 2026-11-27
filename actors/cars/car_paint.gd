extends MeshInstance3D

func _ready() -> void:
	randomizeMaterialColor()

func randomizeMaterialColor() -> void:
	
	# pick a random color
	var hue = randf_range(0,1) # any color hue
	var saturation = randf_range(0,1) # very rainbowy
	var val = randf_range(0.8, 1.0) # only lighter tints
	var random_tint = Color.from_hsv(hue,saturation,val)
	
	# make material unique so cars don't share
	# can't use the normal way 
	# (because the car is a SHADER MATERIAL with crash vertext shader)
	# var mat:StandardMaterial3D = get_active_material(0).duplicate()
	# mat.albedo_color = random_tint

	#var mat:ShaderMaterial = get_active_material(0).duplicate()
	#mat.set_shader_parameter("albedo_color",random_tint)
	#set_surface_override_material(0, mat)
	
	# this way we don't need tons of unique materials! 
	# but shader needs these two lines:
	# instance uniform vec4 albedo_color : source_color = vec4(1.0);
	# void fragment() { ALBEDO = albedo_color.rgb; } 
	
	var mat:ShaderMaterial = get_active_material(0)
	#set_instance_shader_parameter("albedo_color", random_tint) # this would allow >1 color with 1 material
	mat.set_shader_parameter("albedo", random_tint)

	
