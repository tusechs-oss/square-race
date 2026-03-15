extends HBoxContainer

@export var _input_number: LineEdit
@export var _bar_color: ColorPickerButton
@export var _background_color: ColorPickerButton
@export var _auto_module_px_size: CheckBox
@export var _module_px_size: SpinBox
@export var _add_quiet_zone: CheckButton
@export var _show_quiet_zone_indicator: CheckButton
@export var _show_text: CheckButton
@export var _ean13_label: Label

@export var _ean13_rect: EAN13Rect

func _ready():
	self._input_number.text_changed.connect(self._on_input_number_text_changed)
	self._bar_color.color_changed.connect(self._on_bar_color_color_changed)
	self._background_color.color_changed.connect(self._on_background_color_color_changed)
	self._auto_module_px_size.toggled.connect(self._on_auto_module_px_size_toggled)
	self._module_px_size.value_changed.connect(self._on_module_px_size_value_changed)
	self._add_quiet_zone.toggled.connect(self._on_add_quiet_zone_toggled)
	self._show_quiet_zone_indicator.toggled.connect(self._on_show_quiet_zone_indicator_toggled)
	self._show_text.toggled.connect(self._on_show_text_toggled)
	
	self._update_values()
	self._ean13_rect.update()

func _update_values() -> void:
	self._input_number.text = self._ean13_rect.number
	self._bar_color.color = self._ean13_rect.bar_color
	self._background_color.color = self._ean13_rect.background_color
	self._auto_module_px_size.button_pressed = self._ean13_rect.auto_module_size
	self._module_px_size.value = self._ean13_rect.module_size
	self._module_px_size.editable = !self._ean13_rect.auto_module_size
	self._add_quiet_zone.button_pressed = self._ean13_rect.add_quiet_zone
	self._show_text.disabled = !self._ean13_rect.add_quiet_zone
	self._show_text.button_pressed = self._ean13_rect.show_text
	self._show_quiet_zone_indicator.disabled = !self._ean13_rect.show_text
	self._show_quiet_zone_indicator.button_pressed = self._ean13_rect.show_quiet_zone_indicator
	self._ean13_label.text = self._ean13_rect.ean13()

func _on_input_number_text_changed(text: String) -> void:
	self._ean13_rect.number = text
	var cc: int = self._input_number.caret_column
	self._update_values()
	self._input_number.caret_column = cc

func _on_bar_color_color_changed(color: Color) -> void:
	self._ean13_rect.bar_color = color
	self._update_values()

func _on_background_color_color_changed(color: Color) -> void:
	self._ean13_rect.background_color = color
	self._update_values()

func _on_auto_module_px_size_toggled(button_pressed: bool) -> void:
	self._ean13_rect.auto_module_size = button_pressed
	self._module_px_size.editable = !button_pressed
	self._update_values()

func _on_module_px_size_value_changed(value: float) -> void:
	self._ean13_rect.module_size = int(value)
	self._update_values()

func _on_add_quiet_zone_toggled(button_pressed: bool) -> void:
	self._ean13_rect.add_quiet_zone = button_pressed
	self._update_values()

func _on_show_quiet_zone_indicator_toggled(button_pressed: bool) -> void:
	self._ean13_rect.show_quiet_zone_indicator = button_pressed
	self._update_values()

func _on_show_text_toggled(button_pressed: bool) -> void:
	self._ean13_rect.show_text = button_pressed
	self._update_values()
