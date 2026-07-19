class_name RoadChunkBody
extends StaticBody3D

func is_on_asphalt(pos: Vector3) -> bool:
	return get_parent().is_on_asphalt(pos)
