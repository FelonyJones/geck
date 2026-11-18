const Utils := preload("./utils.gd");

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


	func matches(text: String, match_shorthand := true) -> bool:
		if match_shorthand:
			return _short_name == text or name == text;
		return name == text;


	func get_match_index(cmd_args: Array[String]) -> int:
		var i_full = cmd_args.find("--" + name);
		var i_short = -1;
		if _get_short_name() != "":
			i_short = cmd_args.find("-" + _get_short_name());

		var i = -1;

		if i_short >= 0: i = i_short;
		if i_full >= 0: i = i_full;

		return i;

	func find_match(matches: Matches, cmd_args: Array[String]) -> ArgMatch:
		if _default_value != null:
			matches.add_value(name, _default_value);
		
		var i_full = cmd_args.find("--" + name);
		var i_short = cmd_args.find("-" + _get_short_name());

		var i = -1;

		if i_short >= 0: i = i_short;
		if i_full >= 0: i = i_full;

		if i < 0:
			return null;

		var val = null;

		if i + 1 <= cmd_args.size() - 1:
			if not cmd_args[i + 1].begins_with("-"): 
				val = cmd_args[i + 1];

		return ArgMatch.new(name, i, val);


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

class Command:
	var _args: Array[Arg] = [];
	var name := "";
	var _arg_required := false;
	var _help := "";
	var _help_writer = null;

	func _init(newname: String) -> void:
		name = newname;


	func arg(newArg: Arg) -> Command:
		_args.append(newArg);
		return self;


	func help(val: String) -> Command:
		_help = val;
		return self;


	func help_writer(writer: Callable) -> Command:
		_help_writer = writer;
		return self;


	func arg_required(val: bool) -> Command:
		_arg_required = val;
		return self;


	func get_matches(cmd_args: Array) -> Matches:
		cmd_args = cmd_args.map(func(val): return str(val));
		var args_str: Array[String] = []
		args_str.assign(cmd_args)
		return Matches.parse_matches(_args, args_str);


	func get_help_text() -> String:
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


	func printhelp():
		_help_writer.call(get_help_text());


class Matches extends RefCounted:
	var _original_args: Array[String];
	var _args: Array[String];
	var matches: Array[Dictionary] = [];
	var values: Dictionary[StringName, Variant];


	static func parse_matches(cmd_args: Array[Arg], passed_args: Array[String]) -> Matches:
		var inst = Matches.new();
		inst._parse_matches(cmd_args, passed_args);
		return inst;


	func _parse_matches(cmd_args: Array[Arg], passed_args: Array[String]) -> void:
		_args = passed_args;
		_original_args = passed_args.duplicate();
		_args = _args.filter(func(val): return val != "" and val != " ")
		print(_args)

		for arg: Arg in cmd_args:
			if arg._default_value != null:
				add_value(arg.name, arg._default_value);

			var i = arg.get_match_index(_args);
			if i < 0:
				continue;

			var val = null
			if i + 1 <= passed_args.size() - 1:
				if not passed_args[i + 1].begins_with("-"): 
					# val = passed_args[i + 1]
					val = Utils.take(_args, i + 1);

			Utils.take(_args, i);

			add_match(arg.name, -1, val)
			if val != null:
				add_value(arg.name, val)


	func clean_matches() -> Array[String]:
		return _args;


	func add_match(name, index, val = null) -> void:
		matches.append({
			"name" : name,
			"index" : index,
			"val" : val,
		})

		if val != null:
			values[name] = val;

			
	func get_match_dict(name: StringName) -> Dictionary:
		for match in matches:
			if match.name == name:
				return match 

		return {};
	

	func add_value(name: StringName, val: Variant):
		values[name] = val;
	

	func has_flag(name: StringName) -> bool:
		for match in matches:
			if match.name == name:
				return true

		return false;
	


	func get_value(name: StringName) -> Variant:
		return values[name];

	func is_empty() -> bool:
		return matches.is_empty();
		

class ArgMatch extends RefCounted:
	var name := "";
	var index := -1;
	var val = null;
	var default_val = null;

	func _init(_name, _index, _val = null) -> void:
		name = _name;
		index = _index;
		val = _val;
		

	func get_or_default():
		if val == null:
			return default_val;
		else: return val;


	func get_or(or_val):
		if val == null:
			return or_val;
		else: return val;


