@tool
extends EditorPlugin
class_name EditorConsolePlugin

#TODO: Save history to disk
#TODO: Save custom context
#FIXME: error: Can't take value from empty array

const PLUGIN_NAME := "editor-console";
const SINGLETON_NAME = "EditorConsoleApi";
const DEFAULT_SCRIPT_PATH = "res://addons/editor-console/scripts/"

var console_gui := preload("./console_gui.tscn").instantiate()
var api := preload("./console_api.gd").new()
var executor := preload("./executor.gd").new()

var script_path := DEFAULT_SCRIPT_PATH;

var _context : Dictionary[String, Variant] = {}
var engine_singletons : Dictionary[String, Variant] = {}
var class_context : Dictionary[String, Variant] = {}
var custom_context : Dictionary[String, Variant] = {}
var misc_context : Dictionary[String, Variant] = {
	"execution_root" : self,
}

var _execution_root = self;


func _init() -> void:
	name = "EditorConsolePlugin"


func _enable_plugin() -> void:
	add_autoload_singleton(SINGLETON_NAME, "./console_api.gd");
	pass;


func _disable_plugin() -> void:
	pass;


func get_singleton():
	return get_tree().root.get_node("/root/" + SINGLETON_NAME)


func _enter_tree() -> void:
	console_gui.plugin = self;
	get_singleton().set("plugin", self);
	add_child(executor);
	executor.plugin = self;
	_execution_root = executor;
	add_dock(console_gui)

	_add_static_context()
	_add_builtin_singletons()
	_add_registered_singleton_names()
	rebuild_context();


func _exit_tree() -> void:
	remove_dock(console_gui)
	console_gui.queue_free()


func rebuild_context():
	_context = {};
	_context.merge(engine_singletons);
	_context.merge(class_context);
	_context.merge(custom_context);
	_context.merge(misc_context);


func _add_registered_singleton_names() -> void:
	for property in ProjectSettings.get_property_list():
		if property.name.begins_with("autoload/"):
			var singleton_name = property.name.get_slice("/", 1)
			class_context[singleton_name] = get_node("/root/%s" % singleton_name)


func _add_builtin_singletons():
	for name in Engine.get_singleton_list():
		engine_singletons[name] = Engine.get_singleton(name);


func _add_static_context():
	for dict in ProjectSettings.get_global_class_list():
		class_context[dict.class] = load(dict.path);
		pass
	pass


func parse_input(text: String):
	if try_parse_path(text): return;
	var args = text.split(" ");

	if executor.commands.has(args[0]):
		executor.commands[args[0]].call(args);
	else:
		eval_expr(text)


func try_parse_path(text: String) -> bool:
	var path := text;

	if text.is_relative_path():
		path = DEFAULT_SCRIPT_PATH + text;


	if not ResourceLoader.exists(path):
		return false;


	var script = load(path) as Script;
	if not script:
		echoerr("File is not a script: %s" % path);
		return true;


	if not script.has_method("_run"):
		echoerr("Script doesn't contain method \"_run\" method: %s" % path);
		return true;
	
	echo("Executing script: %s" % path.get_file())

	script.call("_run", _context)
	return true;


func eval_expr(text):
	var exp := Expression.new()
	var err: int = exp.parse(text, _context.keys())

	if err != OK:
		console_gui.printerrconsole(exp.get_error_text())
		return err

	var result = exp.execute(_context.values(), _execution_root, false)
	if not exp.has_execute_failed():
		if result != null:
			echo(str(result))
		return OK
	else:
		console_gui.printerrconsole(exp.get_error_text())
		return ERR_SCRIPT_FAILED


func change_root(node_path):
	var new_root = get_node_or_null(node_path);
	if not new_root:
		console_gui.printerrconsole("Node at path %s doesn't exist" % str(node_path));
		return;
	_execution_root = new_root;
	echo("Changed root to: %s" % str(node_path))


func add_context(name: String, object):
	if object is NodePath or object is String:
		var path = object as NodePath
		var node = get_node_or_null(path)
		if not node:
			console_gui.printerrconsole("Could not add context \"%s\"; node not found")
			return
		else:
			add_context(name, node);
		return
	custom_context[name] = object;
	rebuild_context();
	echo("Added \"%s\" to console context" % name)


func remove_context(name: String):
	custom_context.erase(name);
	rebuild_context();
	echo("Removed \"%s\" from console contex" % name)


func echo(text):
	console_gui.printconsole(text);


func echoerr(text):
	console_gui.printerrconsole(text);
