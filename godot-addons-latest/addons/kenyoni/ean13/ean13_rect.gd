@tool
@icon("res://addons/kenyoni/ean13/icon.svg")
extends TextureRect
class_name EAN13Rect

const Ean13 := preload("res://addons/kenyoni/ean13/ean13.gd")
const Ean13Renderer := preload("res://addons/kenyoni/ean13/renderer.gd")

## The number to generate the EAN-13 code for. Must be 12 or 13 digits long. If 12 digits are given, the checksum digit is calculated automatically.
## Non-digit characters are automatically removed.
var number: String = "":
    set = set_number,
    get = get_number

## Automatically update the texture when a property changes.
var auto_update: bool = true:
    set = set_auto_update

## Color of the background.
var background_color: Color = Color.WHITE:
    set = set_background_color
## Color of the bars.
var bar_color: Color = Color.BLACK:
    set = set_bar_color
## Automatically set the module pixel size based on the size.
## Do not use expand mode KEEP_SIZE when using it.
## Turn this off when the EAN13 code is resized often, as it impacts the performance quite heavily.
var auto_module_size: bool = true:
    set = set_auto_module_size
## Use that many pixel for one module.
var module_size: int = 3:
    set = set_module_size
## Include the quiet zone around the EAN13 code.
var add_quiet_zone: bool = true:
    set = set_add_quiet_zone
## Include the text representation of the EAN13 number below the code.
## Requires add_quiet_zone to be true.
var show_text: bool = true:
    set = set_show_text
var text_font: Font = null:
    set = set_text_font
## Draw the right quiet zone indicator (an arrow).
## Requires show_text to be true.
var show_quiet_zone_indicator: bool = false:
    set = set_show_quiet_zone_indicator

## The effective number used to generate the EAN13 code, including the checksum digit.
var _ean13_value: String = "0000000000000"

var _update_fn: Callable = self.update
var _cached_data: PackedByteArray = PackedByteArray()

var _renderer: Ean13Renderer = Ean13Renderer.new()

func set_number(new_number: String) -> void:
    new_number = Ean13._number_rx.sub(new_number, "", true)
    if new_number.length() > 13:
        new_number = new_number.substr(0, 13)
    if number == new_number:
        return
    self.update_configuration_warnings()
    number = new_number
    if self.auto_update:
        self.update()

func get_number() -> String:
    return number

func set_auto_update(new_auto_update: bool) -> void:
    if auto_update == new_auto_update:
        return
    auto_update = new_auto_update
    self.notify_property_list_changed()
    if auto_update:
        self.update()

func set_background_color(new_color: Color) -> void:
    if background_color == new_color:
        return
    background_color = new_color
    self._renderer.background_color = new_color
    if self.auto_update:
        self._update_texture()

func set_bar_color(new_color: Color) -> void:
    if bar_color == new_color:
        return
    bar_color = new_color
    self._renderer.bar_color = new_color
    if self.auto_update:
        self._update_texture()

func set_auto_module_size(new_auto: bool) -> void:
    if auto_module_size == new_auto:
        return
    auto_module_size = new_auto
    self.notify_property_list_changed()
    self.update_configuration_warnings()
    if self.auto_update:
        self._update_texture()

func set_module_size(new_size: int) -> void:
    if module_size == new_size:
        return
    module_size = new_size
    self._renderer.module_size = new_size
    if self.auto_update:
        self._update_texture()

func set_add_quiet_zone(new_add_quiet_zone: bool) -> void:
    if add_quiet_zone == new_add_quiet_zone:
        return
    add_quiet_zone = new_add_quiet_zone
    self.notify_property_list_changed()
    self._renderer.add_quiet_zone = new_add_quiet_zone
    if self.auto_update:
        self._update_texture()

func set_show_text(new_show_text: bool) -> void:
    if show_text == new_show_text:
        return
    show_text = new_show_text
    self.notify_property_list_changed()
    self._renderer.show_text = new_show_text
    if self.auto_update:
        self._update_texture()

func set_text_font(new_font: Font) -> void:
    if text_font == new_font:
        return
    text_font = new_font
    self._renderer.text_font = new_font if new_font != null else ThemeDB.fallback_font
    if self.auto_update:
        self._update_texture()

func set_show_quiet_zone_indicator(new_value: bool) -> void:
    if show_quiet_zone_indicator == new_value:
        return
    show_quiet_zone_indicator = new_value
    self._renderer.show_quiet_zone_indicator = new_value
    if self.auto_update:
        self._update_texture()

