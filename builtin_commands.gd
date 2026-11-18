extends EditorScript

const Command := preload("./command.gd").Command;
const Arg := preload("./command.gd").Arg;
const GeckInterface := preload("./console_api.gd");
const Utils := preload("./utils.gd");

static func get_func_descriptions() -> Dictionary[StringName, String]:
	return {};


static func clear(api: GeckInterface, _args):
	api.console_gui.text = "";


func help(api: GeckInterface, args: Array[String]):
	var command = Command.new("help")\
	.help("List commands and other stuff")\
	.arg(
		Arg.new("methods")
			.short_name("m")
			.help("List the script's declared methods")
	).arg(
		Arg.new("all-methods")
			.short_name("M")
			.help("List all methods available to the script")
	).arg(
		Arg.new("commands")
			.help("List all available commands")
	).arg(
		Arg.new("context")
			.short_name("C")
			.help("List current execution context")
	).arg(
		Arg.new("scripts")
			.help("List quick scripts")
	).arg(
		Arg.new("root")
			.help("Show execution root")
	)

	var matches = command.get_matches(args);

	if matches.is_empty() and args.size() <= 1:
		api.print(command.get_help_text());

	elif matches.has_flag("commands"):
		var output = "";
		output += "Command list:"
		for key in api.console.get_commands():
			var cmd = api.console.get_commands()[key]
			output += "\n"
			output += key 
			if cmd.description:
				output += " - " + cmd.description

		
		output += "\n";
		output += "for more type help -h"
		api.print(output)

	elif matches.has_flag("context"):
		var output = "";
		for key in api.plugin.api.get_context().keys():
			output += key;
			output += "\n";
		api.print(output)

	elif matches.has_flag("methods"):
		var output = "";
		output += "Api methods: "
		for method in api.execution_root.get_script().get_script_method_list():
			output += "\n"
			output += method.name;

		api.print(output)

	elif matches.has_flag("all-methods"):
		var output = "";
		output += "Script methods: "
		for method in api.execution_root.get_method_list():
			output += "\n"
			output += method.name;

		api.print(output)

	elif matches.has_flag("scripts"):
		var output := "";
		for path in api.script_paths:
			for file in ResourceLoader.list_directory(path):
				output += path + file
				output += "\n"

		api.print(output)

	elif matches.has_flag("root"):
		var output = "";
		output += "Current execution root: \n%s" % str(api.plugin._execution_root)
		api.print(output)

	else:
		api.printerr("\'%s\' is not a recognized command\n" % " ".join(args))
		api.print(command.get_help_text());


static func echo(api: GeckInterface, args: Array[String]) -> void:
	var parts = args.slice(1)
	var msg = " ".join(parts);
	var msg_as_func = "print(" + msg + ")";
	api.plugin.eval_expr(msg_as_func);

# class ArrayWrapper extends RefCounted:
# 	var _content: Array;
#
# 	func peek(i: int):
# 		return _content[i];
#
# 	func take(i: int):
# 		var val = _content[i]
#
# 		return val


## Run a script
static func run(api: GeckInterface, args: Array):
	var command = Command.new("run")\
		.help("Run a script")\
		.help_writer(func(text): api.print(text))\
		.arg(
			Arg.new("method")
				.default_value("_run")
				.short_name("m")
				.help("Specify which method to run")
			)

	var script_file_name = Utils.take(args, 0);

	# compensate for if run was used as a command to trigger this method
	if script_file_name == "run":
		script_file_name = Utils.take(args, 0);

	var path = Utils.convert_path_to_valid_script_path(script_file_name, api.script_paths);

	if not ResourceLoader.exists(path):
		command.printhelp();
		api.printerr("Path doesn't exist %s" % path);
		return false;

	var script = load(path) as Script;
	if not script:
		command.printhelp();
		api.printerr("File is not a script: %s" % path);
		return true;

	var matches = command.get_matches(args);
	var method = matches.get_value("method");

	args = matches.clean_matches();
	var result = Utils.run_script(script, method, args);

	if result is not Error:
		api.print("Executed script: %s" % path.get_file())
		return result;
	
	match result:
		Error.ERR_METHOD_NOT_FOUND:
			var output = "Method \"%s\" not found in script: " % method + path;
			push_error(output)
			api.printerr(output);

		Error.ERR_INVALID_PARAMETER:
			var method_dict = Utils.get_method_dict_from_list(script.get_script_method_list(), method);
			var func_signature = Utils.format_method_signature(method_dict)
			var output = "";

			output += "Arguments don't match method signature"
			output += "\n\t"

			output += "method signature:";
			output += "\n\t\t"
			output += func_signature;
			output += "\n\t"


			output += "passed arguments:";
			output += "\n\t\t"
			output += str(args)
			push_error(output);
			api.printerr(output);
		_:
			api.printerr(error_string(result));

	command.printhelp();
	return false;


# static func run2(api: GeckInterface, script_file_name: String, args: Array):
# 	var command = Command.new("run")\
# 		.help("Run a script")\
# 		.arg(
# 			Arg.new("method")
# 				.default_value("_run")
# 				.short_name("m")
# 				.help("Specify which method to run")
# 			)
#
# 	var path = Utils.convert_path_to_valid_script_path(script_file_name, "no impl");
#
# 	if not ResourceLoader.exists(path):
# 		return false;
#
# 	var script = load(path) as Script;
# 	if not script:
# 		api.printerr("File is not a script: %s" % path);
# 		return true;
#
# 	var matches = command.get_matches(args);
# 	var method = "_run";
#
# 	if matches.has("method"):
# 		var match = matches.method;
# 		method = match.get_or_default();
#
# 	var clean_args = command.clean_matches(args);
#
# 	var result = Utils.run_script(script, method, clean_args as Array);
#
# 	if result is not Error:
# 		api.print("Executed script: %s" % path.get_file())
# 		return result;
#
# 	match result:
# 		Error.ERR_METHOD_NOT_FOUND:
# 			api.printerr("Method \"%s\" not found in script: " % method + path);
# 		Error.ERR_INVALID_PARAMETER:
# 			api.printerr("Arguments don't match method signature \n\targs: " + str(args.slice(1)));
# 		_:
# 			api.printerr(error_string(result));
# 			api.printerr(command.get_help_text())
# 	api.print("\n");
# 	return false;
