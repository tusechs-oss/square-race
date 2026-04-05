extends RigidBody2D

# --- CẤU HÌNH VŨ KHÍ ---
@export var bullet_scene: PackedScene # Scene đạn súng
@export var auto_aim_enabled := true # Bật/tắt tự động ngắm
@export var auto_aim_max_distance := 800.0 # Khoảng cách tối đa để tự ngắm

# Các loại vũ khí hiện có
enum WeaponType { NONE, GUN, SWORD, GOJO }

# --- CÁC THAM CHIẾU VÀ BIẾN TRẠNG THÁI ---
@export var kill_splash_scene: PackedScene # Hiệu ứng khi tiêu diệt kẻ địch
@export var hollow_purple_scene: PackedScene # Scene đạn Hollow Purple
var current_weapon: WeaponType = WeaponType.NONE # Vũ khí đang cầm
var current_target: Node2D = null # Mục tiêu hiện tại đang nhắm đến

@onready var hand = $hand # Node cánh tay (xoay theo mục tiêu)
@onready var gun_sprite = $hand/Gun # Hình ảnh súng
@onready var sword_sprite = $hand/Sword # Hình ảnh kiếm
@onready var hollow_node = get_node_or_null("../hollow") # Hiệu ứng Gojo
@onready var hollow_anim = get_node_or_null("../hollow/AnimationPlayer") # Animation Gojo
@onready var shoot_timer = $hand/ShootTimer # Thời gian chờ giữa các lần bắn
@onready var muzzle = $hand/Muzzle # Vị trí đầu nòng súng (để spawn đạn)
@onready var sword_hitbox = $hand/Sword/SwordHitbox # Vùng va chạm của kiếm

# Hệ thống rung camera khi chém/bắn
@onready var shake_camera = get_tree().get_first_node_in_group("camera_shake")

# --- HỆ THỐNG ÂM THANH ---
@onready var bounce_sound = get_node_or_null("../BounceSound")
@onready var gun_sound = get_node_or_null("../GunSound")
@onready var sword_sound = get_node_or_null("../SwordSound")
@onready var gojo_sound = get_node_or_null("../Gojo")
@onready var sword_kill_sound = get_node_or_null("../SwordKill")
@onready var reload_sound = get_node_or_null("../Reload")

# --- THÔNG SỐ VŨ KHÍ ---
var sword_kills_left = 0 # Số lần được chém (thường là 1 lần biến mất)
const GUN_PICKUP_DELAY = 1.0 # Delay 1s sau khi nhặt mới được bắn
var gun_ready_at = 0.0 # Mốc thời gian được phép bắn
var gojo_charging = false # Đang tích tụ Hollow Purple
const MAX_AMMO = 2 # Số đạn tối đa
var ammo = MAX_AMMO # Số đạn hiện có
var kill = 0 # Số mạng đã giết
var player_name: String = "" # Tên nhân vật (ID TikTok)

# --- HỆ THỐNG MÁU ---
@export var max_hearts := 1 # Máu tối đa
var hearts := 1 # Máu hiện tại

func _ready():
	_ensure_audio_players() # Khởi tạo các node âm thanh nếu chưa có
	
	# Thiết lập va chạm cho RigidBody2D
	contact_monitor = true
	max_contacts_reported = 8
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	# Khởi tạo Trail (vệt đuôi di chuyển)
	if has_node("Trail"):
		$Trail.visible = false
	hearts = max_hearts

	# 1. Đóng băng vật lý tạm thời khi mới spawn để tránh lỗi giật lag
	freeze = true 
	await get_tree().create_timer(0.1).timeout
	freeze = false 
	
	# 2. Kích hoạt Trail
	if has_node("Trail"):
		if $Trail.has_method("clear_points"):
			$Trail.clear_points()
		$Trail.visible = true
		
	# 3. Ẩn tất cả vũ khí lúc mới sinh ra
	if gun_sprite:
		gun_sprite.hide()
	if sword_sprite:
		sword_sprite.hide()
	if hollow_node:
		hollow_node.hide()
	if sword_hitbox:
		sword_hitbox.monitoring = false
		sword_hitbox.monitorable = false

	add_to_group("Player") # Thêm vào nhóm Player để các hệ thống khác nhận diện
	
	# 4. Tạo vận tốc ban đầu ngẫu nhiên để nhân vật bay lượn
	gravity_scale = 0 # Không trọng lực
	linear_damp = 0 # Không ma sát không khí (bay vĩnh viễn)
	var angle = randf_range(0, 2 * PI)
	var direction = Vector2(cos(angle), sin(angle))
	linear_velocity = direction * 400

