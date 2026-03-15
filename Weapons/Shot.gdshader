shader_type canvas_item;

// Khai báo các biến có thể chỉnh sửa trong Inspector
uniform vec4 blood_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Màu đỏ máu
uniform float glow_power : hint_range(1.0, 20.0) = 5.0;            // Độ rực sáng

void fragment() {
    // Lấy màu gốc từ Texture của hạt
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Lấy màu và độ trong suốt (Alpha) gốc của hạt
    COLOR = tex_color * COLOR;
    
    // Áp dụng màu máu và nhân với độ rực sáng
    COLOR.rgb *= blood_color.rgb * glow_power;
}