class_name CheckMouse
extends Control

# Add this script to any control that should be checked for mouse over,
# or register the control via CheckMouse.register()
# Be aware that buttons always stop the mouse_entered propagation, so you
# need to register them too

static var over_counter: Dictionary
static var over_timer := 0

###

func _ready() -> void:
	CheckMouse.register(self)

###

static func is_over(time := 50) -> bool:
	return over_counter.size() > 0 or over_timer + time > Time.get_ticks_msec()

static func register(node: Node) -> void:
	if node == null: print("check_mouse: trying to register null node"); return
	var control := node as Control
	if control == null:
		control = Helpers.find_class_in_all_children(node, &"Control", true, true)
		if control == null:
			print("check_mouse: node ", node.name, " is not a Control and has no Control child")
			return
	
	control.mouse_entered.connect(CheckMouse._add_over.bind(control))
	control.mouse_exited.connect(CheckMouse._remove_over.bind(control))
	control.tree_exited.connect(CheckMouse._remove_over.bind(control))
	control.visibility_changed.connect(CheckMouse._remove_on_invisibility.bind(control))
	
	# go through the hierarchy and set the mouse filter to pass
	for c in Helpers.get_all_children(node, true):
		if c is Control:
			if c.mouse_filter == Control.MOUSE_FILTER_STOP:
				c.mouse_filter = Control.MOUSE_FILTER_PASS
		if c is OptionButton:
			c.toggled.connect(CheckMouse._option_button_toggled.bind(c))

### events

static func _add_over(node: Node) -> void:
	over_counter[node] = 0

static func _remove_over(node: Node) -> void:
	if over_counter.erase(node):
		if over_counter.size() == 0:
			over_timer = Time.get_ticks_msec()

static func _remove_on_invisibility(obj: Control) -> void:
	if not obj.is_visible_in_tree():
		CheckMouse._remove_over(obj)

static func _option_button_toggled(toggled_on: bool, ob: OptionButton) -> void:
	if toggled_on: _add_over(ob.get_popup())
	else: _remove_over(ob.get_popup())
