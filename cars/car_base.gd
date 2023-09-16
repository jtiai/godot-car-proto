extends CharacterBody3D

signal change_camera(t)
signal set_info(t)

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var gravity = -20
@export var wheel_base = 0.6
@export var steering_limit = 10.0
@export var engine_power = 6.0 * 4.0
@export var braking = -9.0
@export var friction = -2.0
@export var drag = -2.0
@export var max_speed_reverse = 3.0
@export var slip_speed = 9.0
@export var traction_slow = 0.75
@export var traction_fast = 0.02

@export var fixed_ratio: float = 4.0
@export var gear_ratios: Array[float] = [3.0, 2.0, 1.5, 1.0, 0.5]

var drifting = false
var acceleration = Vector3.ZERO
var steer_angle = 0.0
var current_gear = 1

func _ready():
	velocity = Vector3.ZERO
	emit_signal("change_camera", $CameraPositions/Behind)


func _physics_process(delta):

	if is_on_floor():
		get_input()
		apply_friction(delta)
		calculate_steering(delta)

	acceleration.y = gravity

	velocity += acceleration * delta
	emit_signal("set_info", "KPH: %d  RPM: %d   G: %d" % int(Vector2(velocity.x, velocity.z).length() * 3.6 * 4.0), 0, current_gear)

	floor_snap_length = transform.basis.y.length()
	move_and_slide()


func apply_friction(delta):
	if velocity.length() < 0.2 and acceleration.length() == 0:
		velocity.x = 0
		velocity.z = 0
	var friction_force = velocity * friction * delta
	var drag_force = velocity * velocity.length() * drag * delta
	acceleration += drag_force + friction_force


func calculate_steering(delta):
	var rear_wheel = transform.origin + transform.basis.z * wheel_base / 2.0
	var front_wheel = transform.origin - transform.basis.z * wheel_base / 2.0
	rear_wheel += velocity * delta
	front_wheel += velocity.rotated(transform.basis.y, steer_angle) * delta
	var new_heading = rear_wheel.direction_to(front_wheel)

	# traction
	if not drifting and velocity.length() > slip_speed:
		drifting = true
	if drifting and velocity.length() < slip_speed and steer_angle == 0:
		drifting = false
	var traction = traction_fast if drifting else traction_slow

	var d = new_heading.dot(velocity.normalized())
	if d > 0:
		velocity = lerp(velocity, new_heading * velocity.length(), traction)
	if d < 0:
		velocity = -new_heading * min(velocity.length(), max_speed_reverse)
	look_at(transform.origin + new_heading, transform.basis.y)


func get_input():
	var new_gear = current_gear
	if Input.is_action_just_pressed("gear_up"):
		new_gear += 1
	if Input.is_action_just_pressed("gear_down"):
		new_gear -= 1
	current_gear = clampi(new_gear, 1, gear_ratios.size())

	var turn = Input.get_axis("steer_right", "steer_left")
	steer_angle = lerp(steer_angle, turn * deg_to_rad(steering_limit), 0.05)
	$hatchbackSports2/wheel_frontRight.rotation.y = steer_angle*2
	$hatchbackSports2/wheel_frontLeft.rotation.y = steer_angle*2
	acceleration = Vector3.ZERO
	if Input.is_action_pressed("accelerate"):
		acceleration = -transform.basis.z * engine_power / (gear_ratios[current_gear - 1] * fixed_ratio)
	if Input.is_action_pressed("brake"):
		acceleration = -transform.basis.z * braking
