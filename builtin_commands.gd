static func get_func_descriptions() -> Dictionary[StringName, String]:
	return {};


static func clear(context, _args):
	context.plugin.console_gui.text = "";


class Command:
	var _args = [];
	var name := "";
	var _arg_required := false;
	var _help := "";

	func _init(newname: String) -> void:
		name = newname;

	func arg(newArg: Arg) -> Command:
		_args.append(newArg);
		return self;

	func help(val: String) -> Command:
		_help = val;
		return self;

	func arg_required(val: bool) -> Command:
		_arg_required = val;
		return self;
	
	func get_matches(cmd_args: Array[String]) -> Dictionary[String, Variant]:
		var matches : Dictionary[String, Variant] = {};
		for arg: Arg in _args:
			var i_full = cmd_args.find("--" + name);
			var i_short = cmd_args.find("-" + arg._get_short_name());

			var i = -1;

			if i_short >= 0: i = i_short;
			if i_full >= 0: i = i_full;

			if i < 0:
				continue;

			var val = null;
			if not cmd_args.size() >= i + 1:
				if not cmd_args[i + 1].begins_with("-"): val = cmd_args[i + 1];

			matches[arg.name] = val;

		if matches.is_empty() and _arg_required:
			# print help
			pass
			
		return matches

	func get_help_text(cmd_args: Array[String]) -> String:
		var output := "";
		output += "usage: " + name + "<flags>";

		for arg: Arg in _args:
			output += "\n"
			output += "\t"
			var short_name = arg._get_short_name()
			if (short_name):
				output += "-" + short_name + ",  "
			else:
				output += "    "
				pass

			output += "--" + arg.name + " ";

			if arg._help_text:
				output += "\n"
				output += "\t\t"
				output += arg._help_text;

		return output;

class Arg:
	var name := "";
	var _short_name := "";
	var _default_value;
	var _auto_short_name := true;
	var _required := false;
	var _help_text := "";


	func _init(newname: String) -> void:
		name = newname;
		pass

	func _get_short_name():
		if not _short_name:
			return name.left(1);
		else: return _short_name;


	func required(val: bool) -> Arg:
		_required = val;
		return self;

	func auto_short_name(val: bool) -> Arg:
		_auto_short_name = val;
		return self;


	func short_name(val: String) -> Arg:
		_short_name = val;
		return self;


	func default_value(val) -> Arg:
		_default_value = val;
		return self;
	

	func help(text: String) -> Arg:
		_help_text = text;
		return self;


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


func _print_help(cmd):
	var output = ""
	output += cmd.usage;
	output += "\n"
	for flag in cmd.flags:
		pass

	pass


static func echo(context, args: Array[String]) -> void:
	var parts = args.slice(1)
	var msg = " ".join(parts);
	var msg_as_func = "echo(" + msg + ")";
	context.plugin.eval_expr(msg_as_func);


static func get_parent_recursive(this: Node):
	var parent = this.get_parent();
	while parent.get_parent() != null:
		parent = parent.get_parent()
	return parent;

