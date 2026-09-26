class_name RoadChunkBody
extends StaticBody3D

func is_on_asphalt(pos: Vector3) -> bool:
	return 0. < get_parent().get_asphalt_quantity_at(pos)

func get_road_chunk() -> RoadChunk:
	return get_parent()
