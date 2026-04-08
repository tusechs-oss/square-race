extends Area2D

@export var bounce_impulse := 1500.0 # Lực đẩy bật ra tức thì
@export var wind_force := 4500.0
@export var wind_direction := Vector2(-1, 0) # Hướng gió đẩy (Vector2.LEFT = -1,0; Vector2.RIGHT = 1,0)
@export var turbulence_strength := 300.0

@onready var warning_sprite = get_node_or_null("Sprite2D")
@onready var wind_visual = get_node_or_null("windreg")
@onready var color_rect = get_node_or_null("ColorRect")

var tornado_scene = preload("res://tornado.tscn")

func _ready() -> void:
	# Ẩn mặc định ngay khi vào game
	visible = true 
	monitoring = false
	monitorable = false
	
	if warning_sprite:
		warning_sprite.hide()
	if wind_visual:
		wind_visual.hide()
	
	# Tìm và ẩn mọi ColorRect bên trong (kể cả ColorRect2)
	for child in get_children():
		if child is ColorRect:
			child.hide()
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func set_wind_direction(dir: Vector2) -> void:
	wind_direction = dir

func activate_wind(duration: float = 8.0) -> void:
	# --- BƯỚC 1: CẢNH BÁO NHẤP NHÁY (3 GIÂY) ---
	var all_color_rects = []
	for child in get_children():
		if child is ColorRect:
			all_color_rects.append(child)
			child.show()
			
	if warning_sprite: warning_sprite.show()
	if wind_visual: wind_visual.show()
	
	# Nháy nhanh hơn (0.1s mỗi pha)
	var tween = create_tween().set_loops(15)
	
	# Pha HIỆN
	if warning_sprite:
		tween.tween_property(warning_sprite, "modulate:a", 1.0, 0.1).from(0.2)
		# Tăng nhẹ Glow cho Icon
		tween.parallel().tween_property(warning_sprite, "self_modulate", Color(1.9, 1.6, 0.4, 1.0), 0.1)
		
	for cr in all_color_rects:
		# Tăng nhẹ Glow cho ColorRect
		tween.parallel().tween_callback(func(): 
			cr.show()
			cr.self_modulate = Color(1.9, 1.6, 0.3, 1.0) 
		)
	if wind_visual:
		tween.parallel().tween_callback(func(): wind_visual.show())
		
	# Pha ẨN
	if warning_sprite:
		tween.tween_property(warning_sprite, "modulate:a", 0.2, 0.1)
		tween.parallel().tween_property(warning_sprite, "self_modulate", Color(1, 1, 1, 1), 0.1)
		
	for cr in all_color_rects:
		tween.parallel().tween_callback(func(): 
			cr.hide()
			cr.self_modulate = Color(1, 1, 1, 1) 
		)
	if wind_visual:
		tween.parallel().tween_callback(func(): wind_visual.hide())
	
	await tween.finished
	
	# Đảm bảo ẩn hoàn toàn sau khi cảnh báo xong
	if warning_sprite: 
		warning_sprite.hide()
		warning_sprite.modulate.a = 1.0
	if wind_visual: wind_visual.hide()
	for cr in all_color_rects:
		cr.hide()
	
	# --- BƯỚC 1.5: SPAWN TORNADO ---
	if tornado_scene:
		# Chỉ spawn duy nhất 1 cái lốc xoáy
		var tornado = tornado_scene.instantiate()
		# Cho nó to thêm một chút (scale 0.45)
		tornado.scale = Vector2(0.45, 0.45)
		
		if color_rect:
			var rect = color_rect.get_global_rect()
			# Spawn cố định ngay chính giữa vùng cảnh báo (alert)
			tornado.global_position = rect.position + rect.size / 2.0
		else:
			tornado.global_position = global_position
			
		# Phát âm thanh wind từ node có sẵn trong main
		var main_wind_node = get_tree().current_scene.get_node_or_null("wind")
		if main_wind_node:
			main_wind_node.global_position = tornado.global_position
			main_wind_node.play()
			
		get_tree().current_scene.add_child(tornado)
	
	# --- BƯỚC 2: KÍCH HOẠT GIÓ ---
	monitoring = true
	monitorable = true
	
	# Sau một khoảng thời gian thì tắt gió
	await get_tree().create_timer(duration).timeout
	
	# Dừng âm thanh khi hết thời gian lốc xoáy
	var main_wind_node_stop = get_tree().current_scene.get_node_or_null("wind")
	if main_wind_node_stop:
		main_wind_node_stop.stop()
	
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
