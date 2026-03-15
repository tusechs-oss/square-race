shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Màu viền
uniform float border_width : hint_range(0.0, 0.1) = 0.02;           // Độ dày viền
uniform float pixel_size : hint_range(1.0, 100.0) = 100;          // Độ "pixel hóa"

void fragment() {
    // 1. Tạo hiệu ứng Pixel (Downsampling)
    vec2 grid_uv = round(UV * pixel_size) / pixel_size;
    vec4 color = texture(TEXTURE, grid_uv);
    
    // 2. Tạo viền (Border)
    // Kiểm tra xem tọa độ UV có nằm ở sát mép không
    if (UV.x < border_width || UV.x > 1.0 - border_width || 
        UV.y < border_width || UV.y > 1.0 - border_width) {
        color = border_color;
    }
    
    COLOR = color;
}