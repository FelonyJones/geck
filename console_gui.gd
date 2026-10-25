@tool
extends EditorDock

const GeckPlugin := preload("./plugin.gd")
var plugin: GeckPlugin;

@onready var input: LineEdit = %Input
@onready var output: RichTextLabel = %Output

var _input_history = [];
var hist_reverse_index = -1:
	set(value):
		hist_reverse_index = clampi(value, -1, _input_history.size() - 1)

var input_buffer := "";

func _init() -> void:
	name = "GeckGui"

func _ready() -> void:
	input.text_submitted.connect(_on_command_submitted);
	input.gui_input.connect(_on_input_gui_input);

func printconsole(text):
	output.text += str(text) + "\n";

func printerrconsole(text):
	output.text += "[color=red]"+ str(text) + "[/color]\n";
	pass

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
	plugin.parse_input(text);


func _on_input_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return;
	
	if Input.is_action_just_pressed("ui_up"):
		_scroll_history(true);

	if Input.is_action_just_pressed("ui_down"):
		_scroll_history(false);


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

