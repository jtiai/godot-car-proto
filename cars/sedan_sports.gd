extends VehicleBody3D

signal change_camera(t: Node, i: bool)
signal set_info(t: String)

@export var MAX_ENGINE_FORCE = 700.0
@export var MAX_BRAKE_FORCE = 50.0
@export var MAX_STEER_ANGLE = 0.5

@export var steer_speed = 0.8
@export var final_drive_ratio = 3.38
@export var reverse_ratio = -2.5
@export var gear_ratios: Array[float] = [ 4.0, 3.0, 2.0, 1.5, 1.0, 0.5 ]
@export var max_engine_rpm = 8000.0
@export var power_curve: Curve

var steer_target: float = 0.0
var steer_angle: float = 0.0
var current_speed_mps: float = 0.0
var rpm: float = 0.0
var clutch_position: float = 1.0  # 0 = disengaged, 1 = engaged
var ground_multiplier: float = 1.0

var gear_shift_time: float = 0.3
var clutch_timer: float = 0.0
var gear_timer: float= 0.0

@onready var cameras: Array[Node] = [
	$CameraTargets/ChaseClose,
	$CameraTargets/RightSide,
	$CameraTargets/Top,
]

@onready var last_pos = position
@onready var reference_wheel := $rearLeft

@export var current_camera: int = 0

@onready var wheels: Array[Node] = [
	$frontLeft,
	$frontRight,
	$rearLeft,
	$rearRight,
]

var current_gear: int = 0

func _ready():
	emit_signal("change_camera", cameras[current_camera], true)

func _process(delta):
	_process_gears(delta)

	emit_signal("set_info", "Speed: %d   RPM: %d  G: %d  T: %.05f" % [int(get_speed_as_kph()), int(rpm), current_gear, ground_multiplier])


func _physics_process(delta):
	var steer_val = Input.get_axis("steer_right", "steer_left")  # Must be reverse
	var throttle_val = Input.get_action_strength("accelerate")
	var brake_val = Input.get_action_strength("brake")

	current_speed_mps = (position - last_pos).length() / delta
	ground_multiplier = get_ground_multiplier()

	rpm = engine_rpm()
	var rpm_factor = clampf(rpm / max_engine_rpm, 0.0, 1.0)
	var power_factor = power_curve.sample_baked(rpm_factor)

	if current_gear == -1:
		engine_force = clutch_position * throttle_val * power_factor * reverse_ratio * final_drive_ratio * MAX_ENGINE_FORCE * ground_multiplier
	elif current_gear > 0 and current_gear <= gear_ratios.size():
		engine_force = clutch_position * throttle_val * power_factor * gear_ratios[current_gear - 1] * final_drive_ratio * MAX_ENGINE_FORCE * ground_multiplier
	else:
		engine_force = 0.0

	brake = brake_val * MAX_BRAKE_FORCE

	steer_target = steer_val * MAX_STEER_ANGLE

	if steer_target < steer_angle:
		steer_angle -= steer_speed * delta
	elif steer_target > steer_angle:
		steer_angle += steer_speed * delta

	steering = clampf(steer_angle, -MAX_STEER_ANGLE, MAX_STEER_ANGLE)

	last_pos = position


func _input(_event):
	if Input.is_action_just_pressed("change_camera"):
		current_camera = wrapi(current_camera + 1, 0, cameras.size())
		emit_signal("change_camera", cameras[current_camera], false)

func _process_gears(delta):
	if gear_timer > 0.0:
		gear_timer = max(0.0, gear_timer - delta)
		clutch_position = 0.0
	else:
		if Input.is_action_just_pressed("gear_up") and current_gear < gear_ratios.size():
			current_gear += 1
			gear_timer = gear_shift_time
			clutch_position = 0.0
		elif Input.is_action_just_pressed("gear_down") and current_gear > -1:
			current_gear -= 1
			clutch_position = 0.0
		else:
			clutch_position = 1.0

		current_gear = clampi(current_gear, -1, gear_ratios.size()-1)


func get_ground_multiplier() -> float:
	var multiplier := 0.0
	var contacts := false

	for wheel in wheels:
		var contact_body: Node3D = wheel.get_contact_body()
		if contact_body:
			contacts = true
			multiplier += contact_body.terrain_multiplier

	if not contacts:
		return 1.0

	return multiplier / wheels.size()

func get_speed_as_kph() -> float:
	return current_speed_mps * 3600.0 / 1000.0


func engine_rpm() -> float:
	# if we are in neutral, no rpm
	if current_gear == 0:
		return 0.0


	var drive_shaft_rotation_speed : float = reference_wheel.get_rpm() * final_drive_ratio
	if current_gear == -1:
		# we are in reverse
		return drive_shaft_rotation_speed * -reverse_ratio
	elif current_gear <= gear_ratios.size():
		return drive_shaft_rotation_speed * gear_ratios[current_gear - 1]
	else:
		return 0.0
