class_name Helpers

static var _tree: SceneTree = Engine.get_main_loop()

###

static func quit(obj: Object):
	Engine.get_main_loop().quit()
	obj.free()

static func set_tree(tree: SceneTree) -> void:
	_tree = tree

### uid

static func uid_to_file(uid: String) -> String:
	if not uid.begins_with("uid:"): return uid
	return ResourceUID.get_id_path(ResourceUID.text_to_id(uid))

### csv

static func test_csv_file(file: String) -> void:
	var f := FileAccess.open(file, FileAccess.READ)
	var l := 1
	while not f.eof_reached(): # iterate through all lines until the end of file is reached
		var line = f.get_line()
		if line.count("\"") % 2 != 0:
			printerr("WRONG QUOTE COUNT IN ", file, ": [LINE ", l, "] ", line.count("\""))
		l += 1
	f.close()

static func count_csv_file_words(file: String, print_word_count := false, idx := 0) -> int:
	var rq := RegEx.create_from_string(r"\"(.*?(?<!\\))\"")
	var rw := RegEx.create_from_string("[A-Za-z]+")
	var wc := 0
	var f := FileAccess.open(file, FileAccess.READ)
	while not f.eof_reached(): # iterate through all lines until the end of file is reached
		var contents := rq.search_all(f.get_line())
		if contents and contents.size() >= idx:
			wc += rw.search_all(contents[idx].get_string()).size()
	if print_word_count:
		print("Word count of ", file, " [", idx, "]: ", wc)
	f.close()
	return wc

### screenshots

static func take_screenshot(path := "./screenshot", as_jpg := true) -> void:
	var dir := path
	if not dir.ends_with("/") and not dir.ends_with("\\"):
		var idx_s := dir.rfind("/")
		var idx_b := dir.rfind("\\")
		dir = dir.substr(0, idx_s if idx_s > idx_b else idx_b)
	var dir_access := DirAccess.open("user://") if path.begins_with("user://") else DirAccess.open("res://")
	if not dir_access.dir_exists(dir): dir_access.make_dir_recursive(dir)
	var image := _tree.root.get_viewport().get_texture().get_image()
	var timestamp := Time.get_datetime_string_from_system(false, true).replace(" ", "_").replace(":", "").replace("-", "")
	path = path + "_" + timestamp + (".jpg" if as_jpg else ".png")
	var res := image.save_jpg(path) if as_jpg else image.save_png(path)
	if res == OK:
		GameUi.log(Main.tr("UI_LOG_CREATE_SCREENSHOT").format({ "path": path }))

### find nodes and classes

static func get_all_children(node: Node, include_self := false, include_internal := false) -> Array[Node]:
	var to_check: Array[Node] = [ node ]
	var result: Array[Node] = []
	if include_self:
		result.append(node)
	var i := 0
	while i < to_check.size():
		var c := to_check[i].get_children(include_internal)
		result.append_array(c)
		to_check.append_array(c)
		i += 1
	return result

#

static func find_in_children(node: Node, type: Variant, include_self := true, include_internal := false) -> Node:
	if node == null: return null
	if include_self and is_instance_of(node, type): return node
	for child: Node in node.get_children(include_internal):
		if is_instance_of(child, type): return child
	return null

static func find_all_in_children(node: Node, type: Variant, include_self := true, include_internal := false) -> Array[Node]:
	if node == null: return []
	var result: Array[Node] = []
	if include_self and is_instance_of(node, type): result.push_back(node)
	for child: Node in node.get_children(include_internal):
		if is_instance_of(child, type): result.push_back(child)
	return result

static func find_in_all_children(node: Node, type: Variant, include_self := true, include_internal := false) -> Node:
	if node == null: return null
	if include_self and is_instance_of(node, type): return node
	for child: Node in Helpers.get_all_children(node, false, include_internal):
		if is_instance_of(child, type): return child
	return null

static func find_all_in_all_children(node: Node, type: Variant, include_self := true, include_internal := false) -> Array[Node]:
	if node == null: return []
	var result: Array[Node] = []
	for child: Node in Helpers.get_all_children(node, include_self, include_internal):
		if is_instance_of(child, type): result.push_back(child)
	return result

static func find_in_all_parents(node: Node, type: Variant, include_self := true) -> Node:
	if node == null: return null
	if include_self and is_instance_of(node, type): return node
	node = node.get_parent()
	while node != null:
		if is_instance_of(node, type): return node
		node = node.get_parent()
	return null
	
