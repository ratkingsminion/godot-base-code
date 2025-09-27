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
	
static func count_csv_file_words(file: String, idx := 0) -> int:
	var rq := RegEx.create_from_string(r"\"(.*?(?<!\\))\"")
	var rw := RegEx.create_from_string("[A-Za-z]+")
	var wc := 0
	var f := FileAccess.open(file, FileAccess.READ)
	while not f.eof_reached(): # iterate through all lines until the end of file is reached
		var contents := rq.search_all(f.get_line())
		if contents and contents.size() >= idx:
			wc += rw.search_all(contents[idx].get_string()).size()
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
		print("Screenshot taken: ", path)

### find nodes and classes

static func get_all_children(node: Node, include_self := false, include_internal := false) -> Array[Node]:
	var to_check: Array[Node] = [ node ]
	var result: Array[Node] = []
	if include_self:
		result.append(node)
	while to_check.size() > 0:
		var c := (to_check.pop_front() as Node).get_children(include_internal) # pop_front is slow unfortunately
		result.append_array(c)
		to_check.append_array(c)
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
	_scroller.scroll_vertical = int(container.size.y)
	container.set_meta("scroll_last_count", count)
	
### waiting and timing

## coroutine
static func tree_do_next_frame(on_complete: Callable) -> void:
	await _tree.process_frame
	on_complete.call()

## coroutine
static func do_next_frame(node: Node, on_complete: Callable) -> void:
	if not is_instance_valid(node): return
	await node.get_tree().process_frame
	if is_instance_valid(node): on_complete.call()

## coroutine
static func tree_timeout(seconds: float) -> void:
	if seconds <= 0.0: return
	if _tree == null: printerr("Trying to timeout without tree"); return
	await _tree.create_timer(seconds).timeout

## coroutine
static func timeout(node: Node, seconds: float) -> void:
	if seconds <= 0.0: return
	if node == null: printerr("Trying to timeout without node"); return
	var timer = Timer.new()
	timer.one_shot = true
	node.add_child(timer)
	timer.start(seconds)
	await timer.timeout
	if node: node.remove_child(timer)

static func cur_time(multiplier := 1.0) -> float:
	return Time.get_ticks_msec() * 0.001 * multiplier

### prefabs

static func create_prefab(proto_node: Node, free_proto := false) -> PackedScene:
	if not proto_node:
		printerr("Trying to create prefab from null")
		return null
	var scene := PackedScene.new()
	for c: Node in Helpers.get_all_children(proto_node, false, true):
		c.owner = proto_node
	scene.pack(proto_node)
	if free_proto: proto_node.queue_free()
	elif proto_node.get_parent(): proto_node.get_parent().remove_child(proto_node)
	return scene

static func create_node_3d(parent: Node, node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	if parent: parent.add_child(node)
	return node
	

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
