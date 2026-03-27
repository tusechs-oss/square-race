@tool
extends EditorPlugin

var importer

func _enter_tree() -> void:
	# 确保 GDExtension 已加载
	if not ClassDB.class_exists("ResourceImporterGIFTexture"):
		push_error("Godot-GIF: GDExtension not loaded")
		return
	
	# 注册导入插件
	importer = ResourceImporterGIFTexture.new()
	add_import_plugin(importer)
	
	# ResourcePreviewGIFTexture 会自动被 Godot 编辑器发现
	# 不需要手动注册

func _exit_tree() -> void:
	if importer:
		remove_import_plugin(importer)
		importer = null
