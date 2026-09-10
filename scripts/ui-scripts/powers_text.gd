extends RefCounted
## JSON locale dictionaries are registered with Godot on first use. Native locale
## matching, English fallback and live locale-change notifications remain intact.
static var _catalog_path := "res://localization/powers.json"
static var _loaded := false

static func text(key: String, fields: Dictionary = {}) -> String:
	_load_catalog()
	return String(TranslationServer.translate(key)).format(fields)

static func power_name(id: String) -> String:
	return text("power." + id + ".name")

static func _load_catalog() -> void:
	if _loaded: return
	# Set before registration: translations can notify UI nodes during this call.
	_loaded = true
	var file := FileAccess.open(_catalog_path, FileAccess.READ)
	if file == null:
		push_error("Could not read Powers text: " + _catalog_path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("Invalid Powers text JSON: " + _catalog_path)
		return
	for locale in json.data:
		var messages: Variant = json.data[locale]
		if not messages is Dictionary:
			push_error("Powers locale must contain a dictionary: " + str(locale))
			continue
		var translation := Translation.new()
		translation.locale = locale
		for key in messages:
			var message: Variant = messages[key]
			if message is String and not message.is_empty():
				translation.add_message(key, message)
		TranslationServer.add_translation(translation)
