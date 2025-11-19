class_name Preferences
extends Resource

## # Usage example:
## var pref := Preferences.load_or_create("game_settings")
## mouse_sensitivity = pref.get_data("mouse_sensitivity", 1.0)
## # later, after changing the setting:
## pref.set_data("mouse_sensitivity", mouse_sensitivity)

static var _all: Dictionary

@export var data: Dictionary

var _cur_saving := false

signal preference_changed(name: String, value)

###

static func load_or_create(save_name := "user_prefs", binary := false) -> Preferences:
	if not save_name: printerr("Empty name for preferences not allowed!"); return null
	if _all.has(save_name): return _all[save_name]
	var file_name := "user://" + save_name + (".res" if binary else ".tres")
	var pref: Preferences = null
	if ResourceLoader.exists(file_name):
		pref = load(file_name)
		if pref:
			print("Load preferences resource ", pref.resource_path)
			for d: String in pref.data:
				pref.preference_changed.emit(d, pref.data[d])
	if not pref:
		pref = Preferences.new()
		pref.resource_path = file_name
		print("Created preferences resource ", pref.resource_path)
	_all[save_name] = pref
	return pref

###

func has_data(name: String) -> bool:
	if name == "": printerr("Empty data name not allowed!"); return false
	return data.has(name)

func get_data(name: String, default_value):
	if name == "": printerr("Empty data name not allowed!"); return null
	if data.has(name):
		if default_value is int and data[name] is float: return data[name]
		elif default_value is float and data[name] is int: return data[name]
		elif default_value is String and data[name] is StringName: return data[name]
		elif default_value is StringName and data[name] is String: return data[name]
		elif typeof(default_value) == typeof(data[name]): return data[name]
	return default_value

func set_data(name: String, value) -> void:
	if name == "": printerr("Empty data name not allowed!"); return
	if not data.has(name) or typeof(value) != typeof(data[name]) or data[name] != value:
		data[name] = value
		preference_changed.emit(name, value)
		save()

func remove_data(name: String) -> void:
	if name == "": printerr("Empty data name not allowed!"); return
	if data.has(name):
		data.erase(name)
		save()
	
func save() -> void:
	if _cur_saving: return
	_cur_saving = true
	_deferred_save.call_deferred()

###

func _deferred_save() -> void:
	_cur_saving = false
	var res := ResourceSaver.save(self, resource_path)
	if res != OK: print("Could not save preferences resource ", resource_path)

###

func set_on_change_preference(callable: Callable) -> void:
	if data: for d: String in data: callable.call(d, data[d])
	preference_changed.connect(callable)
