extends Node

var current_lang := "en"
var data := {}

func load_lang(lang: String):
	current_lang = lang
	var path = "res://data/lang/%s.json" % lang
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Language file not found:", path)
		return
	var json_text = file.get_as_text()
	var result = JSON.parse_string(json_text)
	if typeof(result) != TYPE_DICTIONARY:
		print("JSON parse error")
		return

	data = result

func translate(key: String) -> String:
	if data.has(key):
		return data[key]
	return key
