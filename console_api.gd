@tool
extends Node

const GeckPlugin := preload("./plugin.gd")
var plugin: GeckPlugin;


func _init() -> void:
	name = "GeckInterface"


func add_context(name: String, object: Variant):
	plugin.add_context(name, object);


func remove_context(name: String):
	plugin.remove_context(name);


