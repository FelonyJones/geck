@tool
extends RefCounted

#TODO: Save history to disk
#TODO: Save custom context
#FIXME: error: Can't take value from empty array

const PLUGIN_NAME := "geck";
const SINGLETON_NAME = "GeckInterface";
const DEFAULT_SCRIPT_PATH = "res://addons/geck/scripts/"
const SETTINGS_PATH = "Addons/GEC(K)/"
const BUILTIN_COMMANDS_PATH = "./builtin_commands.gd"

const Command := preload("./command.gd").Command;
const Arg := preload("./command.gd").Arg;

const GeckGui       := preload("./console_gui.gd");
const GeckInterface := preload("./console_api.gd");
const Utils := preload("./utils.gd");
const BuiltinCommands := preload("./builtin_commands.gd");

var api : GeckInterface;
	
var _engine_singletons : Dictionary[String, Variant] = {}
var _class_context     : Dictionary[String, Variant] = {}
var _custom_context    : Dictionary[String, Variant] = {}
var _autoload_context  : Dictionary[String, Variant] = {}

var script_aliases : Dictionary[String, Dictionary] = {}

var _execution_root = api;

var custom_commands : Dictionary[StringName, CommandData] = {};


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


func get_commands() -> Dictionary[StringName, CommandData]: 
	var commands: Dictionary[StringName, CommandData] = {};

	var get_builtin_command_script_object := Callable(func(): return BuiltinCommands);
	commands.merge(_get_commands_from_script(BuiltinCommands, get_builtin_command_script_object));

	for path in api.command_script_paths:
		commands.merge(_get_commands_from_script_path(path));

	commands.merge(custom_commands);
	return commands;


func register_command(name: StringName, data: CommandData):
	custom_commands[name] = data;


func _get_commands_from_script_path(script_path: String) -> Dictionary[StringName, CommandData]:
	var script = load(script_path) as Script;
	if not script:
		return {};

	var get_script := Callable(func(): return load(script_path));
	return _get_commands_from_script(script, get_script);


func _get_commands_from_script(script: Script, func_get_script: Callable) -> Dictionary[StringName, CommandData]:
	var commands: Dictionary[StringName, CommandData] = {};
	const GET_FUNC_DESCRIPTIONS := "get_func_descriptions";

	for cmd in script.get_script_method_list():
		if cmd.name == GET_FUNC_DESCRIPTIONS or cmd.name.begins_with("_"):
			continue;
		commands[cmd.name] = CommandData.from_dict(cmd, func_get_script);

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
	var args = text.split(" ");
	if try_run_as_script(args): return;

	if get_commands().has(args[0]):
		var command_name = args[0];
		return get_commands()[command_name].run(api, args);

	eval_expr(text)


func try_run_as_script(args: Array[String]) -> bool:
	var text := args[0];
	var path := text;
	var trimmed_args = args.slice(1);
	var script_path = Utils.convert_path_to_valid_script_path(path, api.script_paths);

	if not script_path:
		return false;
	
	var result = get_commands()["run"].run(api, [script_path] + trimmed_args);

	return result is not Error;


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



class CommandData:
	var name : StringName;
	var args : Array[Dictionary];
	var default_args : Array[Variant];
	var flags  : MethodFlags;
	var id     : int;
	var return_val : Dictionary;

	var description : String;

	var get_script : Callable;

	func _init(
		_name : StringName,
		_args : Array[Dictionary],
		_default_args : Array[Variant],
		_flags  : MethodFlags,
		_id     : int,
		_return_val : Dictionary,
		_get_script : Callable,
		
	) -> void:
		name = _name
		args = _args
		default_args = _default_args 
		flags = _flags  
		id = _id     
		return_val = return_val 
		get_script = _get_script


	func run(api, args):
		var full_args = [args];
		if self.args.size() > 0 and self.args[0].name == "api":
			full_args = [api, args];

		return Utils.run_script(get_script.call(), name, full_args)


	static func from_dict(dict: Dictionary, func_get_script : Callable) -> CommandData:
		return CommandData.new(
			dict.name,
			dict.args,
			dict.default_args,
			dict.flags,
			dict.id,
			dict.return,
			func_get_script,
		);
