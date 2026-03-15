extends RigidBody2D
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
@export var bounce_volume_db := -15
@export var gun_volume_db := -5
@export var sword_volume_db := -5
@export var sword_kill_volume_db := -5
@export var reload_volume_db := -5
@onready var bounce_sound: AudioStreamPlayer = null
@onready var gun_sound: AudioStreamPlayer2D = null
@onready var sword_sound: AudioStreamPlayer2D = null
@onready var sword_kill_sound: AudioStreamPlayer2D = null
@onready var reload_sound: AudioStreamPlayer2D = null
func _ready():
	_ensure_audio_players()
	contact_monitor = true
	max_contacts_reported = 8
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if has_node("Trail"):
		$Trail.visible = false

	# 2. VÔ HIỆU HÓA vật lý tạm thời để không bị khựng khi tính toán va chạm lúc mới spawn
	freeze = true 

	# 3. Đợi 0.2 giây để mọi thứ (tọa độ, tài nguyên) ổn định hoàn toàn
	await get_tree().create_timer(0.1).timeout

	# 4. KÍCH HOẠT lại nhân vật: cho phép di chuyển mượt mà
	freeze = false 
	
	# 5. Bật Trail lên sau khi đã ở vị trí chuẩn
	if has_node("Trail"):
		if $Trail.has_method("clear_points"):
			$Trail.clear_points() # Xóa sạch các điểm "rác" cũ nếu có
		$Trail.visible = true
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
		bounce_sound.stop()
		bounce_sound.play()
	var random_bounce_offset = randf_range(-0.2, 0.2)
	
	# Lấy hướng vận tốc hiện tại, xoay nhẹ nó đi một chút
	var current_dir = linear_velocity.angle()
	var new_dir = current_dir + random_bounce_offset
	
	# Áp dụng hướng mới nhưng vẫn giữ nguyên tốc độ 400
	linear_velocity = Vector2.RIGHT.rotated(new_dir) * 400
	
	# Hiệu ứng phụ: Thêm chút lực đẩy nhẹ để không bao giờ bị đứng im
	apply_central_impulse(linear_velocity.normalized() * 10)
	var state = PhysicsServer2D.body_get_direct_state(get_rid())

