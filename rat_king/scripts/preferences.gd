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

###

static func load_or_create(save_name := "user_prefs", binary := false) -> Preferences:
	if not save_name: printerr("Empty name for preferences not allowed!"); return null
	if _all.has(save_name): return _all[save_name]
	var file_name := "user://" + save_name + (".res" if binary else ".tres")
	var pref: Preferences = null
	if ResourceLoader.exists(file_name):
		pref = load(file_name)
		if pref != null: print("Load preferences resource ", pref.resource_path)
	if pref == null:
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
	if data.has(name): return data[name]
	return default_value

func set_data(name: String, value) -> void:
	if name == "": printerr("Empty data name not allowed!"); return
	if not data.has(name) or data[name] != value:
		data[name] = value
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
