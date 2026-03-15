extends RigidBody2D
@onready var bounce_sound = $BounceSound
@export var bullet_scene: PackedScene
@export var auto_aim_enabled := true
@export var auto_aim_max_distance := 800.0

enum WeaponType { NONE, GUN, SWORD }

@export var kill_splash_scene: PackedScene
var current_weapon: WeaponType = WeaponType.NONE
var current_target: Node2D = null # Biến lưu mục tiêu hiện tại
@onready var hand = $hand
@onready var gun_sprite = $hand/Gun        # sprite khẩu súng
@onready var sword_sprite = $hand/Sword    # sprite cây kiếm
@onready var shoot_timer = $hand/ShootTimer
@onready var muzzle = $hand/Muzzle
@onready var sword_hitbox = $hand/Sword/SwordHitbox
@onready var sword_timer = $hand.get_node_or_null("SwordTimer") # nếu muốn thêm Timer riêng cho kiếm
@onready var shake_camera = get_tree().get_first_node_in_group("camera_shake")
var sword_kills_left = 0
const GUN_PICKUP_DELAY = 1.0 # Chờ 1 giây sau khi nhặt súng mới được bắn
var gun_ready_at = 0.0 # Thời điểm (giây) được phép bắn
const MAX_AMMO = 2
var ammo = MAX_AMMO
var kill = 0
var player_name: String = ""
func _ready():
	# ẩn hết vũ khí khi spawn
	if gun_sprite:
		gun_sprite.hide()
	if sword_sprite:
		sword_sprite.hide()
	if sword_hitbox:
		sword_hitbox.monitoring = false
		sword_hitbox.monitorable = false

	add_to_group("Player")
	await get_tree().create_timer(0.1).timeout
	gravity_scale = 0
	linear_damp = 0

	var angle = randf_range(0, 2 * PI)
	var direction = Vector2(cos(angle), sin(angle))
	linear_velocity = direction * 400

func _on_body_entered(body):
	if bounce_sound:
		bounce_sound.play()
	# Tạo một chút độ lệch ngẫu nhiên từ -0.2 đến 0.2 radian (khoảng -10 đến 10 độ)
	var random_bounce_offset = randf_range(-0.2, 0.2)
	
	# Lấy hướng vận tốc hiện tại, xoay nhẹ nó đi một chút
	var current_dir = linear_velocity.angle()
	var new_dir = current_dir + random_bounce_offset
	
	# Áp dụng hướng mới nhưng vẫn giữ nguyên tốc độ 400
	linear_velocity = Vector2.RIGHT.rotated(new_dir) * 400
	
	# Hiệu ứng phụ: Thêm chút lực đẩy nhẹ để không bao giờ bị đứng im
	apply_central_impulse(linear_velocity.normalized() * 10)
	var state = PhysicsServer2D.body_get_direct_state(get_rid())
	
	if state.get_contact_count() > 0:
		var contact_pos = state.get_contact_local_position(0)
		$SparkParticles.global_position = contact_pos
		
		var normal = state.get_contact_local_normal(0)
		$SparkParticles.direction = normal
		
		$SparkParticles.emitting = true
		$SparkParticles.restart()

