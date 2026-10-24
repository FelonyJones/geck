@tool
extends Node

var plugin;

var context_queue = {};

func _enter_tree() -> void:
	print("added api to tree")
	pass


func _exit_tree() -> void:
	print("removed api from tree")
	pass


func add_context(name: String, object: Variant):
	plugin.add_context(name, object);


func remove_context(name: String):
	plugin.remove_context(name);


