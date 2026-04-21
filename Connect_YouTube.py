import pytchat
import socket
import json
import time
import requests
import threading

# --- CẤU HÌNH ---
VIDEO_ID = ""  # Để trống nếu muốn tự động tìm buổi live đang diễn ra
CHANNEL_HANDLE = "@gogAnju" # Tên kênh của bạn
UDP_IP = "127.0.0.1"
UDP_PORT = 4242
API_KEY = "AIzaSyC5mxMOsIZHp4RdgjQ4V6Ibc4c_eUNd9zw" # Đã dán API Key của bạn

# Ngưỡng donate cho Boss Lv3 (Ví dụ 30,000 VND)
BOSS_LV3_THRESHOLD = 30000

# --- KHỞI TẠO ---
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

def get_live_video_id(handle):
    """Tự động tìm VIDEO_ID của buổi live đang diễn ra trên kênh"""
    try:
        # 1. Tìm Channel ID từ Handle
        search_url = f"https://www.googleapis.com/youtube/v3/search?part=snippet&type=channel&q={handle}&key={API_KEY}"
        res = requests.get(search_url).json()
        if "items" not in res or not res["items"]:
            print(f"❌ Không tìm thấy kênh: {handle}")
            return None
        
        channel_id = res["items"][0]["snippet"]["channelId"]
        
        # 2. Tìm video đang LIVE của channel đó
        live_url = f"https://www.googleapis.com/youtube/v3/search?part=snippet&channelId={channel_id}&type=video&eventType=live&key={API_KEY}"
        res_live = requests.get(live_url).json()
        
        if "items" in res_live and res_live["items"]:
            v_id = res_live["items"][0]["id"]["videoId"]
            print(f"✅ Đã tìm thấy buổi live đang diễn ra! ID: {v_id}")
            return v_id
        else:
            print(f"📴 Kênh {handle} hiện không livestream.")
            return None
    except Exception as e:
        print(f"❌ Lỗi khi tự động tìm buổi live: {e}")
        return None

def send_to_godot(user_data, reason, is_raw=False):
    """
    user_data: có thể là tên (string) hoặc object author từ pytchat
    """
    if is_raw: # Nếu là dữ liệu từ Chat/SuperChat
        payload = {
            "user": user_data.name,
            "nickname": user_data.name,
            "avatar": user_data.imageUrl,
            "reason": reason,
            "timestamp": time.time()
        }
    else: # Nếu là dữ liệu Like/Sub (không lấy được tên cụ thể)
        payload = {
            "user": user_data,
            "nickname": user_data,
            "avatar": "https://www.gstatic.com/youtube/img/branding/youtubelogo/2x/youtube_logo_dark_64dp.png",
            "reason": reason,
            "timestamp": time.time()
        }
    
    message = json.dumps(payload).encode('utf-8')
    sock.sendto(message, (UDP_IP, UDP_PORT))
    print(f"🚀 [Godot] Đã gửi: {payload['nickname']} | Lý do: {reason}")

# --- THEO DÕI LIKE VÀ SUB (POLLING) ---
last_likes = 0
last_subs = 0

def update_stats():
    global last_likes, last_subs
    if not API_KEY or API_KEY == "YOUR_YOUTUBE_API_KEY":
        print("⚠️ Cảnh báo: Chưa cấu hình API_KEY. Không thể theo dõi Like/Sub.")
        return

    url = f"https://www.googleapis.com/youtube/v3/videos?part=statistics&id={VIDEO_ID}&key={API_KEY}"
    try:
        # Lấy số Like
        resp = requests.get(url).json()
        if "items" in resp:
            stats = resp["items"][0]["statistics"]
            current_likes = int(stats.get("likeCount", 0))
            
            # 100 likes = 1 spawn
            if last_likes > 0 and current_likes // 100 > last_likes // 100:
                diff = (current_likes // 100) - (last_likes // 100)
                for _ in range(diff):
                    send_to_godot("YouTube", "100_likes")
            
            last_likes = current_likes

        # Lấy số Sub (Cần channel ID, ta sẽ lấy từ video info)
        video_url = f"https://www.googleapis.com/youtube/v3/videos?part=snippet&id={VIDEO_ID}&key={API_KEY}"
        video_resp = requests.get(video_url).json()
        if "items" in video_resp:
            channel_id = video_resp["items"][0]["snippet"]["channelId"]
            channel_url = f"https://www.googleapis.com/youtube/v3/channels?part=statistics&id={channel_id}&key={API_KEY}"
            channel_resp = requests.get(channel_url).json()
            if "items" in channel_resp:
                current_subs = int(channel_resp["items"][0]["statistics"].get("subscriberCount", 0))
                
                # 1 sub = 1 spawn
                if last_subs > 0 and current_subs > last_subs:
                    diff = current_subs - last_subs
                    for _ in range(diff):
                        send_to_godot("New Sub", "spawn")
                
                last_subs = current_subs

    except Exception as e:
        print(f"❌ Lỗi cập nhật stats: {e}")

def stats_thread():
    while True:
        update_stats()
        time.sleep(10) # Cập nhật mỗi 10 giây (Tăng lên nếu bị giới hạn API)

# --- THEO DÕI CHAT VÀ SUPER CHAT ---
def start_chat():
    global VIDEO_ID
    
    # Nếu VIDEO_ID trống, tự động tìm buổi live của CHANNEL_HANDLE
    if not VIDEO_ID or VIDEO_ID == "YOUR_YOUTUBE_VIDEO_ID":
        print(f"🔍 Đang tự động tìm buổi live cho kênh: {CHANNEL_HANDLE}...")
        VIDEO_ID = get_live_video_id(CHANNEL_HANDLE)
    
    if not VIDEO_ID:
        print("❌ Không có VIDEO_ID để kết nối. Hãy đảm bảo bạn đang livestream và CHANNEL_HANDLE chính xác.")
        return

    print(f"📺 Đang kết nối với YouTube Live: {VIDEO_ID}...")
    livechat = pytchat.create(video_id=VIDEO_ID)
    
    # Thread lấy stats (like/sub) chạy song song với chat
    t = threading.Thread(target=stats_thread, daemon=True)
    t.start()

    while livechat.is_alive():
        for c in livechat.get().sync_items():
            print(f"💬 {c.author.name}: {c.message} (Donate: {c.amountString})")
            
            # Xử lý Super Chat (Boss Lv3)
            # Theo yêu cầu: 30k Super Chat = Boss Lv3
            if c.amountValue >= BOSS_LV3_THRESHOLD:
                send_to_godot(c.author, "boss_lv_3", is_raw=True)
            elif c.amountValue > 0:
                # Các mức donate thấp hơn spawn hộp thường
                send_to_godot(c.author, "spawn", is_raw=True)
            
            # Xử lý lệnh test
            if c.message.lower() == "test":
                send_to_godot(c.author, "spawn", is_raw=True)

    print("❌ Livechat đã kết thúc hoặc ID sai.")

if __name__ == "__main__":
    start_chat()
