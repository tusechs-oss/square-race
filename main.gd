extends Node2D
var current_lb = "main"
@onready var leaderboard_node = $CanvasLayer
@export var bxh: PackedScene
@export var spawn_area: Area2D 
@export var sword_scene: PackedScene
@export var box_template: PackedScene
@export var gun_scene: PackedScene
@onready var spawn_region = $SpawnRegion/ColorRect
@onready var line_edit = find_child("LineEdit") 
@export var player_scene_path: String = "res://Weapons/Player.tscn"
@export var node_scene_path: String = "res://Weapons/node_2d.tscn"
@export var prefer_player_template: bool = true

func _ready() -> void:
	if box_template == null:
		var path = player_scene_path if prefer_player_template else node_scene_path
		var ps = load(path)
		if ps and ps is PackedScene:
			box_template = ps
	if Global.has_signal("tiktok_spawn_requested"):
		Global.tiktok_spawn_requested.connect(_on_tiktok_spawn)
	randomize()
	
func _on_tiktok_spawn(user_name, avatar_url, reason, raw_data = null):
	if box_template:
		# 1. Tạo nhân vật
		var new_player = spawn_basic_box()
		
		# 2. Gán ID TikTok vào biến player_name của Player để lưu leaderboard
		# Ưu tiên sử dụng nickname cho bảng xếp hạng nếu có
		var actual_name = user_name
		if raw_data is Dictionary and raw_data.has("nickname") and raw_data["nickname"] != "":
			actual_name = raw_data["nickname"]
			
		var player_body = new_player.get_node_or_null("RigidBody2D")
		if player_body and "player_name" in player_body:
			player_body.player_name = actual_name
		elif "player_name" in new_player:
			new_player.player_name = actual_name

		# 3. Hiện tên lên Label cho người xem thấy
		var label_node = new_player.get_node_or_null("RigidBody2D/Label")
		if label_node == null:
			label_node = new_player.find_child("Label", true, false)
		if label_node == null:
			var rb = new_player.get_node_or_null("RigidBody2D")
			if rb:
				label_node = Label.new()
				label_node.name = "Label"
				label_node.anchors_preset = 5
				label_node.anchor_left = 0.5
				label_node.anchor_right = 0.5
				label_node.offset_left = -72.0
				label_node.offset_top = -35.0
				label_node.offset_right = 72.0
				label_node.offset_bottom = -3.0
				label_node.grow_horizontal = 2
				label_node.horizontal_alignment = 1
				label_node.vertical_alignment = 1
				label_node.z_index = 30
				rb.add_child(label_node)
		if label_node:
			# Ưu tiên hiện nickname cho đẹp, nếu không có thì hiện user_name
			if raw_data is Dictionary and raw_data.has("nickname") and raw_data["nickname"] != "":
				label_node.text = raw_data["nickname"]
			else:
				label_node.text = user_name
			label_node.visible = true
			print("[Spawn] label:", label_node.text)
			# Đảm bảo có font chữ và style đồng nhất
			if label_node.label_settings == null:
				var settings = LabelSettings.new()
				settings.font = preload("res://SouthernGothic-Normal-FREE-FOR-PERSONAL-USE-ONLY.otf")
				settings.font_size = 17
				settings.outline_size = 6
				settings.outline_color = Color.BLACK
				label_node.label_settings = settings

		# 4. Xử lý Avatar (Giữ nguyên để tránh lỗi 403)
		var final_url = ""
		if avatar_url != null and str(avatar_url) != "" and str(avatar_url) != "<null>":
			final_url = str(avatar_url)
		elif raw_data is Dictionary and raw_data.has("profilePictureUrl"):
			final_url = raw_data["profilePictureUrl"]

		if final_url != "":
			var tex_rect = new_player.find_child("TextureRect")
			if tex_rect:
				_download_and_apply_avatar(final_url, tex_rect)
func _download_and_apply_avatar(url: String, tex_rect):
	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(result, response_code, _headers, body):
		if response_code == 200 and body.size() > 0:
			var tex = ImageHelper.load_texture_from_buffer(body)
			if tex and is_instance_valid(tex_rect):
				tex_rect.texture = tex
		http.queue_free()
	)
	
	# THÊM USER-AGENT ĐỂ TRANH LỖI 403
	var headers = ["User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)"]
	var error = http.request(url, headers)
