shader_type canvas_item;

uniform sampler2D noise_tex; // Dùng để tạo vết cháy rách rưới 
uniform float dissolve_value : hint_range(0.0, 1.1) = 0.0; // Thanh trượt từ 0 đến 1 
uniform vec3 burn_color : source_color = vec3(2.0, 0.5, 0.0); // Màu lửa phát sáng (cam rực) 
uniform float burn_size : hint_range(0.0, 0.2) = 0.05; // Độ rộng viền lửa

void fragment() { 
     // Lấy màu gốc của model (hình mặt người của bạn) 
     vec4 albedo_color = texture(TEXTURE, UV); 
     
     // Lấy giá trị từ ảnh nhiễu (noise) 
     float noise = texture(noise_tex, UV).r; 
     
     // Tạo hiệu ứng đục lỗ (Dissolve) 
     // Nếu giá trị noise nhỏ hơn dissolve_value thì xóa pixel đó đi 
     if (noise < dissolve_value) { 
         discard; 
     } 
 
     // Tạo viền lửa cháy rực rỡ 
     float stop1 = dissolve_value; 
     float stop2 = dissolve_value + burn_size; 
     
     // Kiểm tra xem pixel có nằm trong vùng đang cháy không 
     float burn_mask = step(noise, stop2) * (1.0 - step(noise, stop1)); 
     
     // Trộn màu gốc với màu lửa phát sáng 
     vec3 final_color = mix(albedo_color.rgb, burn_color, burn_mask); 
     
     COLOR = vec4(final_color, albedo_color.a); 
 }