class_name RoadChunkData
extends Resource

@export_category("terrain")
@export var terrain_heightmap: Texture
@export var terrain_normalmap: Texture
@export var terrain_albedo_image: Texture
@export var height_unit: float = 5.

@export_category("water")
@export_range(0., 100.) var water_scale: float = 35.
@export_range(0., 100.) var water_speed: float = 15.
@export_range(0., 200.) var water_shinyness: float = 15
@export_range(0.005, 20.) var water_detail_count: float = 5.0
@export_range(0., TAU) var water_angle: float = 0.
@export_range(0., 1.) var water_angle_dominance: float = 0.0
@export_range(0., 1.) var water_detail_strength: float = 0.575
@export_range(0., 1.) var water_height: float = 0.2
@export_range(0., 1.) var water_transparency: float = 0.8
@export var water_color: Color = Color.BLUE

@export_category("dynamic_surface")
## The type of dynamic surface used within the level
@export var surface: RoadChunk.DynamicSurfaces = RoadChunk.DynamicSurfaces.ASPHALT

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
