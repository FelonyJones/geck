@tool
extends Node

const GeckConsole := GeckPlugin.GeckConsole;

const SETTINGS_PATH := GeckPlugin.SETTINGS_PATH;

var plugin: GeckPlugin;

var console: GeckConsole:
	get:
		return plugin.console;

var script_paths : Array[String]:
	get:
		return [ProjectSettings.get_setting(SETTINGS_PATH + "scripts_folder")];

var command_script_paths : Array[String]:
	get:
		return [];

var execution_root:
	get:
		return console._execution_root;


func _init() -> void:
	name = "GeckInterface"

func get_context() -> Dictionary[String, Variant]:
	return console.get_context();


func execute(text: String):
	console.parse_input(text);


func refresh_context():
	console.refresh_context();


func add_context(name: String, object: Variant):
	console.add_context(name, object);


func remove_context(name: String):
	console.remove_context(name);


func println(val):
	plugin.console_gui.print(val + "\n");


func print(val):
	plugin.console_gui.print(val);


func printerr(val):
	plugin.console_gui.printerr(val + "\n");

