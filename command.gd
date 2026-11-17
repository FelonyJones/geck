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
