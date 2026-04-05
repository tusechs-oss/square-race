extends Node2D

func _ready():
	# Play spawn animation if exists
	if has_node("purple/AnimationPlayer"):
		$purple/AnimationPlayer.play("spawngojo")
	
	# Connect signal for pickup
	if has_node("Area2D"):
		$Area2D.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("Player") and body.has_method("pick_up_gojo"):
		body.pick_up_gojo()
		queue_free()
