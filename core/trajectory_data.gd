class_name TrajectoryData
extends Resource

## Overall duration traversing the trajectory should take
@export var trajectory_duration_sec: float = 0.

## Stops and curves for each segment in the trajectory
@export var curves: Curve3D = Curve3D.new()

## Time duration of each segment in seconds 
@export var segment_durations_sec: Array[float] = []

## How much time the target should wait at the start of each segment
@export var stop_durations_sec: Array[float] = []

## How much normalized progress each segment advances(to help PathFollower3Ds set progress_ratio)
@export var segment_normalized_progress: Array[float]
