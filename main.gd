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
var countdown_secs := 10
var countdown_remaining := 0
var pending_weapon := ""
var pending_weapon_node: Node2D = null
var spawn_timer_label: Label = null
var spawn_timer: Timer = null
@export var spawn_timer_label_path: NodePath
@export var spawn_timer_path: NodePath
@export var spimg_path: NodePath
var spimg_node: Node = null
@export var sword_preview_tex: Texture2D
@export var gun_preview_tex: Texture2D

func _ready() -> void:
	if box_template == null:
		var path = player_scene_path if prefer_player_template else node_scene_path
		var ps = load(path)
		if ps and ps is PackedScene:
			box_template = ps
	if Global.has_signal("tiktok_spawn_requested"):
		Global.tiktok_spawn_requested.connect(_on_tiktok_spawn)
	randomize()
	_find_spawn_timer_nodes()
	_find_spimg_node()
	
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

func _find_spawn_timer_nodes() -> void:
	spawn_timer_label = null
	spawn_timer = null
	if spawn_timer_label_path != null and str(spawn_timer_label_path) != "":
		var n1 = get_node_or_null(spawn_timer_label_path)
		if n1 is Label:
			spawn_timer_label = n1
	if spawn_timer_path != null and str(spawn_timer_path) != "":
		var n2 = get_node_or_null(spawn_timer_path)
		if n2 is Timer:
			spawn_timer = n2
	if spawn_timer_label == null or spawn_timer == null:
		var ui = get_node_or_null("Control")
		if ui != null:
			if spawn_timer_label == null:
				spawn_timer_label = ui.get_node_or_null("SpawnTimerLabel")
				if spawn_timer_label == null:
					for n in ui.get_children():
						if n is Label and n.find_child("Timer", true, false) != null:
							spawn_timer_label = n
							break
			if spawn_timer == null:
				if spawn_timer_label != null:
					var t = spawn_timer_label.get_node_or_null("Timer")
					if t is Timer:
						spawn_timer = t
				if spawn_timer == null:
					var t2 = ui.find_child("Timer", true, false)
					if t2 is Timer:
						spawn_timer = t2
	if spawn_timer_label == null or spawn_timer == null:
		var pair = _scan_for_label_timer(get_tree().current_scene)
		if pair.size() == 2:
			spawn_timer_label = pair[0]
			spawn_timer = pair[1]
	if spawn_timer_label == null or spawn_timer == null:
		var pair2 = _scan_for_label_timer(self)
		if pair2.size() == 2:
			spawn_timer_label = pair2[0]
			spawn_timer = pair2[1]

func _scan_for_label_timer(node: Node) -> Array:
	var result: Array = []
	if node == null:
		return result
	for child in node.get_children():
		if child is Label:
			# tìm Timer bất kỳ dưới Label (không phụ thuộc tên)
			for sub in child.get_children():
				if sub is Timer:
					return [child, sub]
			# tìm sâu hơn nếu Timer không phải là con trực tiếp
			var found := _find_timer_recursive(child)
			if found is Timer:
				return [child, found]
		var sub = _scan_for_label_timer(child)
		if sub.size() == 2:
			return sub
	return result

func _find_timer_recursive(node: Node) -> Node:
	for c in node.get_children():
		if c is Timer:
			return c
		var deep := _find_timer_recursive(c)
		if deep is Timer:
			return deep
	return null

func _find_spimg_node() -> void:
	spimg_node = null
	if spimg_path != null and str(spimg_path) != "":
		var n = get_node_or_null(spimg_path)
		if n != null:
			spimg_node = n
	if spimg_node == null:
		spimg_node = get_node_or_null("SPimg")
	if spimg_node == null:
		spimg_node = get_node_or_null("spimg")
	if spimg_node == null:
		var found = _find_node_by_name(get_tree().current_scene, "SPimg")
		if found != null:
			spimg_node = found
	if spimg_node == null:
		var found2 = _find_node_by_name(get_tree().current_scene, "spimg")
		if found2 != null:
			spimg_node = found2

func _find_node_by_name(node: Node, name: String) -> Node:
	if node == null:
		return null
	if node.name.to_lower() == name.to_lower():
		return node
	for c in node.get_children():
		var res = _find_node_by_name(c, name)
		if res != null:
			return res
	return null

