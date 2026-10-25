@tool
class_name EditorConsoleExecutor
extends Node

var plugin: EditorConsolePlugin;

const ECHO := &"echo";
const CLEAR := &"clear";
const RESETROOT := &"resetroot";
const HELP := &"help";

var commands : Dictionary[StringName, Callable] = {
	ECHO : cmd_echo,
	CLEAR : cmd_clear,
	RESETROOT : cmd_help,
	HELP : cmd_help,
}

func _init() -> void:
	name = "EditorConsoleExecutor"

func rebuild_context() -> void: plugin.rebuild_context()
func echo(text) -> void: plugin.echo(text)
func add_context(name: String, object) -> void: plugin.add_context(name, object);
func remove_context(name: String) -> void: plugin.remove_context(name);
func change_root(node_path) -> void: plugin.change_root(node_path);

func get_context() -> Dictionary[String, Variant]: return plugin._context;

func cmd_clear(_args):
	plugin.console_gui.text = "";


func cmd_reset_root(_args):
	plugin._execution_root = self;


func cmd_help(args: Array[String]):
	var output = "";
	output += "Current execution root: \n%s" % str(plugin._execution_root)
	output += "\n"
	output += "\n"
	output += "Root method list:"
	for val in plugin._execution_root.get_method_list():
		output += "\n\t%s" % val.name
		pass
	echo(output)


func cmd_echo(args: Array[String]) -> void:
	var parts = args.slice(1)
	var msg = " ".join(parts);
	var msg_as_func = "echo(" + msg + ")";
	plugin.eval_expr(msg_as_func);


func get_parent_recursive():
	var parent = get_parent();
	while parent.get_parent() != null:
		parent = parent.get_parent()
	return parent;


