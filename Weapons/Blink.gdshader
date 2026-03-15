shader_type canvas_item;

// mix_weight từ 0.0 (bình thường) đến 1.0 (trắng hoàn toàn
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    // Hòa trộn màu gốc với màu flash dựa trên trọng số flash_modifier
    color.rgb = mix(color.rgb, flash_color.rgb, flash_modifier);
    COLOR = color;
}