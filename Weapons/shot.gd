extends Node2D

var shooter: Node2D = null
@export var speed := 3000
var bullet_count := 0

func _process(delta):
	position += transform.x * speed * delta


func _on_bullet_body_entered(body: Node2D) -> void:
	# 1) Đụng tường thì xoá đạn
	if body.is_in_group("wall"):
		queue_free()
		return

	# 2) Bỏ qua chính người bắn
	if body == shooter:
		return

	# 3) Trúng Player khác → trừ máu bằng apply_damage(1)
	#    Chỉ khi apply_damage trả về true (tức chết) mới cộng kill + upload_score + xóa target
	if body.is_in_group("Player"):
		var dead := true
		if body.has_method("apply_damage"):
			dead = body.apply_damage(1)
		if dead:
			if body.has_method("upload_score"):
				body.upload_score()
			body.queue_free()

		# 4) Xử lý cho người bắn: chỉ cộng kill khi mục tiêu đã chết
		if shooter != null and dead:
			shooter.kill += 1
			if shooter.has_method("upload_score"):
				shooter.upload_score()
			
			# 5) Hiệu ứng máu bắn ra tại vị trí va chạm (nếu đạn có node BloodSplash con)
		if has_node("BloodSplash"):
			var blood = $BloodSplash
			
			# Nhấc node máu ra khỏi đạn, gắn vào scene chính để tồn tại tới khi hiệu ứng kết thúc
			var main_scene = get_tree().current_scene
			remove_child(blood) 
			main_scene.add_child(blood) 
			
			# Đặt vị trí/rotation theo điểm va chạm
			blood.global_position = global_position
			blood.global_rotation = global_rotation
			
			# Kích hoạt hiệu ứng hạt
			blood.emitting = true
			
			# Tự xóa node máu sau khoảng 1 giây
			get_tree().create_timer(1.0).timeout.connect(blood.queue_free)
		# 6) Cuối cùng mới xóa viên đạn
		queue_free()
