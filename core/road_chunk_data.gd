class_name RoadChunkData
extends Resource

@export var terrain_heightmap: Texture ## Normalized data of how high is the terrain on this level
@export var terrain_normalmap: Texture
@export var terrain_albedo_image: Texture
@export var asphalt_filter_image: Texture
@export var asphalt_quantity_texture: Texture ## Normalized data of how high is the starting asphalt on this level
@export var target_height_texture: Texture ## Includes both the terrain and asphalt heights normalized
