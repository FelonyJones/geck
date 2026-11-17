@tool
extends EditorPlugin
class_name GeckPlugin

#TODO: Save history to disk
#TODO: Save custom context
#FIXME: error: Can't take value from empty array

const PLUGIN_NAME := "geck";
const SINGLETON_NAME = "GeckInterface";
const DEFAULT_SCRIPT_PATH = "res://addons/geck/scripts/"
const SETTINGS_PATH = "Addons/GEC(K)/"
const BUILTIN_COMMANDS = "./builtin_commands.gd"

const GeckGui := preload("./console_gui.gd");
const GeckInterface := preload("./console_api.gd");
const GeckConsole = preload("./console.gd");


var console_gui : GeckGui = preload("./console_gui.tscn").instantiate()
var api : GeckInterface;
var console : GeckConsole;

func _init() -> void:
	name = "GeckPlugin"


func _enable_plugin() -> void:
	add_autoload_singleton(SINGLETON_NAME, "./console_api.gd");
	pass;


func _enter_tree() -> void:
	_init_settings();

	console_gui.plugin = self;
	add_dock(console_gui)

	api = await search_for_singleton();
	if not api:
		printerr("[GEC(K)] failed to find singleton")
		return;
	api.set("plugin", self);

	console = GeckConsole.new(api);
	console_gui.api = api;

	print("[GEC(K)] inited singleton")
	print(api)


func _exit_tree() -> void:
	remove_dock(console_gui)
	console_gui.queue_free()


func _disable_plugin() -> void:
	pass;


func get_singleton():
	return get_tree().root.get_node("/root/" + SINGLETON_NAME)


func search_for_singleton() -> Node:
	var singleton = get_tree().root.get_node_or_null("/root/" + SINGLETON_NAME);
	var timestamp = Time.get_unix_time_from_system()
	var timeout = 5;

	while singleton == null:
		singleton = get_tree().root.get_node_or_null("/root/" + SINGLETON_NAME);

		if singleton != null:
			break;

		if Time.get_unix_time_from_system() - timestamp > timeout:
			printerr("[GEC(K)] timed out trying to find singleton")
			return null

		await get_tree().process_frame

	return singleton


func _init_settings():
	_register_setting("scripts_folder", DEFAULT_SCRIPT_PATH, Variant.Type.TYPE_STRING, PROPERTY_HINT_FILE_PATH);
	_register_setting("default_slot", EditorDock.DockSlot.DOCK_SLOT_BOTTOM_L, Variant.Type.TYPE_INT);
	pass


func _register_setting(path: String, default_value: Variant, type: Variant.Type, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	if not path.begins_with(SETTINGS_PATH.left(SETTINGS_PATH.length() - 1)):
		if not path.begins_with("/"): path = "/" + path;
		path = "Addons/GEC(K)" + path;
		pass
	
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, default_value);
	
	ProjectSettings.set_initial_value(path, default_value);
	
	ProjectSettings.add_property_info({
		"name": path,
		"type": type,
		"hint": hint,
		"hint_string": hint_string
	});