func _set_spimg_texture(tex: Texture2D, kind: String = "") -> void:
	if spimg_node == null or tex == null:
		return
		
	var max_size = 100.0
	if kind == "sword":
		max_size = 140.0 # Kiếm to ra một chút so với 120
	elif kind == "gun":
		max_size = 80.0  # Súng nhỏ đi một chút so với 100
		
	var scale_factor = 1.0
	var t_size = tex.get_size()
	if t_size.x > 0 and t_size.y > 0:
		var max_dim = max(t_size.x, t_size.y)
		scale_factor = max_size / max_dim
		
	if spimg_node is TextureRect:
		spimg_node.texture = tex
		spimg_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spimg_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spimg_node.custom_minimum_size = Vector2(max_size, max_size)
		spimg_node.size = Vector2(max_size, max_size)
	elif spimg_node is Sprite2D:
		spimg_node.texture = tex
		spimg_node.scale = Vector2(scale_factor, scale_factor)
	elif "texture" in spimg_node:
		spimg_node.set("texture", tex)
		if "scale" in spimg_node:
			spimg_node.set("scale", Vector2(scale_factor, scale_factor))

func _update_spawn_preview(kind: String) -> void:
	_find_spimg_node()
	if spimg_node == null:
		return
	var scene: PackedScene = null
	if kind == "sword":
		scene = sword_scene
	elif kind == "gun":
		scene = gun_scene
	if scene == null:
		return
	var tmp = scene.instantiate()
	var tex: Texture2D = null
	tex = _find_texture_in_tree(tmp)
	if tex != null:
		_set_spimg_texture(tex, kind)
	if tex == null:
		if kind == "sword" and sword_preview_tex != null:
			_set_spimg_texture(sword_preview_tex, kind)
		elif kind == "gun" and gun_preview_tex != null:
			_set_spimg_texture(gun_preview_tex, kind)
	if is_instance_valid(tmp):
		tmp.queue_free()

func _find_texture_in_tree(node: Node) -> Texture2D:
	if node == null:
		return null
	var queue: Array = [node]
	while queue.size() > 0:
		var n: Node = queue.pop_front()
		if "texture" in n:
			var t = n.get("texture")
			if t != null and t is Texture2D:
				return t
		for c in n.get_children():
			queue.append(c)
	return null

func _start_weapon_countdown(kind: String) -> void:
	_find_spawn_timer_nodes()
	if spawn_timer == null:
		spawn_timer = Timer.new()
		add_child(spawn_timer)
	_update_spawn_preview(kind)
	
	# Khởi tạo vũ khí trước nhưng ẩn đi để lấy tọa độ ngẫu nhiên
	if is_instance_valid(pending_weapon_node):
		pending_weapon_node.queue_free()
	pending_weapon_node = null
	
	var khung = spawn_region.get_global_rect()
	var rx = randf_range(khung.position.x, khung.end.x)
	var ry = randf_range(khung.position.y, khung.end.y)
	var target_pos = Vector2(rx, ry)
	
	if kind == "sword" and sword_scene != null:
		pending_weapon_node = sword_scene.instantiate()
	elif kind == "gun" and gun_scene != null:
		pending_weapon_node = gun_scene.instantiate()
		
	if pending_weapon_node != null:
		pending_weapon_node.global_position = target_pos
		pending_weapon_node.visible = false
		# Tắt vật lý và tương tác tạm thời để nó không bị nhặt khi đang đếm ngược
		_set_node_interaction(pending_weapon_node, false)
		get_tree().current_scene.add_child(pending_weapon_node)
	
	# Di chuyển cả Countdown_reg tới vị trí vừa lấy được
	var coundotw_reg = _find_node_by_name(get_tree().current_scene, "Countdown_reg")
	if coundotw_reg == null:
		coundotw_reg = _find_node_by_name(get_tree().current_scene, "coundotw_reg")
		
	if coundotw_reg != null:
		coundotw_reg.visible = true
		if coundotw_reg is CanvasLayer:
			# Với CanvasLayer, ta set offset để dịch chuyển tất cả con bên trong
			coundotw_reg.offset = target_pos
		elif coundotw_reg is Node2D or coundotw_reg is Control:
			coundotw_reg.global_position = target_pos
				
		# Nếu Countdown_reg là CanvasLayer, các node con bên trong nên được đặt gốc tọa độ ở (0,0)
		if spawn_timer_label != null:
			if spawn_timer_label is Control:
				# Đặt nhãn đếm ngược xuống góc dưới bên phải hoặc sát bên dưới ảnh
				# Thay vì trừ 60 ở trục y (đưa lên trên), ta cộng vào để đưa xuống dưới
				spawn_timer_label.position = Vector2(-spawn_timer_label.size.x/2 + 65, -spawn_timer_label.size.y/2 + 45)
				
		if spimg_node != null:
			if spimg_node is Control:
				spimg_node.position = Vector2(-spimg_node.size.x/2, -spimg_node.size.y/2)
			elif "position" in spimg_node:
				spimg_node.set("position", Vector2(0, 0))
	
	if spimg_node != null:
		spimg_node.visible = true
	pending_weapon = kind
	countdown_remaining = countdown_secs
	if spawn_timer_label != null:
		spawn_timer_label.visible = true
		spawn_timer_label.modulate = Color(1, 1, 1, 1)
		spawn_timer_label.scale = Vector2(1, 1)
		spawn_timer_label.text = str(countdown_remaining) + "s"
	spawn_timer.stop()
	spawn_timer.wait_time = 1.0
	spawn_timer.one_shot = false
	if spawn_timer.timeout.is_connected(_on_spawn_timer_tick):
		spawn_timer.timeout.disconnect(_on_spawn_timer_tick)
	spawn_timer.timeout.connect(_on_spawn_timer_tick)
	spawn_timer.start()

