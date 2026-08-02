extends Node
const BUILTIN_LANGUAGE_PATH := "res://data/lang"
const USER_LANGUAGE_PATH := "user://languages"
var current_language := "en"
var translations: Dictionary = {}
var available_languages: Array[Dictionary] = []
func _ready():
	_create_user_language_directory()
	scan_languages()
func _create_user_language_directory():
	if not DirAccess.dir_exists_absolute(USER_LANGUAGE_PATH):
		DirAccess.make_dir_recursive_absolute(USER_LANGUAGE_PATH)
func scan_languages() -> Array[Dictionary]:
	available_languages.clear()
	_scan_language_directory(BUILTIN_LANGUAGE_PATH, false)
	_scan_language_directory(USER_LANGUAGE_PATH, true)
	return available_languages
func _scan_language_directory(directory_path: String, is_user_language: bool):
	if not DirAccess.dir_exists_absolute(directory_path):
		return
	for file_name in DirAccess.get_files_at(directory_path):
		if file_name.get_extension().to_lower() != "json":
			continue
		var file_path := directory_path.path_join(file_name)
		var data := _read_json(file_path)
		if data.is_empty():
			continue
		if not data.has("language"):
			push_warning("Language metadata missing: " + file_path)
			continue
		var metadata = data["language"]
		if not metadata is Dictionary:
			continue
		var code := str(metadata.get("code", file_name.get_basename()))
		var display_name := str(metadata.get("name", code))
		if _language_exists(code):
			if is_user_language:
				_replace_language(code, display_name, file_path)
			continue
		available_languages.append({
			"code": code,
			"name": display_name,
			"path": file_path
		})
func load_lang(language_code: String) -> bool:
	var language := _get_language(language_code)
	if language.is_empty():
		push_warning("Language not found: " + language_code)
		return false
	var data := _read_json(language["path"])
	if data.is_empty():
		return false
	translations = data
	current_language = language_code
	return true
func translate(key: String) -> String:
	var value: Variant = translations
	for part in key.split("."):
		if not value is Dictionary or not value.has(part):
			return key
		value = value[part]
	return str(value)
func _read_json(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open language file: " + file_path)
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_warning("Invalid JSON in %s at line %d: %s" % [
			file_path,
			json.get_error_line(),
			json.get_error_message()
		])
		return {}
	if not json.data is Dictionary:
		push_warning("Language root must be a Dictionary: " + file_path)
		return {}
	return json.data
func _language_exists(code: String) -> bool:
	for language in available_languages:
		if language["code"] == code:
			return true
	return false
func _get_language(code: String) -> Dictionary:
	for language in available_languages:
		if language["code"] == code:
			return language
	return {}
func _replace_language(code: String, display_name: String, file_path: String):
	for index in range(available_languages.size()):
		if available_languages[index]["code"] == code:
			available_languages[index] = {
				"code": code,
				"name": display_name,
				"path": file_path
			}
			return
