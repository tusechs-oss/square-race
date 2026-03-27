extends Node2D

# --- HỆ THỐNG THIÊN THẠCH (METEOR SYSTEM) ---
# Cơ chế: Mỗi 20 giây sẽ chọn ngẫu nhiên 3 vị trí thiên thạch để xuất hiện.
# Thiên thạch sẽ tồn tại trong 5 giây rồi biến mất.
# Nếu người chơi chạm vào thiên thạch đang hoạt động sẽ bị tiêu diệt ngay lập tức.

@export var spawn_interval := 20.0 # Khoảng thời gian giữa mỗi lần xuất hiện (20s)
@export var active_duration := 5.0 # Thời gian thiên thạch tồn tại (5s)
@export var explosion_scene: PackedScene = preload("res://Explosion.tscn")
@export var meteor_scene: PackedScene = preload("res://Fire_SheetSprite.tscn")

@onready var timer: Timer = $Timer
var meteors: Array[Area2D] = []
var meteor_to_hole: Dictionary = {} # Ánh xạ Meteor -> Sprite2D (hố)

func _ready() -> void:
	# 1. Thu thập tất cả các node Meteor (Area2D) và Hố (Sprite2D)
	var holes: Array[Sprite2D] = []
	for child in get_children():
		if child is Area2D:
			meteors.append(child)
			
			# FIX VỊ TRÍ: Chuyển vị trí của CollisionShape lên node cha (Area2D) 
			# để Area2D có global_position chính xác (không còn là 0,0)
			for subchild in child.get_children():
				if subchild is CollisionShape2D:
					var shape_pos = subchild.position
					child.position += shape_pos
					subchild.position = Vector2.ZERO # Reset về tâm của Area2D
			
			# Đảm bảo Area2D có thể phát hiện Layer 1 (Player)
			child.collision_layer = 0 
			child.collision_mask = 1  
			
			# Mặc định ẩn lúc bắt đầu
			child.visible = false
			child.monitoring = false
			child.monitorable = false
			
			# Kết nối tín hiệu va chạm
			if not child.body_entered.is_connected(_on_meteor_body_entered):
				child.body_entered.connect(_on_meteor_body_entered)
		elif child is Sprite2D and child.name.to_lower().contains("hole"):
			holes.append(child)
			child.visible = false
			child.modulate.a = 0.0 # Bắt đầu bằng độ mờ 0
	
	# Ghép đôi Meteor với Hố gần nhất
	for m in meteors:
		var closest_hole = null
		var min_dist = 999999.0
		for h in holes:
			var dist = m.global_position.distance_to(h.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_hole = h
		if closest_hole:
			meteor_to_hole[m] = closest_hole
	
	_hide_all_meteors() # Đảm bảo mọi thứ ẩn lúc bắt đầu
	
	# 2. Cấu hình Timer 20 giây
	if timer:
		timer.wait_time = spawn_interval
		timer.one_shot = false
		if not timer.timeout.is_connected(_on_spawn_timer_timeout):
			timer.timeout.connect(_on_spawn_timer_timeout)
		timer.start()

# --- XỬ LÝ KHI ĐẾN GIỜ SPAWN ---
func _on_spawn_timer_timeout() -> void:
	# Ẩn tất cả thiên thạch cũ (nếu còn)
	_hide_all_meteors()
	
	# Chọn ngẫu nhiên 3 thiên thạch từ danh sách
	if meteors.size() > 0:
		var available_meteors = meteors.duplicate()
		available_meteors.shuffle() # Trộn ngẫu nhiên
		
		var spawn_count = min(3, available_meteors.size())
		for i in range(spawn_count):
			var m = available_meteors[i]
			_activate_meteor(m)

# --- KÍCH HOẠT THIÊN THẠCH ---
func _activate_meteor(meteor: Area2D) -> void:
	var target_pos = meteor.global_position
	
	# BẮT ĐẦU GÂY SÁT THƯƠNG NGAY KHI BẮT ĐẦU RƠI
	meteor.monitoring = true
	meteor.monitorable = true
	# Kiểm tra ngay lập tức xem có ai đang đứng ở điểm rơi không
	_check_and_kill_overlapping(meteor)
	
	# 1. Hiệu ứng rơi bằng AnimationPlayer từ scene Fire_SheetSprite
	if meteor_scene:
		var m_instance = meteor_scene.instantiate()
		add_child(m_instance)
		
		# BÙ TRỪ VỊ TRÍ: Animation 'Fall' trong Fire_SheetSprite kết thúc tại y = 237
		# Chúng ta cần đặt instance sao cho điểm kết thúc này trùng với target_pos
		var animation_offset = Vector2(0, 237)
		m_instance.global_position = target_pos - animation_offset
		
		var anim_player = m_instance.find_child("fall", true, false)
		if anim_player:
			anim_player.play("Fall")
			# Trong lúc đang rơi, vẫn liên tục kiểm tra va chạm
			var fall_timer = 0.0
			while fall_timer < 0.2133:
				_check_and_kill_overlapping(meteor)
				await get_tree().physics_frame # Dùng physics_frame để chính xác hơn về va chạm
				fall_timer += get_physics_process_delta_time()
		else:
			await get_tree().create_timer(0.24).timeout
		
		m_instance.queue_free()
	
	# 2. Va chạm (Impact) và Nổ
	# A. Hiện hố
	if meteor_to_hole.has(meteor):
		var hole = meteor_to_hole[meteor]
		hole.visible = true
		hole.modulate.a = 0.0
		var hole_tween = create_tween()
		# Hiện SIÊU NHANH lên 0.8 trong 0.1 giây và 1.0 trong 0.05 giây (tổng cộng 0.15s)
		hole_tween.tween_property(hole, "modulate:a", 0.8, 0.7) 
		hole_tween.tween_property(hole, "modulate:a", 1.0, 0.2)
	
	# B. Tạo hiệu ứng nổ
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = target_pos
		add_child(explosion)
		if explosion.has_node("AnimationPlayer"):
			var exp_anim = explosion.get_node("AnimationPlayer")
			exp_anim.play("Explosion")
			exp_anim.animation_finished.connect(func(_anim): explosion.queue_free())
	
	# C. Giữ collision trong suốt thời gian hố tồn tại
	_check_and_kill_overlapping(meteor)
	
	# 3. Đợi hố tồn tại (active_duration) và liên tục gây sát thương
	var hole_timer = 0.0
	while hole_timer < active_duration:
		_check_and_kill_overlapping(meteor)
		await get_tree().physics_frame
		hole_timer += get_physics_process_delta_time()
	
	# Tắt collision và ẩn hố sau khi hết thời gian
	meteor.monitoring = false
	meteor.monitorable = false
	
	if meteor_to_hole.has(meteor):
		var hole = meteor_to_hole[meteor]
		hole.visible = false
		hole.modulate.a = 0.0

# Hàm bổ trợ kiểm tra và diệt những ai đang đứng trong vùng va chạm
func _check_and_kill_overlapping(meteor: Area2D) -> void:
	if not meteor.monitoring: return
	var bodies = meteor.get_overlapping_bodies()
	if bodies.size() > 0:
		print("Meteor ", meteor.name, " overlapping with: ", bodies.size(), " bodies")
	for body in bodies:
		_on_meteor_body_entered(body)

# --- ẨN TẤT CẢ THIÊN THẠCH ---
func _hide_all_meteors() -> void:
	for m in meteors:
		m.monitoring = false
		m.monitorable = false
	for h in meteor_to_hole.values():
		h.visible = false
		h.modulate.a = 0.0

# --- XỬ LÝ KHI NGƯỜI CHƠI CHẠM VÀO ---
func _on_meteor_body_entered(body: Node) -> void:
	if body == null: return
	
	# --- DEBUG SIÊU CHI TIẾT ---
	print("!!! VA CHẠM THIÊN THẠCH !!!")
	print("- Tên node va chạm: ", body.name)
	print("- Các nhóm của node: ", body.get_groups())
	if body.get_parent():
		print("- Tên node cha: ", body.get_parent().name)
		print("- Các nhóm của node cha: ", body.get_parent().get_groups())
	
	# Kiểm tra tất cả các khả năng để tìm Player
	var player_node = null
	
	# 1. Kiểm tra chính nó
	if body.is_in_group("Player"):
		player_node = body
	# 2. Kiểm tra node cha (thường RigidBody2D là con của Node2D "Player")
	elif body.get_parent() and body.get_parent().is_in_group("Player"):
		player_node = body.get_parent()
	# 3. Kiểm tra các node con (đôi khi va chạm trả về node cha)
	else:
		for child in body.get_children():
			if child.is_in_group("Player"):
				player_node = child
				break
	
	# 4. Kiểm tra theo tên (Dự phòng nếu group bị lỗi)
	if not player_node:
		if "Player" in body.name:
			player_node = body
		elif body.get_parent() and "Player" in body.get_parent().name:
			player_node = body.get_parent()

	if player_node:
		print("=> ĐÃ TÌM THẤY PLAYER: ", player_node.name)
		if player_node.has_method("apply_damage"):
			print("=> Đang gây sát thương cho: ", player_node.name)
			player_node.apply_damage(9999)
			
		# Xóa toàn bộ cụm Player để chắc chắn chết
		var root_to_delete = player_node
		if player_node.get_parent() and ("Player" in player_node.get_parent().name or player_node.get_parent().is_in_group("Player")):
			root_to_delete = player_node.get_parent()
			
		print("=> Đang xóa node: ", root_to_delete.name)
		root_to_delete.queue_free()
	else:
		print("=> KHÔNG TÌM THẤY GROUP 'Player' TRONG VA CHẠM NÀY")


func _on_meteor_2_body_entered(body: Node2D) -> void:
	_on_meteor_body_entered(body)

func _on_meteor_3_body_entered(body: Node2D) -> void:
	_on_meteor_body_entered(body)

func _on_meteor_4_body_entered(body: Node2D) -> void:
	_on_meteor_body_entered(body)

func _on_meteor_5_body_entered(body: Node2D) -> void:
	_on_meteor_body_entered(body)

func _on_meteor_6_body_entered(body: Node2D) -> void:
	_on_meteor_body_entered(body)

func _on_meteor_7_body_entered(body: Node2D) -> void:
	_on_meteor_body_entered(body)

func _on_meteor_8_body_entered(body: Node2D) -> void:
	_on_meteor_body_entered(body)

func _on_meteor_9_body_entered(body: Node2D) -> void:
	_on_meteor_body_entered(body)

func _on_meteor_10_body_entered(body: Node2D) -> void:
	_on_meteor_body_entered(body)
