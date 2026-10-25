@tool

const ECHO := &"echo";
const CLEAR := &"clear";
const RESETROOT := &"resetroot";
const HELP := &"help";

var commands : Dictionary[StringName, Callable] = {
	ECHO : cmd_help,
	CLEAR : cmd_help,
	RESETROOT : cmd_help,
	HELP : cmd_help,
}

var plugin;

func cmd_help():
	var output = "";
	output += "Current execution root: \n%s" % str(plugin._execution_root)
	output += "\n"
	output += "\n"
	output += "Root method list:"
	for val in plugin._execution_root.get_method_list():
		output += "\n\t%s" % val.name
		pass
	echo(output)


func echo(text) -> void: plugin.echo(text)

func cmd_echo(args: Array[String]) -> void:
	var parts = args.slice(1)
	var msg = " ".join(parts);
	var msg_as_func = "echo(" + msg + ")";
	plugin.eval_expr(msg_as_func);