func _on_spawn_timer_tick() -> void:
	if countdown_remaining > 0:
		countdown_remaining -= 1
		if spawn_timer_label != null:
			spawn_timer_label.text = str(countdown_remaining) + "s"
			var tw1 = create_tween()
			tw1.tween_property(spawn_timer_label, "modulate", Color(1, 0.25, 0.25, 1), 0.08)
			tw1.tween_property(spawn_timer_label, "modulate", Color(1, 1, 1, 1), 0.22)
			var tw2 = create_tween()
			tw2.tween_property(spawn_timer_label, "scale", Vector2(1.18, 1.18), 0.08)
			tw2.tween_property(spawn_timer_label, "scale", Vector2(1, 1), 0.22)
	if countdown_remaining <= 0:
		spawn_timer.stop()
		if spawn_timer_label != null:
			spawn_timer_label.text = ""
			spawn_timer_label.visible = false
		if spimg_node != null:
			spimg_node.visible = false
			
		var coundotw_reg = _find_node_by_name(get_tree().current_scene, "Countdown_reg")
		if coundotw_reg == null:
			coundotw_reg = _find_node_by_name(get_tree().current_scene, "coundotw_reg")
		if coundotw_reg != null:
			coundotw_reg.visible = false
		
		# Hiện vũ khí và bật lại vật lý
		if is_instance_valid(pending_weapon_node):
			pending_weapon_node.visible = true
			_set_node_interaction(pending_weapon_node, true)
		
		pending_weapon_node = null
		# Bỏ fallback để tránh spawn thừa nếu node đã bị giải phóng
				
		pending_weapon = ""

# Hàm hỗ trợ bật/tắt tương tác vật lý và Area2D cho vũ khí
func _set_node_interaction(node: Node, enabled: bool) -> void:
	if node == null:
		return
		
	# Xử lý RigidBody2D (đứng yên/chuyển động)
	if node is RigidBody2D:
		node.freeze = !enabled
		
	# Xử lý Area2D (không cho phép nhặt khi đang đếm ngược)
	if node is Area2D:
		node.monitoring = enabled
		node.monitorable = enabled
		
	# Đệ quy tìm các node con (ví dụ Area2D pickup nằm trong Node2D)
	for child in node.get_children():
		_set_node_interaction(child, enabled)
	
	# Xử lý các script có bật/tắt physics process
	if not node is RigidBody2D and node.has_method("set_physics_process"):
		node.set_physics_process(enabled)

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

func _spawn_sword_now() -> void:
	if sword_scene == null:
		return
	var khung = spawn_region.get_global_rect()
	var rx = randf_range(khung.position.x, khung.end.x)
	var ry = randf_range(khung.position.y, khung.end.y)
	var box = sword_scene.instantiate()
	box.global_position = Vector2(rx, ry)
	get_tree().current_scene.add_child(box)

func _on_sword_pressed() -> void:
	_start_weapon_countdown("sword")
	
func _spawn_gun_now() -> void:
	if gun_scene == null:
		return
	var khung = spawn_region.get_global_rect()
	var rx = randf_range(khung.position.x, khung.end.x)
	var ry = randf_range(khung.position.y, khung.end.y)
	var box = gun_scene.instantiate()
	box.global_position = Vector2(rx, ry)
	get_tree().current_scene.add_child(box)

func _on_gun_pressed() -> void:
	_start_weapon_countdown("gun")

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