func _ready() -> void:
    self._renderer.background_color = self.background_color
    self._renderer.bar_color = self.bar_color
    self._renderer.module_size = self.module_size
    self._renderer.add_quiet_zone = self.add_quiet_zone
    self._renderer.show_text = self.show_text
    self._renderer.text_font = self.text_font if self.text_font != null else ThemeDB.fallback_font
    self._renderer.show_quiet_zone_indicator = self.show_quiet_zone_indicator

    if self.texture == null && self.auto_update:
        self.update()

## The effective number used to generate the EAN-13 code, including the checksum digit.
## Only set if update was called.
func ean13() -> String:
    return self._ean13_value

## Updates the EAN-13 code and texture based on the current properties.
func update() -> void:
    var number: String = self.number
    if number == "":
        number = "000000000000"
    if number.length() < 12:
        number = number.pad_zeros(12)
    if number.length() == 12:
        var checksum_digit: int = Ean13.checksum(int(number))
        number += str(checksum_digit)
    self._ean13_value = number
    self._cached_data = Ean13.encode(number)
    self._update_texture()

func _set(property: StringName, value: Variant) -> bool:
    if property == "expand_mode":
        self.update_configuration_warnings()

    return false

func _get(property: StringName) -> Variant:
    match property:
        "ean13_number":
            return self._ean13_value
    return null

func _get_property_list() -> Array[Dictionary]:
    var props: Array[Dictionary] = [
        {
            "name": "_update_fn",
            "type": TYPE_CALLABLE,
            "usage": PROPERTY_USAGE_EDITOR if !self.auto_update else PROPERTY_USAGE_NONE,
            "hint": PROPERTY_HINT_TOOL_BUTTON,
            "hint_string": "Update"
        },
        {
            "name": "auto_update",
            "type": TYPE_BOOL,
            "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
        },
        {
            "name": "number",
            "type": TYPE_STRING,
            "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
        },
    ]

    if Engine.is_editor_hint():
        props.append({
            "name": "ean13_number",
            "type": TYPE_STRING,
            "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY,
        })

    props.append_array([
        {
            "name": "Appearance",
            "type": TYPE_NIL,
            "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_GROUP,
        },
        {
            "name": "background_color",
            "type": TYPE_COLOR,
            "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
        },
        {
            "name": "bar_color",
            "type": TYPE_COLOR,
            "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
        },
        {
            "name": "auto_module_size",
            "type": TYPE_BOOL,
            "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
        },
        {
            "name": "module_size",
            "type": TYPE_INT,
            "usage": (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY) if self.auto_module_size else (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE),
            "hint": PROPERTY_HINT_RANGE,
            "hint_string": "1,1,or_greater"
        },
        {
            "name": "add_quiet_zone",
            "type": TYPE_BOOL,
            "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
        },
        {
            "name": "show_text",
            "type": TYPE_BOOL,
            "usage": (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE) if self.add_quiet_zone else (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_READ_ONLY),
        },
        {
            "name": "show_quiet_zone_indicator",
            "type": TYPE_BOOL,
            "usage": (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE) if self.add_quiet_zone else (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_READ_ONLY),
        },
        {
            "name": "text_font",
            "type": TYPE_OBJECT,
            "hint": PROPERTY_HINT_RESOURCE_TYPE,
            "hint_string": "Font",
            "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
        }
    ])

    return props

func _validate_property(property: Dictionary) -> void:
    if property.name == "texture":
        property.usage &= ~(PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE)

func _property_can_revert(property: StringName) -> bool:
    return property in ["background_color", "bar_color", "auto_module_size", "add_quiet_zone", "show_text", "show_quiet_zone_indicator"]

func _property_get_revert(property: StringName) -> Variant:
    match property:
        "background_color":
            return Color.WHITE
        "bar_color":
            return Color.BLACK
        "auto_module_size":
            return true
        "add_quiet_zone":
            return true
        "show_text":
            return true
        "show_quiet_zone_indicator":
            return false
        _:
            return null

func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = PackedStringArray()
    if number.length() == 13 && !Ean13.validate(number):
        warnings.append("EAN-13 number has an invalid checksum digit.")
    if self.auto_module_size && self.expand_mode == EXPAND_KEEP_SIZE:
        warnings.append("Do not use auto module px size AND keep size expand mode.")
    return warnings

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_RESIZED:
            if self.auto_module_size && self.auto_update:
                self._update_texture()
            elif self.auto_module_size:
                self._update_module_size()

func _update_module_size() -> void:
    self.module_size = Ean13Renderer.calculate_module_size(self.size, self.add_quiet_zone)

func _update_texture() -> void:
    if self.auto_module_size:
        self._update_module_size()
    var image: Image = await self._renderer.generate_image(self._ean13_value, self._cached_data)
    if image != null:
        self.texture = ImageTexture.create_from_image(image)
    else:
        self.texture = null
