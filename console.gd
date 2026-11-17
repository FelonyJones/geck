@tool
extends RefCounted

#TODO: Save history to disk
#TODO: Save custom context
#FIXME: error: Can't take value from empty array

const PLUGIN_NAME := "geck";
const SINGLETON_NAME = "GeckInterface";
const DEFAULT_SCRIPT_PATH = "res://addons/geck/scripts/"
const SETTINGS_PATH = "Addons/GEC(K)/"

const GeckGui       := preload("./console_gui.gd");
const GeckInterface := preload("./console_api.gd");
const BuiltinCommands := preload("./builtin_commands.gd");

var api : GeckInterface;
	
var _engine_singletons : Dictionary[String, Variant] = {}
var _class_context     : Dictionary[String, Variant] = {}
var _custom_context    : Dictionary[String, Variant] = {}
var _autoload_context  : Dictionary[String, Variant] = {}

var script_aliases : Dictionary[String, Dictionary] = {}

var _execution_root = api;

var custom_commands : Dictionary[StringName, Dictionary] = {};


func _init(new_api: GeckInterface) -> void:
	api = new_api;
	_execution_root = api;
	refresh_context();


# Context
# ---------------------------------

func refresh_context():
	var _get_registered_singleton_names = func() -> Dictionary[String, Variant]:
		var class_context: Dictionary[String, Variant] = {};
		for property in ProjectSettings.get_property_list():
			if property.name.begins_with("autoload/"):
				var singleton_name = property.name.get_slice("/", 1)
				class_context[singleton_name] = api.get_node("/root/%s" % singleton_name)
		return class_context;

	var _get_builtin_singletons = func() -> Dictionary[String, Variant]:
		var context: Dictionary[String, Variant] = {};
		for singleton_name in Engine.get_singleton_list():
			context[singleton_name] = Engine.get_singleton(singleton_name);
		return context;

	var _get_static_context = func() -> Dictionary[String, Variant]:
		var context: Dictionary[String, Variant] = {};
		for dict in ProjectSettings.get_global_class_list():
			context[dict.class] = load(dict.path);
		return context;

	_class_context = _get_static_context.call()
	_engine_singletons = _get_builtin_singletons.call()
	_autoload_context = _get_registered_singleton_names.call()


func get_context() -> Dictionary[String, Variant]:
	var context: Dictionary[String, Variant] = {};
	context.merge(_engine_singletons);
	context.merge(_class_context);
	context.merge(_custom_context);
	context.merge(_autoload_context);
	return context;


func get_commands() -> Dictionary[StringName, Dictionary]: 
	var commands: Dictionary[StringName, Dictionary] = {};

	commands.merge(_get_commands_from_script(BuiltinCommands));

	for path in api.command_script_paths:
		commands.merge(_get_commands_from_script(load(path)));

	commands.merge(custom_commands);
	return commands;


func register_command(name: StringName, func_data: Dictionary):
	custom_commands[name] = func_data;


func _get_commands_from_script(script: Script) -> Dictionary[StringName, Dictionary]:
	var commands: Dictionary[StringName, Dictionary] = {};
	const GET_FUNC_DESCRIPTIONS := "get_func_descriptions";

	for cmd in script.get_script_method_list():
		if cmd.name == GET_FUNC_DESCRIPTIONS or cmd.name.begins_with("_"):
			continue;
		commands[cmd.name] = cmd;
		commands[cmd.name].callable = Callable(script, cmd.name);

	if script.has_script_method(GET_FUNC_DESCRIPTIONS):
		var descs: Dictionary = script.callv(GET_FUNC_DESCRIPTIONS, []);
		for key in descs.keys():
			if not commands.has(key):
				continue;
			commands[key].description = descs[key];

	return commands;


# Parsing
# ---------------------------------


func parse_input(text: String):
	if try_parse_path(text): return;
	var args = text.split(" ");

	if get_commands().has(args[0]):
		var context = {
			"plugin" = self,
			"executor" = _execution_root
		};
		get_commands()[args[0]].callable.call(context, args);
		return;

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

	script.call("_run", get_context())
	return true;


func eval_expr(text):
	var exp := Expression.new()
	var err: int = exp.parse(text, get_context().keys())

	if err != OK:
		api.printerr(exp.get_error_text())
		return err

	var result = exp.execute(get_context().values(), _execution_root, false)
	if not exp.has_execute_failed():
		if result != null:
			echo(str(result))
		return OK
	else:
		api.printerr(exp.get_error_text())
		return ERR_SCRIPT_FAILED

# Api
# ---------------------------------


func change_root(node_path):
	var new_root = api.get_node_or_null(node_path);
	if not new_root:
		self.printerr("Node at path %s doesn't exist" % str(node_path));
		return;
	_execution_root = new_root;
	echo("Changed root to: %s" % str(node_path))


func add_context(name: String, object):
	if object is NodePath or object is String:
		var path = object as NodePath
		var node = api.get_node_or_null(path)
		if not node:
			self.printerr("Could not add context \"%s\"; node not found")
			return
		else:
			add_context(name, node);
		return
	_custom_context[name] = object;
	echo("Added \"%s\" to console context" % name)


func remove_context(name: String):
	_custom_context.erase(name);
	echo("Removed \"%s\" from console contex" % name)


func print(text):
	api.print(text);


func printerr(text):
	api.printerr(text);


func echo(text):
	self.print(text);


func echoerr(text):
	self.printerr(text);
