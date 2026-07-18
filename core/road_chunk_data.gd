class_name RoadChunkData
extends Resource

@export_category("terrain")
@export var terrain_heightmap: Texture
@export var terrain_normalmap: Texture
@export var terrain_albedo_image: Texture

@export_category("asphalt")
## Data about the attributes of the asphalt
## Red channel: asphalt presence
## Green channel: asphalt editability
## Blue channel: asphalt(?) fluidity(is asphalt actually water)
@export var asphalt_attributes: Texture

## Data about the starting asphalt quantity on the level
## Red channel: Normalized asphalt quantity
## Green channel: Normalized asphalt temperature
## Blue channel: unused
@export var start_asphalt_state: Texture

## Data about the target asphalt quantity on the level
## Red channel: target asphalt quantity
## Green channel: unused
## Blue channel: unused
@export var target_asphalt_state: Texture
