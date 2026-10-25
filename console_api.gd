@tool
extends Node

const GecPlugin := preload("./plugin.gd")
var plugin: GecPlugin;


func _init() -> void:
	name = "GecInterface"


func add_context(name: String, object: Variant):
	plugin.add_context(name, object);


func remove_context(name: String):
	plugin.remove_context(name);


