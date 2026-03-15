extends CanvasLayer

@onready var score_list = _find_score_list()

func _find_score_list():
	var list = get_node_or_null("Panel/ScrollContainer/ScoreList")
	if list == null:
		list = get_node_or_null("Panel/ScoreList")
	if list == null:
		list = find_child("ScoreList", true, false)
	return list
var leaderboard_name = "main"
var update_timer: Timer
var is_updating := false

func _ready():
	randomize()
	# Tạo timer để tự động cập nhật bảng xếp hạng
	update_timer = Timer.new()
	update_timer.wait_time = 5.0
	update_timer.autostart = true
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)
	
	# Đợi các Autoload sẵn sàng hoàn toàn
	await get_tree().create_timer(0.5).timeout
	_update_leaderboard()

func _on_update_timer_timeout():
	_update_leaderboard()

func _update_leaderboard():
	if is_updating:
		return
	is_updating = true
	# Kiểm tra xem SilentWolf đã sẵn sàng chưa
	if not SilentWolf or not SilentWolf.Scores:
		is_updating = false
		return
		
	# Lấy điểm từ server
	var scores_node = SilentWolf.Scores
	if not scores_node.has_method("get_scores"):
		is_updating = false
		return
		
	var scores_call = scores_node.get_scores(10, Global.current_leaderboard)
	if not scores_call:
		is_updating = false
		return
		
	var sw_result = await scores_call.sw_get_scores_complete
	if sw_result and sw_result.has("scores"):
		setup_scores(sw_result.scores)
	else:
		_show_message("Không có dữ liệu hoặc lỗi kết nối")
	is_updating = false

func setup_scores(scores):
	if score_list == null:
		score_list = _find_score_list()
		
	if score_list == null:
		return
		
	# Xóa danh sách cũ
	for child in score_list.get_children():
		child.queue_free()
	
	# Hiển thị Top 10 người chơi
	var custom_font = preload("res://SouthernGothic-Normal-FREE-FOR-PERSONAL-USE-ONLY.otf")
	for i in range(min(scores.size(), 10)):
		var score_data = scores[i]
		var label = Label.new()
		# Tùy chỉnh hiển thị: Tên - Điểm
		label.text = "%d. %s: %d" % [i + 1, score_data.player_name, int(score_data.score)]
		
		# Thêm font và style
		label.add_theme_font_override("font", custom_font)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		
		if i == 0: # Top 1 màu vàng
			label.add_theme_color_override("font_color", Color.GOLD)
			
		score_list.add_child(label)

func _show_message(text: String):
	if score_list == null:
		score_list = _find_score_list()
	if score_list == null:
		return
	for child in score_list.get_children():
		child.queue_free()
	var custom_font = preload("res://SouthernGothic-Normal-FREE-FOR-PERSONAL-USE-ONLY.otf")
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", custom_font)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.SALMON)
	score_list.add_child(label)
