extends Area2D

@export var bounce_impulse := 1500.0 # Lực đẩy bật ra tức thì
@export var wind_force := 4500.0
@export var wind_direction := Vector2(-1, 0) # Hướng gió đẩy (Vector2.LEFT = -1,0; Vector2.RIGHT = 1,0)
@export var turbulence_strength := 300.0

func _ready() -> void:
	# Ẩn mặc định, sẽ hiện khi có gió
	visible = false
	monitoring = false
	monitorable = false
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func set_wind_direction(dir: Vector2) -> void:
	wind_direction = dir

func activate_wind(duration: float = 8.0) -> void:
	visible = true
	monitoring = true
	monitorable = true
	
	# Sau một khoảng thời gian thì tắt gió
	await get_tree().create_timer(duration).timeout
	visible = false
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