# --- XỬ LÝ VA CHẠM (NẢY TƯỜNG) ---
func _on_body_entered(body):
	if bounce_sound:
		bounce_sound.stop()
		bounce_sound.play()
		
	# Tạo sự ngẫu nhiên khi nảy để quỹ đạo bay thú vị hơn
	var random_bounce_offset = randf_range(-0.2, 0.2)
	var current_dir = linear_velocity.angle()
	var new_dir = current_dir + random_bounce_offset
	
	# Luôn duy trì tốc độ 400 sau khi va chạm
	linear_velocity = Vector2.RIGHT.rotated(new_dir) * 400
	
	# Cú hích nhẹ để đảm bảo không bao giờ bị kẹt đứng im
	apply_central_impulse(linear_velocity.normalized() * 10)

func _ensure_audio_players() -> void:
	# Các node âm thanh đã được gán qua @onready get_node_or_null
	pass

# --- TÌM MỤC TIÊU GẦN NHẤT ---
func get_target_from_area():
	if not $AutoAimArea: return null
	
	var targets = $AutoAimArea.get_overlapping_bodies()
	var closest_enemy = null
	var min_dist = INF
	
	for body in targets:
		# Chỉ nhắm vào các node thuộc nhóm Player và không phải là chính mình
		if body.is_in_group("Player") and body != self:
			var dist = global_position.distance_to(body.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_enemy = body
				
	return closest_enemy

# --- NHẶT VŨ KHÍ ---
func pick_up_gun():
	current_weapon = WeaponType.GUN
	ammo = MAX_AMMO 
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
	if hollow_node:
		hollow_node.hide()
	# Kích hoạt vùng chém của kiếm
	if sword_hitbox:
		sword_hitbox.monitoring = true
		sword_hitbox.monitorable = false

func pick_up_gojo():
	if gojo_charging: return
	current_weapon = WeaponType.GOJO
	
	if gun_sprite: gun_sprite.hide()
	if sword_sprite: sword_sprite.hide()
	
	# Bắt đầu chuỗi chiêu thức Hollow Red -> Blue -> Purple
	start_hollow_sequence()

func start_hollow_sequence():
	gojo_charging = true
	
	# Phát âm thanh Gojo
	if gojo_sound:
		gojo_sound.stop()
		gojo_sound.play()
	
	# Sử dụng animation "reloading" có sẵn trong Player.tscn
	if hollow_node and hollow_anim:
		hollow_node.show()
		hollow_anim.play("reloading")
		
		# Đợi đến khi ra màu tím (khoảng 2.5s theo animation reloading)
		await get_tree().create_timer(2.5).timeout
		
		# Phóng Hollow Purple
		launch_hollow_purple()
		
		# Đợi nốt phần còn lại của animation
		await hollow_anim.animation_finished
		hollow_node.hide()
	
	current_weapon = WeaponType.NONE
	gojo_charging = false

func launch_hollow_purple():
	if hollow_purple_scene == null:
		# Fallback if not assigned
		hollow_purple_scene = load("res://HollowPurple.tscn")
		
	if hollow_purple_scene:
		var purple = hollow_purple_scene.instantiate()
		purple.shooter = self
		# Phóng theo hướng đang nhìn (hand rotation)
		purple.direction = Vector2.RIGHT.rotated(hand.global_rotation)
		purple.global_position = global_position
		get_tree().current_scene.add_child(purple)
		
		# Hiệu ứng rung màn hình mạnh
		if shake_camera and shake_camera.has_method("add_trauma"):
			shake_camera.add_trauma(1.0)

func _process(delta):
	# Cập nhật vị trí hiệu ứng Gojo theo nhân vật
	if hollow_node and hollow_node.visible:
		hollow_node.global_position = global_position

	# Lật ảnh súng/kiếm khi quay sang trái để không bị ngược
	if hand.global_rotation > PI/2 or hand.global_rotation < -PI/2:
		gun_sprite.flip_v = true 
	else:
		gun_sprite.flip_v = false

	# 1. Tìm mục tiêu nếu chưa có hoặc mục tiêu cũ đã ra khỏi tầm bắn
	if is_instance_valid(current_target):
		var distance = global_position.distance_to(current_target.global_position)
		if distance > auto_aim_max_distance:
			current_target = null
	else:
		current_target = get_target_from_area()

	# 2. Xoay tay cầm súng mượt mà về phía mục tiêu
	if current_weapon == WeaponType.GUN:
		if current_target and is_instance_valid(current_target):
			var target_dir = (current_target.global_position - global_position).normalized()
			var target_angle = target_dir.angle()
			hand.rotation = lerp_angle(hand.rotation, target_angle, 0.2)
	else:
		# Nếu không cầm súng thì để tay ở vị trí mặc định (góc 0)
		hand.rotation = lerp_angle(hand.rotation, 0, 0.1)
	
	# 3. Thực hiện bắn tự động nếu cầm súng
	match current_weapon:
		WeaponType.GUN:
			if gun_sprite and gun_sprite.visible:
				auto_shoot()

# --- LOGIC BẮN SÚNG ---
func auto_shoot():
	if ammo <= 0:
		return
	if Time.get_ticks_msec() / 1000.0 < gun_ready_at:
		return
	if shoot_timer and shoot_timer.is_stopped():
		shoot()
		shoot_timer.start()

func shoot():
	if bullet_scene:
		if ammo <= 0:
			return
		
		if gun_sound:
			gun_sound.stop()
			gun_sound.play()
			
		# Tạo đạn và gán vị trí, hướng bắn từ Muzzle
		var bullet = bullet_scene.instantiate()
		bullet.shooter = self
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = muzzle.global_position
		bullet.global_rotation = muzzle.global_rotation
		bullet.global_transform = muzzle.global_transform
		
		ammo -= 1
		if ammo <= 0:
			drop_gun() # Hết đạn thì vứt súng

# --- LOGIC CHÉM KIẾM ---
func _on_sword_hitbox_body_entered(body: Node2D) -> void:
	_try_sword_kill(body)

func _try_sword_kill(body: Node2D) -> bool:
	if sword_kills_left <= 0:
		return false
	if body == null or body == self or body.is_queued_for_deletion():
		return false
	if not body.is_in_group("Player"):
		return false
		
	var dead := true
	if body.has_method("apply_damage"):
		dead = body.apply_damage(1) # Trừ máu kẻ địch
		
	if dead and body.has_method("queue_free"):
		kill += 1 # Tăng điểm giết mạng
		upload_score()
		
		if sword_kill_sound:
			sword_kill_sound.stop()
			sword_kill_sound.play()
			
		# Hiệu ứng rung màn hình
		if shake_camera and shake_camera.has_method("add_trauma"):
			shake_camera.add_trauma(0.5)
			
		# Hiệu ứng nổ tung khi chết
		if kill_splash_scene:
			var splash := kill_splash_scene.instantiate()
			splash.global_position = body.global_position
			get_tree().current_scene.add_child(splash)
			var anim_player := splash.get_node_or_null("Sprite2D/AnimationPlayer")
			if not anim_player:
				anim_player = splash.get_node_or_null("AnimationPlayer")
			if anim_player is AnimationPlayer:
				anim_player.play("Splash")
			
		body.queue_free() # Xóa kẻ địch
		sword_kills_left -= 1
		if sword_kills_left <= 0:
			_consume_sword() # Hết số lần chém thì mất kiếm
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

# --- HỆ THỐNG MÁU VÀ HIỆU ỨNG TRÚNG ĐÒN ---
func apply_damage(amount := 1) -> bool:
	hearts -= amount
	# Hiệu ứng chớp đỏ khi trúng đạn
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1, 0.4, 0.4, 1.0), 0.05)
	t.tween_property(self, "modulate", Color(1, 1, 1, 1.0), 0.3)
	
	if hearts > 0:
		return false # Chưa chết
	return true # Đã hết máu

