const template := """
@tool
func _run(context):
	"""


func evaluate(code: String, context):
	var script := GDScript.new();
	code = template + code;
	script.set(&"source_code", code);
	script.new()._run(code);



