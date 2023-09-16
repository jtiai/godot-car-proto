extends Camera3D

@export var lerp_speed: float = 20.0

var target = null


func _physics_process(delta):
	if !target:
		return
	#global_transform = global_transform.interpolate_with(target.global_transform, lerp_speed * delta)
	global_transform = target.global_transform

func _on_change_camera(t: Node, i: bool):
	target = t
	if i:
		global_transform = t.global_transform
