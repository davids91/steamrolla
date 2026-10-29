# work in progress!!!! - mcf
# gives all SUB-MESHES (child objects) a rigid body
# put this script on an node3d parent that contains a bunch of meshes

extends Node3D

func _ready() -> void:
	var kids = get_children()
	print("giving physics to all "+str(kids.size())+" children of "+name)
	for child in kids:
		if child is MeshInstance3D:
			give_mesh_physics(child)

func give_mesh_physics(mesh_instance: MeshInstance3D) -> void:

	print("giving ["+mesh_instance.name+"] some physics")

	# make a rigid body
	var rigid_body = RigidBody3D.new()
	rigid_body.transform = mesh_instance.transform
	# TODO: give it a size-dependent mass/friction/etc

	# add rb to the scene
	add_child(rigid_body)

	# put the mesh inside rb at pos 0,0,0
	mesh_instance.transform = Transform3D.IDENTITY 
	mesh_instance.reparent(rigid_body)

	# automagically create a collider as a child
	mesh_instance.create_convex_collision(true, true)

	# could do it manually...
	# var col = CollisionShape3D.new()
	# col.shape = mesh_instance.mesh.create_convex_mesh()
	# could even optimize and use box or sphere shape instead...
	# col.shape = BoxShape3D.new()
	# col.shape.size = Vector3(1.0, 1.0, 1.0) 
	# rigid_body.add_child(col)
