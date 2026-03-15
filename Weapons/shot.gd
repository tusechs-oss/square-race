extends Node2D

var shooter: Node2D = null
@export var speed := 3000
var bullet_count := 0

func _process(delta):
	position += transform.x * speed * delta


func _on_bullet_body_entered(body: Node2D) -> void:
	# 1. Đụng tường thì xoá đạn
	if body.is_in_group("wall"):
		queue_free()
		return

	# 2. Bỏ qua chính người bắn
	if body == shooter:
		return

	# 3. Chỉ xử lý khi trúng Player khác
	if body.is_in_group("Player"):
		# Lưu lại vị trí kẻ địch bị bắn trúng trước khi xóa
		var death_pos = body.global_position
		
		# Cho kẻ địch upload điểm trước khi chết
		if body.has_method("upload_score"):
			body.upload_score()
		
		body.queue_free()

		# 4. Xử lý logic cho người bắn
		if shooter != null:
			shooter.kill += 1
			if shooter.has_method("upload_score"):
				shooter.upload_score() # Cập nhật điểm ngay lập tức cho người bắn
			
			# CHẠY HIỆU ỨNG BLOOD SPLASH
			# Lấy scene blood splash đã gán ở Player
		if has_node("BloodSplash"):
			var blood = $BloodSplash
			
			# Nhấc máu ra khỏi viên đạn để khi đạn bị xóa, máu vẫn còn chạy
			var main_scene = get_tree().current_scene
			# Xóa máu khỏi cha hiện tại (viên đạn)
			remove_child(blood) 
			# Gắn máu vào scene chính của game
			main_scene.add_child(blood) 
			
			# Đặt vị trí máu tại đúng điểm va chạm hiện tại
			blood.global_position = global_position
			blood.global_rotation = global_rotation
			
			# Kích hoạt hiệu ứng (Vì là CPUParticles2D)
			blood.emitting = true
			
			# Tự xóa node máu sau khi diễn xong (khoảng 1 giây)
			get_tree().create_timer(1.0).timeout.connect(blood.queue_free)
		# Cuối cùng mới xóa viên đạn
		queue_free()
