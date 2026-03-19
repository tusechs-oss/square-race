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
	
# Trích xuất boss_level từ reason/raw_data theo thứ tự ưu tiên:
# 1) raw_data.boss_level
# 2) reason = "boss_lv_X"
# 3) Test offline: gift == "rose" + repeatEnd → map repeatCount 5/10/15/20 → 1..4
# 4) raw_data.hearts (nếu có) → nâng cấp theo hearts-1
func _resolve_boss_level(reason: Variant, raw_data: Variant) -> int:
	var level := 0
	if raw_data is Dictionary:
		level = int(raw_data.get("boss_level", 0))
		if level == 0:
			var g := str(raw_data.get("gift", "")).to_lower()
			var rc := int(raw_data.get("repeatCount", 0))
			var re := bool(raw_data.get("repeatEnd", false))
			if g == "rose" and re:
				match rc:
					5: level = 1
					10: level = 2
					15: level = 3
					20: level = 4
					25: level = 5
			elif g == "donut":
				level = 6
		if raw_data.has("hearts"):
			var h := int(raw_data["hearts"])
			if h > 0:
				level = max(level, h - 1)
	if level == 0 and typeof(reason) == TYPE_STRING:
		var r := str(reason).to_lower()
		if r.begins_with("boss_lv_"):
			var parts = r.split("_")
			if parts.size() >= 3:
				level = int(parts[2])
	return level

# Màu sắc theo cấp Boss (1→5): đỏ nhạt → đỏ đậm
func _boss_color_for_level(level: int) -> Color:
	match level:
		1: return Color(1.0, 0.7, 0.7, 1.0)
		2: return Color(1.0, 0.5, 0.5, 1.0)
		3: return Color(0.95, 0.3, 0.3, 1.0)
		4: return Color(0.9, 0.15, 0.15, 1.0)
		5: return Color(0.85, 0.05, 0.05, 1.0)
		6: return Color(0.7, 0.0, 0.0, 1.0)
		_: return Color(1, 1, 1, 1)

# Áp màu Boss lên phần thân (ưu tiên TextureRect; không có thì tô cả RigidBody2D)
func _apply_boss_color(rb: Node, level: int) -> void:
	if rb == null:
		return
	var col := _boss_color_for_level(level)
	var body_tex = rb.get_node_or_null("TextureRect")
	if body_tex == null:
		body_tex = rb.find_child("TextureRect", true, false)
	if body_tex and "modulate" in body_tex:
		body_tex.modulate = col
	else:
		rb.modulate = col

# Áp màu cho Trail (Line2D) nếu nhân vật có node "Trail"
func _apply_trail_color(rb: Node, level: int) -> void:
	if rb == null:
		return
	var trail = rb.get_node_or_null("Trail")
	if trail == null:
		trail = rb.find_child("Trail", true, false)
	if trail:
		var col := _boss_color_for_level(level)
		if "default_color" in trail:
			trail.default_color = col
		elif "modulate" in trail:
			trail.modulate = col
		# Tăng độ dày trail theo cấp nếu có thuộc tính width
		if "width" in trail:
			trail.width = 6.0 + max(level - 1, 0) * 2.0
		if "visible" in trail:
			trail.visible = true

# Tăng kích cỡ theo cấp Boss; Lv6 phóng to rõ rệt
func _boss_scale_for_level(level: int) -> float:
	match level:
		1: return 1.0
		2: return 1.2
		3: return 1.4
		4: return 1.7
		5: return 2.1
		6: return 2.6
		_: return 1.0

func _apply_boss_scale_full(rb: Node2D, level: int) -> void:
	if rb == null:
		return
	var s := _boss_scale_for_level(level)
	var root := rb.get_parent()
	if root is Node2D:
		(root as Node2D).scale = Vector2(s, s)
	else:
		rb.scale = Vector2(s, s)

# Scale CollisionShape2D theo cấp để khớp kích cỡ hiển thị
func _apply_collision_scale(rb: Node2D, level: int) -> void:
	if rb == null:
		return
	var s := _boss_scale_for_level(level)
	var col = rb.get_node_or_null("CollisionShape2D")
	if col == null:
		col = rb.find_child("CollisionShape2D", true, false)
	if col == null:
		return
	var shape = col.shape
	if shape == null:
		return
	# Lưu kích cỡ gốc để tránh nhân đôi khi gọi lại
	if not col.has_meta("base_saved"):
		if "size" in shape:
			col.set_meta("base_size", shape.size)
		elif "extents" in shape:
			col.set_meta("base_extents", shape.extents)
		elif "radius" in shape:
			col.set_meta("base_radius", shape.radius)
			if "height" in shape:
				col.set_meta("base_height", shape.height)
		col.set_meta("base_saved", true)
	# Áp scale theo loại shape
	if "size" in shape:
		var base_size = col.get_meta("base_size", shape.size)
		shape.size = base_size * s
	elif "extents" in shape:
		var base_extents = col.get_meta("base_extents", shape.extents)
		shape.extents = base_extents * s
	elif "radius" in shape:
		var base_radius = float(col.get_meta("base_radius", shape.radius))
		shape.radius = base_radius * s
		if "height" in shape:
			var base_h = float(col.get_meta("base_height", shape.height))
			shape.height = base_h * s

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
		
		# 3.1. Xử lý Boss theo donate → boss_level càng rõ ràng càng tốt
		var boss_level := _resolve_boss_level(reason, raw_data)
		if boss_level > 0:
			var rb2 = new_player.get_node_or_null("RigidBody2D")
			var hp := boss_level + 1
			if rb2 and rb2.has_method("apply_damage"):
				rb2.max_hearts = hp
				rb2.hearts = hp
				_apply_boss_color(rb2, boss_level)
				_apply_trail_color(rb2, boss_level)
				_apply_boss_scale_full(rb2, boss_level)
			# Không thêm tiền tố BossLv vào tên

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

# Spawn boss thủ công từ UI: số tim = level + 1 (Lv1=2, Lv2=3, Lv3=4, Lv4=5)
func _spawn_boss_level(level: int) -> void:
	var new_player = spawn_basic_box()
	if new_player:
		var rb = new_player.get_node_or_null("RigidBody2D")
		if rb and rb.has_method("apply_damage"):
			var hp = level + 1
			rb.max_hearts = hp
			rb.hearts = hp
			_apply_boss_color(rb, level)
			_apply_trail_color(rb, level)
			_apply_boss_scale_full(rb, level)

func _on_boss_lv_1_pressed() -> void:
	_spawn_boss_level(1)
