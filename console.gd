@tool
extends EditorDock

@onready var input: LineEdit = %Input
@onready var output: RichTextLabel = %Output

var context : Dictionary[String, Variant]= {
}

var _input_history = [];
var hist_reverse_index = -1:
	set(value):
		hist_reverse_index = clampi(value, -1, _input_history.size() - 1)

		
var input_buffer := "";

func _ready() -> void:
	input.text_submitted.connect(_on_command_submitted);
	input.gui_input.connect(_on_input_gui_input);


func _scroll_history(up := true):
	var down = !up;
	if up:
		if _input_history.size() < 1:
			return;
		
		if hist_reverse_index < 0:
			input_buffer = input.text;

		hist_reverse_index += 1;

		var hist_cmd = get_reversed(_input_history, hist_reverse_index);
		input.text = hist_cmd;
		return;

	if down:
		hist_reverse_index -= 1;

		if hist_reverse_index < 0:
			input.text = input_buffer;
			return;

		if hist_reverse_index > _input_history.size() - 1:
			input.text = input_buffer;
			return;

		var hist_cmd = get_reversed(_input_history, hist_reverse_index);
		input.text = hist_cmd;


func _on_input_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return;
	
	if Input.is_action_just_pressed("ui_up"):
		_scroll_history(true);

	if Input.is_action_just_pressed("ui_down"):
		_scroll_history(false);


func get_reversed(array: Array, reverse_index: int):
	var forward_index: int = array.size() - 1 - reverse_index;
	return array[forward_index];


func _on_command_submitted(text: String):
	var cmd = text;
	input_buffer = "";
	hist_reverse_index = -1;

	if _input_history.back() != cmd:
		_input_history.append(cmd);

	output.text += "\n> " + text + "\n"
	input.text = "";
	parse_input(text);


func parse_input(text: String):
	var args = text.split(" ");
	if args[0] == "echo":
		cmd_echo(args);
	else:
		eval_expr(text)


func cmd_echo(args: Array[String]):
	var parts = args.slice(1)
	var msg = " ".join(parts);
	var msg_as_func = "echo(%s)" % msg;
	eval_expr(msg_as_func);


func eval_expr(text):
	var exp := Expression.new()
	var err: int = exp.parse(text, context.keys())

	if err != OK:
		printerrconsole(exp.get_error_text())
		return err
	var result = exp.execute(context.values(), self)
	if not exp.has_execute_failed():
		if result != null:
			echo(str(result))
		return OK
	else:
		printerrconsole(exp.get_error_text())
		return ERR_SCRIPT_FAILED


func echo(text):
	output.text += str(text) + "\n";


func printerrconsole(text):
	output.text += "[color=red]"+ str(text) + "[/color]\n";
	pass
