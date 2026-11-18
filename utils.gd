static func has_flag(bitmask: int, flag: int) -> bool:
	return (bitmask & flag) != 0;


static func has_property():
	pass


static func format_method_signature(dict: Dictionary) -> String:
	var output = "";
	output += "func " + dict.name + "("
	var arg_count = dict.args.size() - 1;
	var default_arg_count = dict.default_args.size() - 1;

	for i in dict.args.size():
		var arg = dict.args[i];

		output += arg.name

		var type_name = type_string(arg.type);
		if arg.class_name:
			type_name = arg.class_name;

		output += ": " + type_name;

		var diff = arg_count - default_arg_count;
		var default_arg_index = i - diff;
		if has_index(dict.default_args, default_arg_index):
			var default_arg = str(dict.default_args[default_arg_index])
			output += " = " + default_arg

		if i < arg_count:
			output += (", ")

	output += ") -> "

	var return_type = type_string(dict.return.type);
	if dict.return.class_name:
		return_type = dict.return.class_name;

	output += return_type;

	return output


static func get_method_dict_from_list(script_method_list: Array[Dictionary], method_name: StringName) -> Dictionary:
	for dict in script_method_list:
		if dict.name == method_name:
			return dict;
	return {};


static func run_script(script: Script, method: StringName, args := []):
	var methods = script.get_script_method_list();
	var contains = false;
	var method_dict: Dictionary; 
	
	for dict in methods:
		if dict.name == method:
			contains = true;
			method_dict = dict;

	if not contains:
		return ERR_METHOD_NOT_FOUND;

	if method_dict.args.size() != args.size():
		return ERR_INVALID_PARAMETER;

	print(format_method_signature(method_dict))

	var is_static = has_flag(method_dict.flags, MethodFlags.METHOD_FLAG_STATIC);

	var script_object;
	var gdscript = script as GDScript;
	var csharp = script as CSharpScript;

	if is_static:
		script_object = script;
	elif gdscript:
		script_object = gdscript.new();
	elif csharp:
		script_object = csharp.new();
	else:
		return FAILED;

	var callable = Callable(script_object, method);
	return callable.callv(args);
	

static func convert_path_to_valid_script_path(script_file_name: String, default_paths: Array[String]) -> String:
	for dir in default_paths:
		var path := script_file_name;
		if script_file_name.is_relative_path():
			path = dir + script_file_name;

		if not ResourceLoader.exists(path):
			continue;

		var script = load(path) as Script;
		if not script:
			continue;
		return path;
	
	return "";


static func take(array: Array, i: int):
	if not has_index(array, i):
		return null
	var val = array[i];
	array.remove_at(i);
	return val


static func has_index(array: Array, i: int) -> bool:
	return array.size() -1 >= i and i >= 0
