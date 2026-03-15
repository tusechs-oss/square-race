extends Marker2D

@export var gun_scene : PackedScene 
func _on_spawn_timer_timeout() -> void:
	if gun_scene: 
		var new_gun = gun_scene.instantiate() 
		new_gun.global_position = global_position 
		get_tree().current_scene.add_child(new_gun) 
		
		print("Da spawn sung tai: ", global_position) 
