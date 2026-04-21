extends Node

signal youtube_superchat_received(user_name, avatar_url, amount)
signal youtube_spawn_requested(user_name, avatar_url, reason, raw_data)
var udp := PacketPeerUDP.new()
var listen_port := 4242
var current_leaderboard := "main"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SilentWolf.configure({
		"api_key": "e0ttkdWhZtreM8ggsZDN5f1LfWB23CB2fxDAAPU8",
		"game_id": "Squareleague",
		"log_level": 1
	})

	SilentWolf.configure_scores({
		"open_scene_on_close": "res://scenes/MainPage.tscn"
	})

	udp.set_dest_address("127.0.0.1", 6500) # (Nếu bạn muốn gửi lại gì đó)
	if udp.bind(listen_port) != OK:
		pass
	
	set_process(true)


func _process(_delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var text = udp.get_packet().get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			# Chuẩn hóa tên hiển thị và avatar từ dữ liệu đầu vào
			var _name := ""
			if parsed.has("nickname") and str(parsed["nickname"]) != "" and str(parsed["nickname"]) != "<null>":
				_name = str(parsed["nickname"])
			elif parsed.has("user") and str(parsed["user"]) != "" and str(parsed["user"]) != "<null>":
				_name = str(parsed["user"])
			elif parsed.has("displayName") and str(parsed["displayName"]) != "" and str(parsed["displayName"]) != "<null>":
				_name = str(parsed["displayName"])
			else:
				_name = "Anonymous"

			var _avatar := ""
			if parsed.has("avatar") and str(parsed["avatar"]) != "" and str(parsed["avatar"]) != "<null>":
				_avatar = str(parsed["avatar"])
			elif parsed.has("profilePictureUrl") and str(parsed["profilePictureUrl"]) != "" and str(parsed["profilePictureUrl"]) != "<null>":
				_avatar = str(parsed["profilePictureUrl"])
			elif parsed.has("avatarUrl") and str(parsed["avatarUrl"]) != "" and str(parsed["avatarUrl"]) != "<null>":
				_avatar = str(parsed["avatarUrl"])

			var _reason := str(parsed.get("reason", ""))

			# Gửi tín hiệu spawn với dữ liệu đã chuẩn hóa
			print("[UDP] spawn:", _name)
			youtube_spawn_requested.emit(_name, _avatar, _reason, parsed)
