extends Node2D

# --- HỆ THỐNG THIÊN THẠCH (METEOR SYSTEM) ---
# Cơ chế: Mỗi 20 giây sẽ chọn ngẫu nhiên 3 vị trí thiên thạch để xuất hiện.
# Thiên thạch sẽ tồn tại trong 5 giây rồi biến mất.
# Nếu người chơi chạm vào thiên thạch đang hoạt động sẽ bị tiêu diệt ngay lập tức.

@export var spawn_interval := 20.0 # Khoảng thời gian giữa mỗi lần xuất hiện (20s)
@export var active_duration := 5.0 # Thời gian thiên thạch tồn tại (5s)

@onready var timer: Timer = $Timer
var meteors: Array[Area2D] = []

func _ready() -> void:
	# 1. Thu thập tất cả các node Meteor (Area2D) trong Meteor_service
	for child in get_children():
		if child is Area2D:
			meteors.append(child)
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
		
		# Chờ 5 giây sau đó cho biến mất
		await get_tree().create_timer(active_duration).timeout
		_hide_all_meteors()

# --- KÍCH HOẠT THIÊN THẠCH ---
func _activate_meteor(meteor: Area2D) -> void:
	meteor.visible = true
	meteor.monitoring = true
	meteor.monitorable = true

# --- ẨN TẤT CẢ THIÊN THẠCH ---
func _hide_all_meteors() -> void:
	for m in meteors:
		m.visible = false
		m.monitoring = false
		m.monitorable = false

# --- XỬ LÝ KHI NGƯỜI CHƠI CHẠM VÀO ---
func _on_meteor_body_entered(body: Node) -> void:
	if body == null: return
	
	# Kiểm tra trực tiếp node, cha, và con để tìm nhóm "Player"
	var player_node = null
	if body.is_in_group("Player"):
		player_node = body
	elif body.get_parent() and body.get_parent().is_in_group("Player"):
		player_node = body.get_parent()
	else:
		# Kiểm tra các node con (đôi khi va chạm trả về node con nếu cấu trúc phức tạp)
		for child in body.get_children():
			if child.is_in_group("Player"):
				player_node = child
				break
	
	if player_node:
		if player_node.has_method("apply_damage"):
			# Gây sát thương cực lớn
			player_node.apply_damage(999)
			# Kiểm tra lại nếu vẫn chưa chết thì xóa luôn
			if is_instance_valid(player_node):
				player_node.queue_free()
		elif player_node.has_method("queue_free"):
			player_node.queue_free()
		
		# Nếu là node cha bọc RigidBody thì xóa cả cụm
		var root = player_node.get_parent()
		if root and root.name == "Player" and root.has_method("queue_free"):
			root.queue_free()


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