func get_target_from_area():
	if not $AutoAimArea: return null
	
	# SỬA LỖI: Gọi trực tiếp từ Area2D
	var targets = $AutoAimArea.get_overlapping_bodies()
	var closest_enemy = null
	var min_dist = INF
	
	for body in targets:
		# SỬA LỖI: Check đúng tên Group "Player" (viết hoa giống trong _ready)
		if body.is_in_group("Player") and body != self:
			var dist = global_position.distance_to(body.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_enemy = body
				
	return closest_enemy
func pick_up_gun():
	current_weapon = WeaponType.GUN
	ammo = MAX_AMMO  # Nạp đạn đầy mỗi khi nhặt súng
	# Chờ 1 giây mới được bắn
	gun_ready_at = Time.get_ticks_msec() / 1000.0 + GUN_PICKUP_DELAY
	if gun_sprite:
		gun_sprite.show()
	if sword_sprite:
		sword_sprite.hide()
		

func pick_up_sword():
	current_weapon = WeaponType.SWORD
	sword_kills_left = 1
	if sword_sprite:
		sword_sprite.show()
	if gun_sprite:
		gun_sprite.hide()
	# Bật SwordHitbox để phát hiện kẻ địch khi va chạm
	if sword_hitbox:
		sword_hitbox.monitoring = true
		sword_hitbox.monitorable = false

func _process(delta):
	if hand.global_rotation > PI/2 or hand.global_rotation < -PI/2:
	# Nếu súng đang chỉ sang bên trái
		gun_sprite.flip_v = true # Lật ngược cái ảnh súng lại để nó không bị lộn đầu
	# Nếu bạn có sprite tay, cũng flip luôn
	else:
	# Nếu súng đang chỉ sang bên phải
		gun_sprite.flip_v = false
	# 1. Quản lý mục tiêu (Giữ mục tiêu cho đến khi chết hoặc ra khỏi tầm)
	if is_instance_valid(current_target):
		var distance = global_position.distance_to(current_target.global_position)
		# Nếu mục tiêu đi quá xa tầm Area2D (ví dụ 800) thì bỏ qua
		if distance > auto_aim_max_distance:
			current_target = null
	else:
		current_target = get_target_from_area()

	# 2. Xoay 'hand' mượt mà về phía mục tiêu
	if current_weapon == WeaponType.GUN:
		if current_target and is_instance_valid(current_target):
			var target_dir = (current_target.global_position - global_position).normalized()
			var target_angle = target_dir.angle()
			hand.rotation = lerp_angle(hand.rotation, target_angle, 0.2)
	
	# KHI CẦM KIẾM (HOẶC KHÔNG CẦM GÌ): Ép nó đứng yên một góc
	else:
		# Bạn có thể để 0 (chỉ sang phải) hoặc deg_to_rad(90) (chỉ xuống dưới)
		hand.rotation = lerp_angle(hand.rotation, 0, 0.1)
	
	# 3. Logic vũ khí
	match current_weapon:
		WeaponType.GUN:
			if gun_sprite and gun_sprite.visible:
				auto_shoot()
func auto_shoot():
	if ammo <= 0:
		return
	# Chưa hết delay 1s sau khi nhặt súng thì chưa bắn
	if Time.get_ticks_msec() / 1000.0 < gun_ready_at:
		return
	if shoot_timer and shoot_timer.is_stopped():
		shoot()
		shoot_timer.start()

func shoot():
	if bullet_scene:
		if ammo <= 0:
			return
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		bullet.shooter = self
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = muzzle.global_position
		bullet.global_rotation = muzzle.global_rotation
		bullet.global_transform = muzzle.global_transform
		ammo -= 1
		if ammo <= 0:
			drop_gun()

func _on_sword_hitbox_body_entered(body: Node2D) -> void:
	_try_sword_kill(body)

func _check_sword_overlap_kill() -> void:
	if sword_kills_left <= 0:
		return
	if not sword_hitbox:
		return
	for body in sword_hitbox.get_overlapping_bodies():
		if _try_sword_kill(body):
			return

func _try_sword_kill(body: Node2D) -> bool:
	if sword_kills_left <= 0:
		return false
	if body == null or body == self:
		return false
	if not body.is_in_group("Player"):
		return false
	if body.has_method("queue_free"):
		kill += 1
		# Tạo splash effect tại vị trí kẻ bị chém (nếu đã gán scene trong Inspector)
		if kill_splash_scene:
			var splash := kill_splash_scene.instantiate()
			splash.global_position = body.global_position
			get_tree().current_scene.add_child(splash)
			# Trong KillSplash.tscn, AnimationPlayer nằm ở đường dẫn Sprite2D/AnimationPlayer
			var anim_player := splash.get_node_or_null("Sprite2D/AnimationPlayer")
			if anim_player is AnimationPlayer:
				anim_player.play("Splash") # tên animation trong KillSplash.tscn
		body.queue_free()
		sword_kills_left -= 1
		if shake_camera and shake_camera.has_method("add_trauma"):
			shake_camera.add_trauma(0.45)
		if sword_kills_left <= 0:
			_consume_sword()
		return true
	return false

func _consume_sword() -> void:
	current_weapon = WeaponType.NONE
	if sword_sprite:
		sword_sprite.hide()
	if sword_hitbox:
		sword_hitbox.monitoring = false

# Giống _consume_sword: khi hết đạn thì súng biến mất (ẩn)
func _consume_gun() -> void:
	current_weapon = WeaponType.NONE
	if gun_sprite:
		gun_sprite.hide()

@export var gun_drop_scene: PackedScene # Kéo file GunDrop.tscn vào đây

func drop_gun():
	if gun_drop_scene == null: 
		return
	var drop = gun_drop_scene.instantiate()
	
	# Đặt vị trí và xoay theo súng hiện tại
	drop.global_position = gun_sprite.global_position
	drop.global_rotation = 0  # Luôn rơi thẳng xuống, không bay lên theo góc súng
	
	get_tree().current_scene.add_child(drop)
	
	# Gọi đúng tên Animation bạn vừa sửa ở Bước 1
	var anim = drop.get_node("AnimationPlayer")
	anim.play("drop")
	
	# Ẩn súng thật
	gun_sprite.hide()
	current_weapon = WeaponType.NONE
func blank():
	if ammo <= 0:
		drop_gun()


func upload_score():
	# Sử dụng player_name (tên từ TikTok) để lưu điểm
	var final_name = player_name if player_name != "" else "Anonymous"
	
	# Gửi điểm lên SilentWolf
	if SilentWolf.Scores:
		SilentWolf.Scores.save_score(final_name, kill, Global.current_leaderboard)