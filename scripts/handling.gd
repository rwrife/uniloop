class_name WheelHandling
extends Resource
## One resource for physical handling and side-scroll camera tuning.

@export var gravity: float = 26.0
@export var acceleration: float = 18.0
@export var brake: float = 34.0
@export var drag: float = 4.0
@export var max_speed: float = 32.0
## Downhill momentum may carry the wheel past max_speed by this factor.
@export var overspeed: float = 1.3
@export var slope_gravity: float = 0.6
@export var reverse_speed: float = 6.0
@export var air_control: float = 4.0
@export var spin_rate: float = 7.0
@export var align_rate: float = 14.0
@export var jump_speed: float = 10.0
@export var pump_boost: float = 4.0
@export var crash_angle: float = 75.0
@export var crash_speed_keep: float = 0.3
@export var wheel_radius: float = 0.65
@export var floor_snap: float = 0.35
@export var fall_height: float = -9.0
@export var camera_distance: float = 20.0
@export var camera_height: float = 2.5
@export var camera_lead: float = 7.0
@export var camera_follow: float = 5.0
@export var reset_offset: float = 3.0
@export var gate_min_speed: float = 0.5
