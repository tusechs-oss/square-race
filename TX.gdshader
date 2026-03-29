shader_type canvas_item;

uniform float width : hint_range(0.0, 0.5) = 0.05; 
uniform float speed : hint_range(0.0, 10.0) = 2.0;

// Hiệu ứng chết cháy
uniform sampler2D noise_tex; 
uniform float dissolve_value : hint_range(0.0, 1.1) = 0.0; 
uniform vec3 burn_color : source_color = vec3(2.0, 0.5, 0.0); 
uniform float burn_size : hint_range(0.0, 0.3) = 0.1; 

void fragment() {
    vec2 uv = UV;
    float noise = texture(noise_tex, uv).r;
    
    // 1. Xóa pixel nếu bị tan biến (Dissolve)
    if (noise < dissolve_value) {
        discard;
    }

    // 2. Xác định màu nền (Texture hoặc Viền cầu vồng)
    vec4 base_color = texture(TEXTURE, uv);
    bool is_border = uv.x < width || uv.x > 1.0 - width || uv.y < width || uv.y > 1.0 - width;

    if (is_border) {
        float hue = TIME * speed;
        vec3 rainbow = 0.5 + 0.5 * cos(hue + uv.xyx + vec3(0, 2, 4));
        base_color = vec4(rainbow, 1.0);
    }

    // 3. Tạo hiệu ứng viền lửa cháy (Burn Edge) với Gradient
    float burn_edge = step(noise, dissolve_value + burn_size);
    // Tạo gradient mượt cho lửa
    float edge_intensity = smoothstep(dissolve_value, dissolve_value + burn_size, noise);
    edge_intensity = 1.0 - edge_intensity; // Đảo ngược để tâm cháy rực nhất
    
    vec3 final_burn_color = burn_color * edge_intensity * 1.5; // Làm rực màu lên
    
    // Trộn màu gốc với màu lửa dựa trên vùng cháy
    vec3 final_rgb = mix(base_color.rgb, final_burn_color, burn_edge * edge_intensity);
    
    COLOR = vec4(final_rgb, base_color.a);
}