extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -500.0 # Độ cao khi nhảy

# Lấy trọng lực từ hệ thống của Godot
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	# Thêm trọng lực nếu không đứng trên sàn
	if not is_on_floor():
		velocity.y += gravity * delta

	# Xử lý nhảy
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Lấy hướng di chuyển (Trái/Phải)
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	# Code đẩy các vật thể vật lý
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider() is RigidBody2D:
			# Truyền lực đẩy dựa trên vận tốc của người chơi
			collision.get_collider().apply_central_impulse(velocity * 0.5)
