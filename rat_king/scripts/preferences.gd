class_name Preferences
extends Resource

## # Usage example:
## var pref := Preferences.load_or_create("game_settings")
## mouse_sensitivity = pref.get_data("mouse_sensitivity", 1.0)
## # later, after changing the setting:
## pref.set_data("mouse_sensitivity", mouse_sensitivity)

static var _all: Dictionary

@export var data: Dictionary

var _definitions: Dictionary
var _cur_saving := false

signal preference_changed(name: String, value)

###

static func load_or_create(save_name := "user_prefs", definitions_folder := "", binary := false) -> Preferences:
	if not save_name:
		printerr("Empty name for preferences not allowed!")
		return null
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
	if definitions_folder:
		var dir := DirAccess.open(definitions_folder)
		if dir == null:
			printerr("Could not get preference definitions")
		else:
			for file: String in dir.get_files():
				var def := load(dir.get_current_dir() + "/" + file) as PreferenceDefinition
				pref._definitions[def.uid.to_lower()] = def
	return pref

###

func try_get_definition(uid: String) -> PreferenceDefinition:
	if _definitions.has(uid.to_lower()): return _definitions[uid.to_lower()]
	return null

func get_data_via_def(name: String):
	if name == "": printerr("Empty data name not allowed!"); return null
	if name.to_lower() not in _definitions: printerr("No Definition for ", name); return null
	var def: PreferenceDefinition = _definitions[name.to_lower()]
	return get_data(name, def.get_default_value())

###

func has_data(name: String) -> bool:
	if not name: printerr("Empty data name not allowed!"); return false
	return name in data

func get_data(name: String, default_value = null, save_default_if_not_existing := false):
	if not name: printerr("Empty data name not allowed!"); return null
	if name in data:
		var d = data[name]
		if default_value is int and d is float: return d
		elif default_value is float and d is int: return d
		elif default_value is StringName and d is String: return d
		elif default_value is String and d is StringName: return d
		elif typeof(default_value) == typeof(d): return d
	elif save_default_if_not_existing:
		set_data(name, default_value)
		return default_value
	if name in _definitions:
		var d = _definitions[name].get_default_value()
		if default_value is float and d is int: return d
		elif default_value is int and d is float: return d
		elif default_value is StringName and d is String: return d
		elif default_value is String and d is StringName: return d
		elif typeof(default_value) == typeof(d): return d
	return default_value

func set_data(name: String, value) -> void:
	if not name: printerr("Empty data name not allowed!"); return
	if name not in data or typeof(value) != typeof(data[name]) or data[name] != value:
		data[name] = value
		preference_changed.emit(name, value)
		save()

func remove_data(name: String) -> void:
	if not name: printerr("Empty data name not allowed!"); return
	if name in data:
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
	for d: String in data:
		callable.call(d, data[d])
	preference_changed.connect(callable)
