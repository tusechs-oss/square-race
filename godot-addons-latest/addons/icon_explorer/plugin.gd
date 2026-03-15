@tool
extends EditorPlugin

const ExplorerScene: PackedScene = preload("res://addons/icon_explorer/internal/ui/explorer/explorer.tscn")
const ExplorerDialog := preload("res://addons/icon_explorer/internal/ui/explorer_dialog.gd")
const ExplorerDialogScene: PackedScene = preload("res://addons/icon_explorer/internal/ui/explorer_dialog.tscn")
const MainScreen := preload("res://addons/icon_explorer/internal/ui/main_screen.gd")
const MainScreenScene := preload("res://addons/icon_explorer/internal/ui/main_screen.tscn")
const IconDatabase := preload("res://addons/icon_explorer/internal/scripts/database.gd")

const CFG_KEY_LOAD_ON_STARTUP: String = "plugins/icon_explorer/load_on_startup"
const CFG_KEY_SHOW_MAIN_SCREEN: String = "plugins/icon_explorer/show_main_screen"
const CFG_KEY_PREVIEW_SIZE_EXP: String = "plugins/icon_explorer/preview_size_exp"

var _explorer_dialog: ExplorerDialog
var _main_screen: MainScreen = null

var _db: IconDatabase
var _db_loaded: bool = false

func _get_plugin_name() -> String:
    return "Icon Explorer"

func _get_plugin_icon() -> Texture2D:
    return preload("res://addons/icon_explorer/icon.svg")

func _enter_tree() -> void:
    set_editor_setting(CFG_KEY_LOAD_ON_STARTUP, false, TYPE_BOOL, PROPERTY_HINT_NONE)
    set_editor_setting(CFG_KEY_SHOW_MAIN_SCREEN, true, TYPE_BOOL, PROPERTY_HINT_NONE)
    # this could be actually window layout state, but this would be complicated to save back and forth
    set_editor_setting(CFG_KEY_PREVIEW_SIZE_EXP, 6, TYPE_INT, PROPERTY_HINT_RANGE, "4,8,1")

    # TODO: remove later
    var settings: EditorSettings = EditorInterface.get_editor_settings()
    if ProjectSettings.has_setting("plugins/icon_explorer/preview_size_exp"):
        settings.set_setting(CFG_KEY_PREVIEW_SIZE_EXP, ProjectSettings.get_setting("plugins/icon_explorer/preview_size_exp", 6))
        ProjectSettings.set_setting("plugins/icon_explorer/preview_size_exp", null)
    if ProjectSettings.has_setting("plugins/icon_explorer/load_on_startup"):
        settings.set_setting(CFG_KEY_LOAD_ON_STARTUP, ProjectSettings.get_setting("plugins/icon_explorer/load_on_startup", false))
        ProjectSettings.set_setting("plugins/icon_explorer/load_on_startup", null)
    if ProjectSettings.has_setting("plugins/icon_explorer/show_main_screen"):
        settings.set_setting(CFG_KEY_SHOW_MAIN_SCREEN, ProjectSettings.get_setting("plugins/icon_explorer/show_main_screen", true))
        ProjectSettings.set_setting("plugins/icon_explorer/show_main_screen", null)

    self._explorer_dialog = ExplorerDialogScene.instantiate()
    EditorInterface.get_base_control().add_child(self._explorer_dialog)
    self.add_tool_menu_item(self._get_plugin_name() + "...", self._show_popup)

    self._db = IconDatabase.new(self.get_tree())
    self._db.collection_installed.connect(self._on_collection_changed.bind(true))
    self._db.collection_removed.connect(self._on_collection_changed.bind(false))
    self._explorer_dialog.set_icon_db(self._db)
    if self._has_main_screen():
        self._main_screen = MainScreenScene.instantiate()
        self._main_screen.set_icon_db(self._db)
        EditorInterface.get_editor_main_screen().add_child(self._main_screen)
        self._main_screen.hide()

    if settings.get_setting(CFG_KEY_LOAD_ON_STARTUP):
        self._db.load()

func _exit_tree() -> void:
    if self._main_screen != null:
        EditorInterface.get_editor_main_screen().remove_child(self._main_screen)
        self._main_screen.free()
    self.remove_tool_menu_item(self._get_plugin_name() + "...")
    self._explorer_dialog.free()

func _has_main_screen() -> bool:
    var settings: EditorSettings = EditorInterface.get_editor_settings()
    return !settings.has_setting(CFG_KEY_SHOW_MAIN_SCREEN) || settings.get_setting(CFG_KEY_SHOW_MAIN_SCREEN)

func _make_visible(visible: bool) -> void:
    if !self._db_loaded:
        self._db_loaded = true
        self._db.load()
    self._main_screen.visible = visible
    if visible:
        self._main_screen.grab_focus()

func _show_popup() -> void:
    if self._explorer_dialog.visible:
        self._explorer_dialog.grab_focus()
    else:
        self._explorer_dialog.popup_centered_ratio(0.4)

func _on_collection_changed(id: int, status: Error, is_installation: bool):
    var msg: String = "[Icon Explorer] '" + self._db.get_collection(id).name + "' "
    if is_installation:
        if status == Error.OK:
            msg += "successfully installed."
        else:
            msg += "installation failed."
    else:
        if status == Error.OK:
            msg += "successfully removed."
        else:
            msg += "removing failed."
    print(msg)

static func set_editor_setting(key: String, initial_value: Variant, type: Variant.Type, type_hint: PropertyHint, hint_string: String = "") -> void:
    var settings: EditorSettings = EditorInterface.get_editor_settings()
    if !settings.has_setting(key):
        settings.set_setting(key, initial_value)
    settings.set_initial_value(key, initial_value, false)
    settings.add_property_info({
        "name": key,
        "type": type,
        "hint": type_hint,
        "hint_string": hint_string,
    })