### gui

static func is_text_edit_focused(node: Node) -> bool:
	if node == null: return false
	var focused := node.get_viewport().gui_get_focus_owner()
	if focused == null: return false
	if focused is LineEdit or focused is TextEdit: return true
	return false

static func scroll_container_to_end(container: Control, forced := false) -> void:
	if container == null: return
	if container.is_inside_tree():
		await container.get_tree().process_frame
	var count := container.get_child_count()
	if not forced and container.get_meta("scroll_last_count", 0) == count:
		return
	var _scroller: ScrollContainer = Helpers.find_in_all_parents(container, ScrollContainer)
	if _scroller: _scroller.scroll_vertical = int(container.size.y)
	else: printerr("missing ScrollContainer!")
	container.set_meta("scroll_last_count", count)
	
### waiting and timing

## coroutine
static func tree_do_next_physics_frame(on_complete: Callable) -> void:
	await _tree.physics_frame
	on_complete.call()

## coroutine
static func do_next_physics_frame(node: Node, on_complete: Callable) -> void:
	if not is_instance_valid(node): return
	await node.get_tree().physics_frame
	if is_instance_valid(node): on_complete.call()

## coroutine
static func tree_do_next_frame(on_complete: Callable) -> void:
	#var id = on_complete.get_object_id()
	#print("AAA ", id, " ", on_complete.get_object().get_path())
	await _tree.process_frame
	#print("BBB ", id, " ", on_complete.get_object())
	on_complete.call()

## coroutine
static func do_next_frame(node: Node, on_complete: Callable) -> void:
	if not is_instance_valid(node): return
	await node.get_tree().process_frame
	if is_instance_valid(node): on_complete.call()

## coroutine
static func tree_timeout(seconds: float) -> void:
	if seconds <= 0.0: return
	if not _tree: printerr("Trying to timeout without tree"); return
	var timer := _tree.create_timer(seconds)
	#print("created tree timer ", timer, " ... ", get_stack())
	await timer.timeout

## coroutine
static func timeout(node: Node, seconds: float) -> void:
	if seconds <= 0.0: return
	if not node: printerr("Trying to timeout without node"); return
	if not node.is_inside_tree(): printerr("Could not start timeout, node is not inside tree"); return
	var timer = Timer.new()
	timer.one_shot = true
	node.add_child(timer)
	timer.start(seconds)
	#print("created timer ", timer, " ... ", get_stack())
	await timer.timeout
	if timer: timer.queue_free()

static func cur_time(multiplier := 1.0) -> float:
	return Time.get_ticks_msec() * 0.001 * multiplier

### prefabs

static func create_prefab(proto_node: Node, free_proto := false) -> PackedScene:
	if not proto_node:
		printerr("Trying to create prefab from null ", get_stack())
		return null
	var scene := PackedScene.new()
	for c: Node in Helpers.get_all_children(proto_node, false, true):
		if c.owner == proto_node.owner: c.owner = proto_node
	scene.pack(proto_node)
	if free_proto: proto_node.queue_free()
	elif proto_node.get_parent(): proto_node.get_parent().remove_child(proto_node)
	return scene

static func create_node_3d(parent: Node, node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	if parent: parent.add_child(node)
	return node

###

static func clean_via_feature(node: Node, before_free: Callable = Callable()) -> void:
	for tk: Node in node.find_children("*NO-INC*"):
		if before_free: before_free.call(tk)
		tk.queue_free()
	if OS.has_feature("demo"):
		for tk: Node in node.find_children("*FULL-O*"):
			if before_free: before_free.call(tk)
			tk.queue_free()
	elif OS.has_feature("editor") or OS.has_feature("full"):
		for tk: Node in node.find_children("*DEMO-O*"):
			if before_free: before_free.call(tk)
			tk.queue_free()

static func string_to_tags(str: String) -> Array[StringName]:
	var res: Array[StringName]
	for t: String in str.replace_chars(",\t\r\n", " ".unicode_at(0)).split(" ", false):
		res.append(t.to_lower())
	return res
	

### signals

static func clear_signal_connections(s: Signal) -> void:
	for sc: Dictionary in s.get_connections():
		s.disconnect(sc["callable"])

### randomness

static func shuffle(array, rnd: RandomNumberGenerator) -> void:
	var idx: int = array.size()
	while idx > 0:
		var r := rnd.randi_range(0, idx - 1)
		idx -= 1
		var t = array[idx]
		array[idx] = array[r]
		array[r] = t
