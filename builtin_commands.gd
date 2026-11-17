const Command := preload("./command.gd").Command;
const Arg := preload("./command.gd").Arg;

static func get_func_descriptions() -> Dictionary[StringName, String]:
	return {};


static func clear(context, _args):
	context.plugin.console_gui.text = "";


static func help(context, args: Array[String]):
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
		context.plugin.echo(command.get_help_text(args));

	elif matches.has("commands"):
		var output = "";
		output += "Command list:"
		for key in context.plugin._commands:
			var cmd = context.plugin._commands[key]
			output += "\n"
			output += key 
			if cmd.has("description"):
				output += " - " + cmd.description

		
		output += "\n";
		output += "for more type help -h"
		context.plugin.echo(output)

	elif matches.has("context"):
		var output = "";
		for key in context.plugin.api.get_context().keys():
			# var val = context.plugin.api.get_context()[key];
			output += key;
			output += "\n";
		context.plugin.echo(output)

	elif matches.has("methods"):
		var output = "";
		output += "Script methods: "
		for method in context.executor.get_script().get_script_methods():
			output += "\n"
			output += method.name;

		context.plugin.echo(output)

	elif matches.has("all-methods"):
		var output = "";
		output += "Script methods: "
		for method in context.executor.get_method_list():
			output += "\n"
			output += method.name;

		context.plugin.echo(output)

	elif matches.has("scripts"):
		var output := "";
		for path in context.plugin.script_paths:
			for file in ResourceLoader.list_directory(path):
				output += path + file
				output += "\n"

		context.plugin.echo(output)

	elif matches.has("root"):
		var output = "";
		output += "Current execution root: \n%s" % str(context.plugin._execution_root)
		context.plugin.echo(output)

	else:
		context.plugin.echoerr("\'%s\' is not a recognized command\n" % " ".join(args))
		context.plugin.echo(command.get_help_text(args));


static func echo(context, args: Array[String]) -> void:
	var parts = args.slice(1)
	var msg = " ".join(parts);
	var msg_as_func = "echo(" + msg + ")";
	context.plugin.eval_expr(msg_as_func);
