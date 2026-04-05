shader_type canvas_item;

// --- Thông số chỉnh màu (Tinting) ---
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Màu phủ
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0; // Độ mạnh của màu phủ

// --- Thông số nhấp nháy (Flash/Blink) ---
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0; // 0.0: gốc, 1.0: màu flash
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Màu flash

// --- Thông số viền (Outline) ---
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Màu viền
uniform float line_thickness : hint_range(0, 10) = 1.0; // Độ dày viền

void fragment() {
    // 1. Lấy màu gốc từ texture
    vec4 color = texture(TEXTURE, UV);
    
    // 2. XỬ LÝ CHỈNH MÀU (TINTING)
    vec4 processed_color = color;
    processed_color.rgb = mix(color.rgb, tint_color.rgb, tint_amount);
    
    // 3. XỬ LÝ NHẤP NHÁY (FLASH)
    // Áp dụng flash sau khi đã tint để flash có màu chính xác
    processed_color.rgb = mix(processed_color.rgb, flash_color.rgb, flash_modifier);
    
    // 4. XỬ LÝ VIỀN (OUTLINE)
    vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
    float outline = 0.0;
    
    // Kiểm tra 8 điểm ảnh xung quanh để tạo viền
    outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
    
    outline = min(outline, 1.0);
    
    // 5. KẾT HỢP MÀU ĐÃ XỬ LÝ VÀ VIỀN
    // Trộn màu đã xử lý với màu viền dựa trên độ alpha của vùng viền
    vec4 final_color = mix(processed_color, line_color, outline - color.a);
    
    // Đảm bảo không bị mất alpha (độ trong suốt) gốc của ảnh và giữ viền
    final_color.a = max(processed_color.a, outline);
    
    COLOR = final_color;
}