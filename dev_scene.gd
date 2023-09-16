extends Node3D

var navigation_curve: Curve3D


func _ready():
	navigation_curve = $Game/dev_track.navigation_path.curve
	$AI/AICar.driving_curve = navigation_curve


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_set_info(t):
	%Info.text = t
