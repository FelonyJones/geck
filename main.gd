@tool
extends EditorPlugin

const PLUGIN_NAME := "editor-console";
const SINGLETON_NAME = "EditorConsoleApi";
var console_gui := preload("./console_gui.tscn").instantiate()
var api := preload("./console_api.gd").new()

var _context : Dictionary[String, Variant] = {}
var engine_singletons : Dictionary[String, Variant] = {}
var class_context : Dictionary[String, Variant] = {}
var custom_context : Dictionary[String, Variant] = {}
var misc_context : Dictionary[String, Variant] = {
	"execution_root" : self,
}

var _execution_root = self;


func _enable_plugin() -> void:
	pass;


func _disable_plugin() -> void:
	pass;


func _enter_tree() -> void:
	console_gui.plugin = self;
	add_autoload_singleton(SINGLETON_NAME, "./console_api.gd");
	get_tree().root.get_node("/root/" + SINGLETON_NAME).set("plugin", self);
	add_dock(console_gui)
	add_static_context()
	add_builtin_singletons()
	add_registered_singleton_names()
	_rebuild_context();


func _exit_tree() -> void:
	remove_dock(console_gui)
	console_gui.queue_free()
	pass


func add_registered_singleton_names() -> void:
	for property in ProjectSettings.get_property_list():
		if property.name.begins_with("autoload/"):
			var singleton_name = property.name.get_slice("/", 1)
			class_context[singleton_name] = get_node("/root/%s" % singleton_name)


func _rebuild_context():
	_context = {};
	_context.merge(engine_singletons);
	_context.merge(class_context);
	_context.merge(custom_context);
	_context.merge(misc_context);


func add_builtin_singletons():
	for name in Engine.get_singleton_list():
		engine_singletons[name] = Engine.get_singleton(name);


func add_static_context():
	for dict in ProjectSettings.get_global_class_list():
		class_context[dict.class] = load(dict.path);
		pass
	pass


func parse_input(text: String):
	var args = text.split(" ");
	match args[0]:
		"echo":
			cmd_echo(args);
		"clear":
			console_gui.output.text = ""

		"reset-root":
			change_root(self.get_path())

		"help":
			cmd_help()
		_:
			eval_expr(text)


func change_root(node_path):
	var new_root = get_node_or_null(node_path);
	if not new_root:
		console_gui.printerrconsole("Node at path %s doesn't exist" % str(node_path));
		return;
	_execution_root = new_root;
	echo("Changed root to: %s" % str(node_path))


func cmd_help():
	var output = "";
	output += "Current execution root: \n%s" % str(_execution_root)
	output += "\n"
	output += "\n"
	output += "Root method list:"
	for val in _execution_root.get_method_list():
		output += "\n\t%s" % val.name
		pass
	echo(output)


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
	_rebuild_context();


func remove_context(name: String):
	custom_context.erase(name);
	_rebuild_context();


func cmd_echo(args: Array[String]):
	var parts = args.slice(1)
	var msg = " ".join(parts);
	var msg_as_func = "echo(" + msg + ")";
	eval_expr(msg_as_func);


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


func echo(text):
	console_gui.printconsole(text);


func get_parent_recursive():
	var parent = get_parent();
	while parent.get_parent() != null:
		parent = parent.get_parent()
	return parent;


