class_name CheckMouse
extends Control

# Add this script to any control that should be checked for mouse over,
# or register the control via CheckMouse.register()
# Be aware that buttons always stop the mouse_entered propagation, so you
# need to register them too

static var over_counter: Array[Node]
static var over_timer := 0

###

func _ready() -> void:
	CheckMouse.register(self)

###

static func is_over(time := 50) -> bool:
	if over_timer + time > Time.get_ticks_msec(): return true
	if null in over_counter: over_counter = over_counter.filter(func(n: Node) -> bool: return n != null)
	return over_counter.size()

static func register(node: Node) -> void:
	if node == null: print("CheckMouse: trying to register null node"); return
	var control := node as Control
	if control == null:
		control = Helpers.find_in_all_children(node, Control, false, true)
		#control = node.find_children("*", "Control").front()
		if control == null:
			printerr("check_mouse: node ", node.name, " is not a Control and has no Control child")
			return
	
	control.mouse_entered.connect(CheckMouse._add_over.bind(control))
	control.mouse_exited.connect(CheckMouse._remove_over.bind(control))
	control.tree_exited.connect(CheckMouse._remove_over.bind(control))
	control.visibility_changed.connect(CheckMouse._remove_on_invisibility.bind(control))
	
	# go through the hierarchy and set the mouse filter to pass
	for c in Helpers.get_all_children(node, false, true):
	#for c in node.find_children("*"):
		if c is Control:
			if c.mouse_filter == Control.MOUSE_FILTER_STOP:
				c.mouse_filter = Control.MOUSE_FILTER_PASS
		if c is OptionButton:
			c.toggled.connect(CheckMouse._option_button_toggled.bind(c))

### events

static func _add_over(node: Node) -> void:
	if node not in over_counter:
		over_counter.append(node)

static func _remove_over(node: Node) -> void:
	if node in over_counter:
		over_counter.erase(node)
		if not over_counter:
			over_timer = Time.get_ticks_msec()

static func _remove_on_invisibility(obj: Control) -> void:
	if not obj.is_visible_in_tree():
		CheckMouse._remove_over(obj)

static func _option_button_toggled(toggled_on: bool, ob: OptionButton) -> void:
	if toggled_on: _add_over(ob.get_popup())
	else: _remove_over(ob.get_popup())