var dying = false # Cờ đánh dấu đang trong hiệu ứng chết

# --- HIỆU ỨNG CHẾT CHÁY (BURN DISSOLVE) ---
func burn_death():
	if dying: return # Tránh gọi nhiều lần
	dying = true
	
	# 1. Khóa chuyển động và ĐÓNG BĂNG nhân vật
	set_deferred("freeze", true)
	# Không dùng PROCESS_MODE_DISABLED ở đây vì nó sẽ làm dừng Tween
	# Thay vào đó ta sẽ dùng một biến cờ để ngừng logic di chuyển
	
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	# 2. Áp dụng logic lên TextureRect hiện tại (Shader cầu vồng)
	var visual_node = get_node_or_null("TextureRect")
	if not visual_node: visual_node = get_node_or_null("Sprite2D") # Fallback
	
	if visual_node and visual_node.material:
		visual_node.material = visual_node.material.duplicate()
		var mat = visual_node.material
		
		# Load noise texture dự phòng
		var noise_tex = load("res://texture for ce/T_VFX_CloudNoise_Tiled.png")
		mat.set_shader_parameter("noise_tex", noise_tex)
		mat.set_shader_parameter("burn_color", Color(3.0, 0.8, 0.1))
		mat.set_shader_parameter("burn_size", 0.15)
		
		# 3. Tween hiệu ứng tan biến
		# Đảm bảo Tween chạy ngay cả khi game bị dừng (nếu cần)
		var t = create_tween()
		mat.set_shader_parameter("dissolve_value", 0.0)
		# Cháy trong 2.5 giây để nhìn rõ hiệu ứng lửa thiêu rụi
		t.tween_property(mat, "shader_parameter/dissolve_value", 1, 1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Chờ hiệu ứng xong
		await t.finished
	
	# 4. Xóa nhân vật
	var root = get_parent()
	if root and (root.is_in_group("Player") or "Player" in root.name):
		root.queue_free()
	else:
		queue_free()
