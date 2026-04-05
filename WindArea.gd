extends Area2D

@export var bounce_impulse := 1500.0 # Lực đẩy bật ra tức thì
@export var wind_force := 4500.0
@export var wind_direction := Vector2(-1, 0) # Hướng gió đẩy (Vector2.LEFT = -1,0; Vector2.RIGHT = 1,0)
@export var turbulence_strength := 300.0

@onready var warning_sprite = get_node_or_null("Sprite2D")
@onready var wind_visual = get_node_or_null("windreg")

func _ready() -> void:
	# Ẩn mặc định
	visible = true # Để các node con có thể điều khiển hiển thị riêng
	monitoring = false
	monitorable = false
	
	if warning_sprite:
		warning_sprite.visible = false
	if wind_visual:
		wind_visual.visible = false
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func set_wind_direction(dir: Vector2) -> void:
	wind_direction = dir

func activate_wind(duration: float = 8.0) -> void:
	# --- BƯỚC 1: CẢNH BÁO NHẤP NHÁY (3 GIÂY) ---
	if warning_sprite or wind_visual:
		if warning_sprite: warning_sprite.visible = true
		if wind_visual: wind_visual.visible = true
		
		# Hiệu ứng nhấp nháy nhanh + Glow giảm xuống (1.5 thay vì 2.5 để không bị chói)
		var tween = create_tween().set_loops(15) # 0.1s * 2 * 15 = 3s
		
		# Pha 1: Mờ đi
		if warning_sprite:
			tween.tween_property(warning_sprite, "modulate:a", 0.2, 0.1)
			tween.parallel().tween_property(warning_sprite, "self_modulate", Color(1, 1, 1, 1), 0.1)
		if wind_visual:
			# Nếu wind_visual là CollisionShape thì dùng visible, nếu là CanvasItem thì dùng modulate
			if wind_visual is CanvasItem:
				tween.parallel().tween_property(wind_visual, "modulate:a", 0.1, 0.1)
			else:
				tween.parallel().tween_callback(func(): wind_visual.visible = false).set_delay(0.1)
		
		# Pha 2: Hiện rõ + Glow nhẹ
		if warning_sprite:
			tween.tween_property(warning_sprite, "modulate:a", 1.0, 0.1)
			tween.parallel().tween_property(warning_sprite, "self_modulate", Color(1.5, 1.5, 1.5, 1), 0.1)
		if wind_visual:
			if wind_visual is CanvasItem:
				tween.parallel().tween_property(wind_visual, "modulate:a", 0.7, 0.1)
			else:
				tween.parallel().tween_callback(func(): wind_visual.visible = true).set_delay(0.1)
		
		await get_tree().create_timer(3.0).timeout
		
		# Kết thúc cảnh báo - ẨN TẤT CẢ VÙNG VÀNG VÀ ICON
		if warning_sprite: 
			warning_sprite.visible = false
			warning_sprite.self_modulate = Color(1, 1, 1, 1)
		if wind_visual:
			wind_visual.visible = false
	
	# --- BƯỚC 2: KÍCH HOẠT GIÓ ---
	# Giữ wind_visual ẩn theo yêu cầu (để bạn tự thêm hiệu ứng sau)
	if wind_visual:
		wind_visual.visible = false
		
	monitoring = true
	monitorable = true
	
	# Sau một khoảng thời gian thì tắt gió
	await get_tree().create_timer(duration).timeout
	
	monitoring = false
	monitorable = false

func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		# TẠO CÚ HÍCH MẠNH TỨC THÌ (IMPULSE)
		# Đẩy mạnh theo hướng gió
		var impulse = wind_direction * bounce_impulse
		
		# Thêm một chút hướng lên trên để hộp bay bổng ra ngoài
		impulse.y = -400.0
		
		# Áp dụng lực đẩy tức thời để "bật" hộp ra ngay lập tức
		body.apply_central_impulse(impulse)
		
		# Tạo hiệu ứng xoay mạnh khi bị bật ra
		body.apply_torque_impulse(randf_range(-1000, 1000))

func _physics_process(delta: float) -> void:
	if not monitoring:
		return
		
	# DUY TRÌ LỰC ĐẨY ĐỂ HỘP KHÔNG QUAY LẠI
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body is RigidBody2D:
			# Tiếp tục đẩy theo hướng gió để hộp bay hẳn ra khỏi vùng này
			body.apply_central_force(wind_direction * wind_force)
			# Thêm một chút nhiễu để không bị kẹt
			body.apply_central_force(Vector2(0, randf_range(-turbulence_strength, turbulence_strength)))