func _on_line_edit_text_submitted(new_text):
	if box_template == null: return
	
	var new_box = box_template.instantiate()
	add_child(new_box)
	# Gán player_name cho node RigidBody2D bên trong (nếu có)
	var player_body = new_box.get_node_or_null("RigidBody2D")
	if player_body and "player_name" in player_body:
		player_body.player_name = new_text
	elif "player_name" in new_box:
		new_box.player_name = new_text
	
	var area = get_node_or_null("SpawnArea")
	if area:
		var rect_pos = area.global_position
		var rect_size = area.size
		
		# Tính toán vị trí ngẫu nhiên bên trong khung
		var rx = randf_range(rect_pos.x, rect_pos.x + rect_size.x)
		var ry = randf_range(rect_pos.y, rect_pos.y + rect_size.y)
		
		new_box.global_position = Vector2(rx, ry)
	else:
		new_box.global_position = get_viewport_rect().size / 2
	
	var label_node = new_box.get_node_or_null("RigidBody2D/Label") 
	if label_node == null:
		label_node = new_box.find_child("Label", true, false)
	if label_node == null:
		var rb = new_box.get_node_or_null("RigidBody2D")
		if rb:
			label_node = Label.new()
			label_node.name = "Label"
			label_node.anchors_preset = 5
			label_node.anchor_left = 0.5
			label_node.anchor_right = 0.5
			label_node.offset_left = -72.0
			label_node.offset_top = -35.0
			label_node.offset_right = 72.0
			label_node.offset_bottom = -3.0
			label_node.grow_horizontal = 2
			label_node.horizontal_alignment = 1
			label_node.vertical_alignment = 1
			label_node.z_index = 30
			rb.add_child(label_node)
	if label_node:
		label_node.text = new_text
		label_node.z_index = 30 
		if label_node.label_settings == null:
			var settings = LabelSettings.new()
			settings.font = preload("res://SouthernGothic-Normal-FREE-FOR-PERSONAL-USE-ONLY.otf")
			settings.font_size = 17
			settings.outline_size = 6
			settings.outline_color = Color.BLACK
			label_node.label_settings = settings

	$Control/NameInput.clear()
	$Control/NameInput.grab_focus()	

func _on_vietnam_pressed():
	var new_box = spawn_basic_box()                
	if new_box:
		# Code xử lý cho khối vuông mới ở đây (ví dụ: gán tên)
		var label = new_box.find_child("Label")
		# var tex_rect = new_box.find_child("TextureRect") # Dòng này bạn chưa dùng nên cứ tạm để đây
		pass

# Thêm biến này lên đầu script để kéo Area2D vào Inspector


func spawn_basic_box():
	var scene := box_template
	if scene == null:
		var path = player_scene_path if prefer_player_template else node_scene_path
		var ps = load(path)
		if ps and ps is PackedScene:
			scene = ps
		if scene == null:
			return null
	var box = scene.instantiate()
	
	# Tìm chính xác Node Boxspawn trong hình image_ba1649.png
	var area = get_node_or_null("Boxspawn")
	if area:
		# Lấy CollisionShape2D bên trong Boxspawn
		var shape_node = area.get_node("CollisionShape2D")
		var size = shape_node.shape.size
		
		# Lấy tọa độ tâm thực tế của vùng này trên màn hình
		var center_pos = shape_node.global_position
		
		# Tính toán Random (Chia 2 để lấy phạm vi từ tâm ra mép)
		var rx = randf_range(center_pos.x - size.x/2, center_pos.x + size.x/2)
		var ry = randf_range(center_pos.y - size.y/2, center_pos.y + size.y/2)
		
		box.global_position = Vector2(rx, ry)
	else:
		box.global_position = get_viewport_rect().size / 2

	# Đưa vào Scene sau khi đã gán tọa độ chuẩn
	get_tree().current_scene.add_child(box)
	return box

func _on_sword_pressed() -> void:
	if sword_scene == null:
		return

	var khung = spawn_region.get_global_rect()

	var rx = randf_range(khung.position.x, khung.end.x)
	var ry = randf_range(khung.position.y, khung.end.y)

	var box = sword_scene.instantiate()
	box.global_position = Vector2(rx, ry)

	get_tree().current_scene.add_child(box)
	
func _on_gun_pressed() -> void:
	if gun_scene == null:
		return

	var khung = spawn_region.get_global_rect()

	var rx = randf_range(khung.position.x, khung.end.x)
	var ry = randf_range(khung.position.y, khung.end.y)

	var box = gun_scene.instantiate()
	box.global_position = Vector2(rx, ry)

	get_tree().current_scene.add_child(box)


func _on_button_pressed() -> void:
	# Tạo một tên bảng mới duy nhất (ví dụ: main_v2, main_v3...)
	var reset_name = "lb_" + str(Time.get_unix_time_from_system())
	Global.current_leaderboard = reset_name
	
	# Gửi một điểm 0 vào bảng mới này để server khởi tạo nó
	if SilentWolf.Scores.has_method("save_score"):
		await SilentWolf.Scores.save_score("Admin", 0, reset_name).sw_save_score_complete
	
	# Cập nhật lại giao diện hiển thị bảng mới này
	if leaderboard_node:
		# Xóa các dòng điểm cũ trên màn hình cho sạch
		var score_list = leaderboard_node.find_child("ScoreList")
		if score_list:
			for child in score_list.get_children():
				child.queue_free()
