## The Renderer is only rudimentary validating the input data. It assumes correctly set options and data.
@tool
extends RefCounted
class_name __KenyoniEan13Renderer

const Ean13 := preload("res://addons/kenyoni/ean13/ean13.gd")

## Size of the quiet zone in modules
const _LEFT_QUIET_ZONE_SIZE: int = 11
## Size of the quiet zone in modules
const _RIGHT_QUIET_ZONE_SIZE: int = 7
## Height ratio based on standard EAN-13 dimensions
const _BAR_HEIGHT_FACTOR: float = 22.85 / 31.35
## Total height ratio based on standard EAN-13 dimensions
const _TOTAL_HEIGHT_FACTOR: float = 25.93 / 37.29

var background_color: Color
var bar_color: Color
var module_size: int = 1
var add_quiet_zone: bool
var show_text: bool
var text_font: Font
var show_quiet_zone_indicator: bool

var _viewport_rid: RID
var _canvas_rid: RID
var _canvas_item_rid: RID

func _init() -> void:
    self._viewport_rid = RenderingServer.viewport_create()
    self._canvas_rid = RenderingServer.canvas_create()
    self._canvas_item_rid = RenderingServer.canvas_item_create()
    RenderingServer.canvas_item_set_parent(self._canvas_item_rid, self._canvas_rid)
    RenderingServer.viewport_attach_canvas(self._viewport_rid, self._canvas_rid)
    RenderingServer.viewport_set_active(self._viewport_rid, true)

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        RenderingServer.viewport_remove_canvas(self._viewport_rid, self._canvas_rid)
        RenderingServer.free_rid(self._canvas_item_rid)
        RenderingServer.free_rid(self._canvas_rid)
        RenderingServer.free_rid(self._viewport_rid)

## Generates an Image of the EAN-13 barcode based on the provided encoded data.
## Asynchronous method. For a synchronous version without text rendering call `generate_image_no_text`.
## Returns `null` if rendering failed.
func generate_image(ean13: String, encoded_data: PackedByteArray) -> Image:
    if self.module_size <= 0 || len(ean13) != 13 || encoded_data.size() != 95:
        return null
    var normal_height: int = _normal_height(self.module_size)
    var guards_height: int = normal_height + _guards_extra_height(self.module_size)
    var size: Vector2i = Vector2i(95 * self.module_size, guards_height)
    if self.add_quiet_zone:
        size.x += (_LEFT_QUIET_ZONE_SIZE + _RIGHT_QUIET_ZONE_SIZE) * self.module_size
        size.y = roundi(113.0 * self.module_size * _TOTAL_HEIGHT_FACTOR)

    var image: Image = null
    if self.add_quiet_zone && self.show_text:
        image = await self._create_text_layer(size, ean13)
        if image == null:
            return null
    else:
        image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8)
        image.fill_rect(Rect2i(Vector2i.ZERO, size), self.background_color)

    self._draw_bars(image, normal_height, guards_height, encoded_data)

    if self.add_quiet_zone && self.show_text && self.show_quiet_zone_indicator:
        self._draw_quiet_zone_indicator(image, normal_height)

    return image

## Generates an Image of the EAN-13 barcode based on the provided encoded data, without rendering the text.
func generate_image_no_text(encoded_data: PackedByteArray) -> Image:
    if self.module_size <= 0 || encoded_data.size() != 95:
        return null

    var normal_height: int = _normal_height(self.module_size)
    var guards_height: int = normal_height + _guards_extra_height(self.module_size)
    var size: Vector2i = Vector2i(95 * self.module_size, guards_height)
    if self.add_quiet_zone:
        size.x += (_LEFT_QUIET_ZONE_SIZE + _RIGHT_QUIET_ZONE_SIZE) * self.module_size
        size.y = roundi(113.0 * self.module_size * _TOTAL_HEIGHT_FACTOR)

    var image: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8)
    image.fill_rect(Rect2i(Vector2i.ZERO, size), self.background_color)

    self._draw_bars(image, normal_height, guards_height, encoded_data)

    if self.add_quiet_zone && self.show_text && self.show_quiet_zone_indicator:
        self._draw_quiet_zone_indicator(image, normal_height)

    return image

