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
var meteor_to_alert: Dictionary = {} # Ánh xạ Meteor -> Sprite2D (cảnh báo)

func _ready() -> void:
	# 1. Thu thập tất cả các node Meteor (Area2D), Hố (Sprite2D) và Cảnh báo
	var holes: Array[Sprite2D] = []
	var alerts: Array[Sprite2D] = []
	
	# Tìm AlertZone
	var alert_zone = get_node_or_null("AlertZone")
	if alert_zone:
		for child in alert_zone.get_children():
			if child is Sprite2D:
				alerts.append(child)
				child.visible = false

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
	
	# Ghép đôi Meteor với Hố và Cảnh báo gần nhất
	for m in meteors:
		# Ghép hố
		var closest_hole = null
		var min_dist_hole = 999999.0
		for h in holes:
			var dist = m.global_position.distance_to(h.global_position)
			if dist < min_dist_hole:
				min_dist_hole = dist
				closest_hole = h
		if closest_hole:
			meteor_to_hole[m] = closest_hole
			
		# Ghép cảnh báo
		var closest_alert = null
		var min_dist_alert = 999999.0
		for a in alerts:
			var dist = m.global_position.distance_to(a.global_position)
			if dist < min_dist_alert:
				min_dist_alert = dist
				closest_alert = a
		if closest_alert:
			meteor_to_alert[m] = closest_alert
	
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
		var selected_meteors = []
		for i in range(spawn_count):
			selected_meteors.append(available_meteors[i])
		
		# HIỂN THỊ CẢNH BÁO TRƯỚC 3 GIÂY
		for m in selected_meteors:
			_show_alert(m)
		
		# Đợi 3 giây trước khi rơi thiên thạch
		await get_tree().create_timer(3.0).timeout
		
		for m in selected_meteors:
			_activate_meteor(m)

# --- HIỂN THỊ CẢNH BÁO ---
func _show_alert(meteor: Area2D) -> void:
	if meteor_to_alert.has(meteor):
		var alert = meteor_to_alert[meteor]
		alert.visible = true
		alert.modulate.a = 1.0
		
		# HIỆU ỨNG NHẤP NHÁY NHANH + GLOW (Phát sáng)
		# Tốc độ: 0.1s cho mỗi pha (0.2s cho 1 chu kỳ), 15 chu kỳ = 3 giây
		var blink_tween = create_tween().set_loops(15) 
		
		# Pha 1: Làm mờ và giảm độ sáng
		blink_tween.tween_property(alert, "modulate:a", 0.3, 0.1)
		blink_tween.parallel().tween_property(alert, "self_modulate", Color(1, 1, 1, 1), 0.1)
		
		# Pha 2: Hiện rõ và phát sáng (Glow) bằng cách tăng self_modulate vượt mức 1.0 (nếu có HDR)
		blink_tween.tween_property(alert, "modulate:a", 0.3, 0.1)
		blink_tween.parallel().tween_property(alert, "self_modulate", Color(2.5, 2.5, 2.5, 1), 0.1)
		
		await get_tree().create_timer(3.0).timeout
		alert.visible = false
		alert.self_modulate = Color(1, 1, 1, 1) # Reset lại độ sáng mặc định

# --- KÍCH HOẠT THIÊN THẠCH ---
func _activate_meteor(meteor: Area2D) -> void:
	var target_pos = meteor.global_position
	
	# KHÔNG GÂY SÁT THƯƠNG KHI ĐANG RƠI (Chỉ làm cảnh)
	meteor.monitoring = false
	meteor.monitorable = false
	
	# 1. Hiệu ứng rơi bằng AnimationPlayer từ scene Fire_SheetSprite
	if meteor_scene:
		var m_instance = meteor_scene.instantiate()
		add_child(m_instance)
		var animation_offset = Vector2(0, 237)
		m_instance.global_position = target_pos - animation_offset
		
		var anim_player = m_instance.find_child("fall", true, false)
		if anim_player:
			anim_player.play("Fall")
			# Đợi đến khi chạm đất
			await get_tree().create_timer(0.2133).timeout
		else:
			await get_tree().create_timer(0.24).timeout
		
		m_instance.queue_free()
	
	# 2. VA CHẠM (IMPACT) VÀ NỔ - ĐÂY MỚI LÀ LÚC GÂY CHẾT
	meteor.monitoring = true
	meteor.monitorable = true
	_check_and_kill_overlapping(meteor)
	
	# A. Hiện hố
	if meteor_to_hole.has(meteor):
		var hole = meteor_to_hole[meteor]
		hole.visible = true
		hole.modulate.a = 0.0
		var hole_tween = create_tween()
		hole_tween.tween_property(hole, "modulate:a", 0.8, 0.1) 
		hole_tween.tween_property(hole, "modulate:a", 1.0, 0.05)
	
	# B. Tạo hiệu ứng nổ
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = target_pos
		add_child(explosion)
		if explosion.has_node("AnimationPlayer"):
			var exp_anim = explosion.get_node("AnimationPlayer")
			exp_anim.play("Explosion")
			exp_anim.animation_finished.connect(func(_anim): explosion.queue_free())
	
	# C. Giữ collision thêm một chút lúc nổ để diệt những ai đứng gần
	_check_and_kill_overlapping(meteor)
	await get_tree().create_timer(0.4).timeout
	
	# Tắt collision sau khi nổ xong (hố trang trí)
	meteor.monitoring = false
	meteor.monitorable = false
	
	# 3. Xử lý hố tồn tại rồi mờ dần
	if meteor_to_hole.has(meteor):
		var hole = meteor_to_hole[meteor]
		await get_tree().create_timer(active_duration + 3.0).timeout
		var fade_out = create_tween()
		fade_out.tween_property(hole, "modulate:a", 0.0, 1.5)
		await fade_out.finished
		hole.visible = false

# Hàm bổ trợ kiểm tra và diệt những ai đang đứng trong vùng va chạm
func _check_and_kill_overlapping(meteor: Area2D) -> void:
	if not meteor.monitoring: return
	var bodies = meteor.get_overlapping_bodies()
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
	for a in meteor_to_alert.values():
		a.visible = false
		a.modulate.a = 0.0

# --- XỬ LÝ KHI NGƯỜI CHƠI CHẠM VÀO ---
func _on_meteor_body_entered(body: Node) -> void:
	if body == null: return
	
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
		if player_node.has_method("burn_death"):
			# Gọi hiệu ứng chết cháy bằng shader mới
			player_node.burn_death()
		else:
			# Nếu không có hiệu ứng, xóa ngay lập tức như cũ
			if player_node.has_method("apply_damage"):
				player_node.apply_damage(9999)
			
			var root_to_delete = player_node
			if player_node.get_parent() and ("Player" in player_node.get_parent().name or player_node.get_parent().is_in_group("Player")):
				root_to_delete = player_node.get_parent()
			root_to_delete.queue_free()


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
