extends Area2D

@export var gun_type : String = "Pistol" 

func _ready():
	pass
func _on_body_entered(body):
	if body.is_in_group("Player"):
		if body.has_method("pick_up_gun"):
			body.pick_up_gun()
			queue_free()
