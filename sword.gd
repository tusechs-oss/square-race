extends Node2D

func _on_body_entered(body):
	if body.is_in_group("Player"):
		if body.has_method("pick_up_sword"):
			body.pick_up_sword()
			queue_free()
