@tool
extends EditorPlugin

const QrCodeRect := preload("res://addons/kenyoni/ean13/ean13_rect.gd")

func _enter_tree() -> void:
    self.add_custom_type("EAN13Rect", "TextureRect", QrCodeRect, preload("res://addons/kenyoni/ean13/icon.svg"))

func _exit_tree() -> void:
    self.remove_custom_type("EAN13Rect")