## renderer.module_size and texture_size have to match.
func _create_text_layer(texture_size: Vector2i, ean13: String) -> Image:
    if self.text_font == null:
        return null

    # get character sizes
    var digit_widths: Array[float] = []
    digit_widths.resize(10)

    var max_digit_size: Vector2 = Vector2.ZERO
    for dig: int in range(10):
        var size: Vector2 = self.text_font.get_char_size(ord("0") + dig, 10)
        digit_widths[dig] = size.x
        max_digit_size.x = max(max_digit_size.x, size.x)
        max_digit_size.y = max(max_digit_size.y, size.y)

    if max_digit_size.x <= 0.0 || max_digit_size.y <= 0.0:
        return null

    var slot_width: float = (41.0 * self.module_size) / 6.0

    # get font size
    var target_height: int = texture_size.y - roundi(95.0 * self.module_size * _BAR_HEIGHT_FACTOR) - self.module_size
    var scale_w: float = (slot_width * 10.0) / max_digit_size.x
    var scale_h: float = (float(target_height) * 10.0) / max_digit_size.y
    # scale with 2 is actually correct
    var font_size: int = int(2.0 * min(scale_w, scale_h))
    # adjust digit widths
    for idx: int in range(10):
        digit_widths[idx] = digit_widths[idx] * (font_size / 10.0)

    # draw
    RenderingServer.viewport_set_update_mode(self._viewport_rid, RenderingServer.VIEWPORT_UPDATE_ONCE)
    RenderingServer.viewport_set_size(self._viewport_rid, texture_size.x, texture_size.y)
    RenderingServer.canvas_item_add_rect(self._canvas_item_rid, Rect2(Vector2.ZERO, texture_size), self.background_color)

    self.text_font.draw_char(self._canvas_item_rid, Vector2(0, texture_size.y), ord(ean13[0]), font_size, self.bar_color)

    var groups: Array[Vector2i] = [
        Vector2i(1, 4),
        Vector2i(7, 50),
    ]
    var ord_zero: int = ord("0")

    for group: Vector2i in groups:
        var x_offset: int = (_LEFT_QUIET_ZONE_SIZE + group.y) * self.module_size

        for idx: int in range(6):
            var chr: String = ean13[group.x + idx]
            var chr_ord: int = ord(chr)
            var x_pos: float = x_offset + idx * slot_width + (slot_width - digit_widths[chr_ord - ord_zero]) * 0.5
            self.text_font.draw_char(self._canvas_item_rid, Vector2(x_pos, texture_size.y), chr_ord, font_size, self.bar_color)

    await RenderingServer.frame_post_draw

    return RenderingServer.texture_2d_get(RenderingServer.viewport_get_texture(self._viewport_rid))

func _draw_bars(image: Image, normal_height: int, guards_height: int, encoded_data: PackedByteArray) -> void:
    for idx: int in range(encoded_data.size()):
        if encoded_data[idx] == 1:
            var is_guard: bool = (idx <= 2) || (idx >= 45 && idx <= 49) || (idx >= 92)
            var current_height: int = guards_height if is_guard else normal_height

            var x_pos: int = idx * self.module_size
            if self.add_quiet_zone:
                x_pos += _LEFT_QUIET_ZONE_SIZE * self.module_size
            var rect: Rect2i = Rect2i(x_pos, 0, self.module_size, current_height)
            image.fill_rect(rect, self.bar_color)

func _draw_quiet_zone_indicator(image: Image, normal_height: int) -> void:
    var indicator_height: int = image.get_height() - normal_height - 2 * self.module_size
    var half_height: int = indicator_height / 2
    # one pixel space to bottom
    var center_y: int = (image.get_height() - 1) - half_height
    
    var tip_x = image.get_width() - 1
    var thickness: int = int(1.8 * self.module_size)

    for idx: int in range(half_height + 1):
        var p_x: int = tip_x - idx
        var draw_x: int = p_x - (thickness - 1)

        image.fill_rect(Rect2i(draw_x, center_y - idx, thickness, 1), self.bar_color)
        image.fill_rect(Rect2i(draw_x, center_y + idx, thickness, 1), self.bar_color)

## Calculates the module size based on the target image size and whether quiet zones are included. This ensures that the generated barcode fits within the specified dimensions while maintaining the correct proportions.
static func calculate_module_size(target_size: Vector2i, add_quiet_zone: bool) -> int:
    var mod_x: float
    var mod_y: float
    
    if add_quiet_zone:
        mod_x = target_size.x / float(95 + _LEFT_QUIET_ZONE_SIZE + _RIGHT_QUIET_ZONE_SIZE)
        mod_y = target_size.y / (113 * _TOTAL_HEIGHT_FACTOR)
    else:
        mod_x = target_size.x / 95.0
        mod_y = target_size.y / (95 * _BAR_HEIGHT_FACTOR + 5)

    return floori(mini(mod_x, mod_y))

static func _normal_height(module_size: int) -> int:
    return roundi(95.0 * module_size * _BAR_HEIGHT_FACTOR)

static func _guards_extra_height(module_size: int) -> int:
    return 5 * module_size
