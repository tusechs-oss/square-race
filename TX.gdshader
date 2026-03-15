shader_type canvas_item;

uniform float width : hint_range(0.0, 0.5) = 0.05; // Độ dày viền (0.0 đến 0.5)
uniform float speed : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    // Lấy tọa độ UV (từ 0 đến 1)
    vec2 uv = UV;
    
    // Kiểm tra xem pixel hiện tại có nằm trong vùng viền không
    // (Gần mép 0.0 hoặc gần mép 1.0)
    bool is_border = uv.x < width || uv.x > 1.0 - width || uv.y < width || uv.y > 1.0 - width;

    if (is_border) {
        // Tạo màu cầu vồng dựa trên thời gian
        float hue = TIME * speed;
        vec3 rainbow = 0.5 + 0.5 * cos(hue + uv.xyx + vec3(0, 2, 4));
        COLOR = vec4(rainbow, 1.0);
    } else {
        // Giữ nguyên màu gốc (trong hình của bạn là màu trắng)
        COLOR = texture(TEXTURE, UV);
    }
}