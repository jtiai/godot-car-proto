extends Node3D


# Units per second
@export var drive_speed: float = 50.0

var driving_curve: Curve3D:
	get:
		return driving_curve
	set(value):
		driving_curve = value
		drive_length = driving_curve.get_baked_length()
		drive_distance = driving_curve.get_closest_offset(global_position)

var drive_length: float = 0.0
var drive_distance: float = 0.0
var speed_mps: float = 0.0


func _ready():
	speed_mps = drive_speed / 3600.0 * 1000.0


func _physics_process(delta):
	if drive_length == 0.0:
		return

	drive_distance = wrapf(drive_distance + speed_mps * delta, 0.0, drive_length)

	var target: Vector3 = driving_curve.sample_baked(drive_distance)

	look_at(target)
	global_position = target