func _ensure_audio_players() -> void:
	# 1. Tìm hoặc tạo BounceSound
	if bounce_sound == null:
		bounce_sound = get_node_or_null("../BounceSound")
	if bounce_sound == null and get_parent():
		bounce_sound = get_parent().get_node_or_null("BounceSound")
	if bounce_sound == null and get_tree().current_scene:
		bounce_sound = get_tree().current_scene.find_child("BounceSound", true, false)
		
	if bounce_sound == null:
		var local_sound = get_node_or_null("LocalBounceSound")
		if local_sound == null:
			local_sound = AudioStreamPlayer2D.new()
			local_sound.name = "LocalBounceSound"
			add_child(local_sound)
			local_sound.stream = load("res://khối va chạm.mp3")
			local_sound.bus = "Master"
			local_sound.attenuation = 0.0
			local_sound.max_distance = 100000.0
		bounce_sound = local_sound
	
	if bounce_sound:
		bounce_sound.volume_db = bounce_volume_db
		
	# 2. Tìm hoặc tạo GunSound
	if gun_sound == null:
		gun_sound = get_node_or_null("../GunSound")
	if gun_sound == null and get_parent():
		gun_sound = get_parent().get_node_or_null("GunSound")
	if gun_sound == null and get_tree().current_scene:
		gun_sound = get_tree().current_scene.find_child("GunSound", true, false)
		
	if gun_sound == null:
		var local_gun = get_node_or_null("LocalGunSound")
		if local_gun == null:
			local_gun = AudioStreamPlayer2D.new()
			local_gun.name = "LocalGunSound"
			add_child(local_gun)
			local_gun.stream = load("res://pixel-gun-3d-zombie-slayer-shoot.mp3")
			local_gun.bus = "Master"
			local_gun.attenuation = 0.0
			local_gun.max_distance = 100000.0
		gun_sound = local_gun
	
	if gun_sound:
		gun_sound.volume_db = gun_volume_db
		
	# 3. Tìm hoặc tạo SwordSound (Gojo)
	if sword_sound == null:
		sword_sound = get_node_or_null("../SwordSound")
	if sword_sound == null and get_parent():
		sword_sound = get_parent().get_node_or_null("SwordSound")
	if sword_sound == null and get_tree().current_scene:
		sword_sound = get_tree().current_scene.find_child("SwordSound", true, false)
		
	if sword_sound == null:
		var local_sword = get_node_or_null("LocalSwordSound")
		if local_sword == null:
			local_sword = AudioStreamPlayer2D.new()
			local_sword.name = "LocalSwordSound"
			add_child(local_sword)
			local_sword.stream = load("res://gomen-amanai-gojo.mp3")
			local_sword.bus = "Master"
			local_sword.attenuation = 0.0
			local_sword.max_distance = 100000.0
		sword_sound = local_sword
	
	if sword_sound:
		sword_sound.volume_db = sword_volume_db
		
	# 4. Tìm hoặc tạo SwordKillSound (Among Us)
	if sword_kill_sound == null:
		sword_kill_sound = get_node_or_null("../SwordKillSound")
	if sword_kill_sound == null and get_parent():
		sword_kill_sound = get_parent().get_node_or_null("SwordKillSound")
	if sword_kill_sound == null and get_tree().current_scene:
		sword_kill_sound = get_tree().current_scene.find_child("SwordKillSound", true, false)
		
	if sword_kill_sound == null:
		var local_kill = get_node_or_null("LocalSwordKillSound")
		if local_kill == null:
			local_kill = AudioStreamPlayer2D.new()
			local_kill.name = "LocalSwordKillSound"
			add_child(local_kill)
			local_kill.stream = load("res://among-us-kill-sound-effect-hd_slMcZ2v.mp3")
			local_kill.bus = "Master"
			local_kill.attenuation = 0.0
			local_kill.max_distance = 100000.0
		sword_kill_sound = local_kill
	
	if sword_kill_sound:
		sword_kill_sound.volume_db = sword_kill_volume_db
		
	# 5. Tìm hoặc tạo ReloadSound
	if reload_sound == null:
		reload_sound = get_node_or_null("../ReloadSound")
	if reload_sound == null and get_parent():
		reload_sound = get_parent().get_node_or_null("ReloadSound")
	if reload_sound == null and get_tree().current_scene:
		reload_sound = get_tree().current_scene.find_child("ReloadSound", true, false)
		
	if reload_sound == null:
		var local_reload = get_node_or_null("LocalReloadSound")
		if local_reload == null:
			local_reload = AudioStreamPlayer2D.new()
			local_reload.name = "LocalReloadSound"
			add_child(local_reload)
			local_reload.stream = load("res://NYSfM2ZRrOsD6TYg.mp3")
			local_reload.bus = "Master"
			local_reload.attenuation = 0.0
			local_reload.max_distance = 100000.0
		reload_sound = local_reload
	
	if reload_sound:
		reload_sound.volume_db = reload_volume_db

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
	
	# Phát âm thanh Gojo khi nhặt kiếm
	if sword_sound:
		sword_sound.stop()
		sword_sound.play()
		
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
		
		# Phát âm thanh súng bắn
		if gun_sound:
			gun_sound.stop()
			gun_sound.play()
		elif bounce_sound:
			bounce_sound.stop()
			bounce_sound.play()
			
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
		upload_score() # Cập nhật điểm ngay khi giết được người
		# Phát âm thanh chém chết (Among Us)
		if sword_kill_sound:
			sword_kill_sound.stop()
			sword_kill_sound.play()
			
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
		
	# Phát âm thanh reload khi vứt súng
	if reload_sound:
		reload_sound.stop()
		reload_sound.play()
		
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
	var display_name = player_name if player_name != "" else "Anonymous"
	
	# Gửi điểm lên bảng xếp hạng hiện tại (trong Global)
	if SilentWolf.Scores:
		SilentWolf.Scores.save_score(display_name, kill, Global.current_leaderboard)

func _physics_process(_delta):
	if linear_velocity.length() < 600:
		linear_velocity = linear_velocity.normalized() * 400
