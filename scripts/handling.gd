class_name WheelHandling
extends Resource
## One resource for physical handling, stunt and side-scroll camera tuning.

@export var gravity: float = 26.0
@export var acceleration: float = 18.0
@export var brake: float = 40.0
@export var drag: float = 4.0
@export var max_speed: float = 32.0
## Hard cap for boosts and stunt bursts, as a multiple of max_speed.
@export var boost_cap: float = 1.6
## Speed above max_speed bleeds off at this rate (m/s per second).
@export var boost_decay: float = 5.0
@export var boost_speed: float = 8.0
@export var slope_gravity: float = 0.6
@export var reverse_speed: float = 8.0
@export var goo_speed: float = 7.0
@export var goo_drag: float = 40.0
@export var spin_rate: float = 9.5
@export var twist_rate: float = 7.0
## Released twists / z-flips glide to the nearest landable angle (rad/s).
@export var twist_snap: float = 7.0
@export var zflip_snap: float = 6.0
## Landing tolerance (degrees) away from a whole half-twist / full z-flip.
@export var twist_tolerance: float = 60.0
@export var zflip_tolerance: float = 55.0
@export var zflip_rate: float = 8.0
@export var auto_level: float = 2.5
@export var align_rate: float = 25.0
@export var jump_speed: float = 10.0
@export var pump_boost: float = 3.0
## Speed added per trick landed cleanly.
@export var trick_boost: float = 5.0
@export var crash_angle: float = 55.0
@export var hard_landing: float = 30.0
@export var recover_time: float = 1.2
@export var cruise_speed: float = 20.0
@export var wheel_radius: float = 0.65
@export var air_timeout: float = 6.0
@export var camera_distance: float = 24.0
@export var camera_height: float = 2.5
@export var camera_lead: float = 7.0
@export var camera_follow: float = 5.0
@export var reset_offset: float = 3.0
@export var gate_min_speed: float = 0.5
