class_name SimpleFSM
extends Node

## A method-based FSM node, created on-the-fly via code. Can be used on a single Object
## or several. Create and initialize an FSM via create():
##
## enum MyState { IDLE, WALK, DEAD } # remember, an enum is just a Dictionary[String, int]
## var fsm := SimpleFSM.create(MyState, <target_object>) # don't use SimpleFSM.new()
## fsm.set_state(MyState.IDLE) # or: fsm.set_state("idle")
##
## Possible methods in <target_object> (the parameters are all optional):
##
##    func _can_change_state_<state_name>_to(next: MyState) -> bool
##    func _can_change_state_<state_name>_from(prev: MyState) -> bool
##    func _enter_state_<state_name>(prev: MyState, stack_action: SimpleFSM.StackAction) -> void
##    func _leave_state_<state_name>(next: MyState, stack_action: SimpleFSM.StackAction) -> void
##    func _can_push_state_again_<state_nanme>() -> bool
##    # The following methods only work if <target_object> is a node
##    # or a parent was provided in create():
##    func _process_state_<state_name>(delta: float) -> void
##    func _physics_process_state_<state_name>(delta: float) -> void
##    func _input_state_<state_name>(event: InputEvent) -> void
##    func _unhandled_input_state_<state_name>(event: InputEvent) -> void
##
## By default <state_name> is the lower-case version of the MyState names, but
## the respective parameter in SimpleFSM.create() can change this.
##
## If <target_object> is an array of Objects (usually Nodes), it has to be the same
## size as the MyState Dictionary/enum. Then every method is called on each respective
## Object, as determined by their order, and the method names are shorter, e.g.
## "_enter_state" instead of "_enter_state_<state_name>".
##    As the order of the nodes matters, you can also just create the FSM via
## SimpleFSM.create_by_nodes(). On runtinme, set the states via fsm.set_state_name(<node_name>)
## or just fsm.set_state(<node_name>). Be aware _can_change_state() and the other
## methods with a state as parameter will now pass the state name instead of the index
## by default.
## If the script of the target Object(s) has a property in the form of _fsm: SimpleFSM,
## then this will automatically be filled with the created FSM.
##
## If no state is set, get_state_idx() returns -1 and get_state_name() returns "".
##
## It's possible to push and pop states. The method _can_push_state_again() can
## be used to define if a state can be pushed more than once. The default is false.
## Be aware that calling set_state() with the push parameter kept at false will reset
## the state stack and *only* call the _leave_state() of the top state on the stack.

signal state_changed(from, to)

enum StackAction { NONE, PUSH, POP }

var _states := {} # Dictionary[int, [Callable, int, Callable, int, ...]]
var _state_names: Array[String]
var _state_objects: Array[Object]
var _cur_state_stack: Array[int]
var _cur_state: Array
var _state_name_as_arg := false
var _can_process := true

static var _functions: Array = [
	"_can_change_state%s_to", 1, "_can_change_state%s_from", 1,
	"_enter_state%s", 2, "_leave_state%s", 2,
	"_process_state%s", 1, "_physics_process_state%s", 1,
	"_input_state%s", 1, "_unhandled_input%s", 1,
	"_can_push_state_again%s", 0 ]
static var _empty := [ null, -1, null, -1, null, -1, null, -1, null, -1, null, -1, null, -1, null, -1, null, -1 ]

###

## states: Dictionary[int, String] or enum
## target: Object or Array of Objects
## parent: optional parent for the FSM, needed if target is not a Node so the process methods are called
## force_lowercase: change state names to lower case in method names and when using set_state_name()
## state_name_as_arg: SimpleFSM uses the state name (instead of the index) when passing a state as argument
static func create(states: Dictionary, target, parent: Node = null, force_lowercase := true, state_name_as_arg := false) -> SimpleFSM:
	var fsm := SimpleFSM.new()
	fsm.name = "FSM"
	fsm._state_name_as_arg = state_name_as_arg
	fsm._cur_state = _empty
	fsm._states[-1] = _empty
	
	if target is Object: target.set("_fsm", fsm)
	for s in states:
		var str_name := str(s).to_lower() if force_lowercase else str(s)
		var state := []
		var t = target if target is Object else target[states[s]]
		if not t is Object: printerr("Parameter 'target' must only contain Objects"); return null
		if not target is Object: t.set("_fsm", fsm); fsm._state_objects.append(t)
		for i: int in range(0, _functions.size(), 2):
			var fn_name: String = _functions[i] % (("_" + str_name) if not target is Array else "")
			var method = t[fn_name] if t.has_method(fn_name) else null
			state.append(method)
			var arg_count: int = -1 if not method else t.get_method_argument_count(fn_name)
			if arg_count > _functions[i + 1]:
				printerr("Too many arguments for method ", fn_name, " of ", str_name, "!")
				return null
			state.append(arg_count)
		fsm._state_names.append(str_name)
		fsm._states[states[s]] = state
	
	if not parent and target is Node: parent = target as Node
	if parent: parent.call_deferred("add_child", fsm, true)
	
	return fsm

## state_nodes: Array of Nodes
## parent: optional parent for the FSM, so the process methods are called
## force_lowercase: change state names to lower case when using set_state_name()
## state_name_as_arg: SimpleFSM uses the state name (instead of the index) when passing a state as argument
static func create_by_nodes(state_nodes: Array, parent: Node = null, force_lowercase := false, state_name_as_arg := true) -> SimpleFSM:
	if not state_nodes: return null
	var dict := {}
	for n in state_nodes:
		if not n is Node: printerr("Wrong type of state node"); return null
		var str_name: String = n.name.to_lower() if force_lowercase else n.name
		dict[str_name] = dict.size()
	return create(dict, state_nodes, parent, force_lowercase, state_name_as_arg)

###

func override_process(enabled: bool) -> void:
	_can_process = enabled
	if not _cur_state_stack: return
	set_process(enabled and _has_method(_cur_state, 4))
	set_physics_process(enabled and _has_method(_cur_state, 5))
	set_process_input(enabled and _has_method(_cur_state, 6))
	set_process_unhandled_input(enabled and _has_method(_cur_state, 7))

func set_state_idx(state: int, push := false, force := false) -> bool:
	if state < -1 or state >= _states.size(): printerr("Wrong state index ", state); return false
	
	var cur_state_idx: int = _cur_state_stack.back() if _cur_state_stack else -1
	if not push and cur_state_idx == state: return false
	
	var next: Array = _states[state]
	if push and state in _cur_state_stack:
		if not _has_method(next, 8) or not _call_condition_0(next, 8): return false
	
	var arg_prev = cur_state_idx
	var arg_next = state
	if _state_name_as_arg:
		arg_prev = _state_names[cur_state_idx] if cur_state_idx >= 0 else ""
		arg_next = _state_names[state] if state >= 0 else ""
	
	if not force:
		if _has_method(_cur_state, 0) and not _call_condition_1(_cur_state, 0, arg_next): return false
		if _has_method(next, 1) and not _call_condition_1(next, 1, arg_prev): return false
	
	_call_method_2(_cur_state, 3, arg_next, StackAction.PUSH if push else StackAction.NONE)
	
	if push: _cur_state_stack.push_back(state)
	else: _cur_state_stack = [ state ]
	_cur_state = next
	state_changed.emit(arg_prev, arg_next)
	
	_call_method_2(_cur_state, 2, arg_prev, StackAction.PUSH if push else StackAction.NONE)

	override_process(_can_process)
	
	return true

func set_state_name(state_name: String, push := false, force := false) -> bool:
	if not state_name: return set_no_state(push, force)
	var idx := _state_names.find(state_name)
	if idx == -1: printerr("Wrong state name ", state_name); return false
	return set_state_idx(idx, push, force) if idx >= 0 else false

func set_state_object(state_object: Object, push := false, force := false) -> bool:
	if not state_object: return set_no_state(push, force)
	var idx := _state_objects.find(state_object)
	if idx == -1: printerr("Wrong state object ", state_object); return false
	return set_state_idx(idx, push, force) if idx >= 0 else false

func set_state(state, push := false, force := false) -> bool:
	if state is int or state is float: return set_state_idx(int(state), push, force)
	elif state is String: return set_state_name(state, push, force)
	elif state is Object: return set_state_object(state, push, force)
	return false

func set_no_state(push := false, force := false) -> bool:
	return set_state_idx(-1, push, force)

func push_state_idx(state_idx: int, force := false) -> bool:
	return set_state_idx(state_idx, true, force)

func push_state(state, force := false) -> bool:
	return set_state(state, true, force)

func push_state_name(state_name: String, force := false) -> bool:
	return set_state_name(state_name, true, force)

func push_state_object(state_object: Object, force := false) -> bool:
	return set_state_object(state_object, true, force)

func pop_state(force := true) -> bool:
	if _cur_state_stack.size() < 2: return false
	
	var cur_state_idx: int = _cur_state_stack[-1]
	var next_state_idx: int = _cur_state_stack[-2]
	var arg_prev = cur_state_idx
	var next: Array = _states[next_state_idx]
	var arg_next = next_state_idx
	if _state_name_as_arg:
		arg_prev = _state_names[cur_state_idx] if cur_state_idx >= 0 else ""
		arg_next = _state_names[next_state_idx] if next_state_idx >= 0 else ""
	
	if not force:
		if _has_method(_cur_state, 0) and not _call_condition_1(_cur_state, 0, arg_next): return false
		if _has_method(next, 1) and not _call_condition_1(next, 1, arg_prev): return false
	
	_call_method_2(_cur_state, 3, arg_next, StackAction.POP)
	
	_cur_state_stack.pop_back()
	_cur_state = next
	state_changed.emit(arg_prev, arg_next)
	
	_call_method_2(_cur_state, 2, arg_prev, StackAction.POP)

	override_process(_can_process)
	
	return true

func pop_all_states() -> bool:
	if _cur_state_stack.size() < 2: return false
	while can_pop_state(): pop_state()
	return true

func can_pop_state() -> bool:
	return _cur_state_stack.size() > 1

###

func get_state_idx() -> int:
	return _cur_state_stack.back() if _cur_state_stack else -1

func get_state_name() -> String:
	var cur_state_idx: int = _cur_state_stack.back() if _cur_state_stack else -1
	return _state_names[cur_state_idx] if cur_state_idx != -1 else ""

func get_state_object() -> Object:
	var cur_state_idx: int = _cur_state_stack.back() if _cur_state_stack else -1
	return _state_objects[cur_state_idx] if cur_state_idx != -1 else null

###

func _has_method(state: Array, idx: int) -> bool:
	return state[idx * 2 + 1] >= 0 # and state[idx * 2]

func _call_method_1(state: Array, idx: int, arg):
	match state[idx * 2 + 1]:
		-1: return
		0: state[idx * 2].call()
		_: state[idx * 2].call(arg)

func _call_method_2(state: Array, idx: int, arg1, arg2):
	match state[idx * 2 + 1]:
		-1: return
		0: state[idx * 2].call()
		1: state[idx * 2].call(arg1)
		_: state[idx * 2].call(arg1, arg2)

func _call_condition_0(state: Array, idx: int) -> bool:
	match state[idx * 2 + 1]:
		-1: return false
		_: return state[idx * 2].call()

func _call_condition_1(state: Array, idx: int, arg) -> bool:
	match state[idx * 2 + 1]:
		-1: return false
		0: return state[idx * 2].call()
		_: return state[idx * 2].call(arg)

###

func _ready() -> void:
	override_process(_can_process)

func _process(delta: float) -> void:
	_call_method_1(_cur_state, 4, delta)

func _physics_process(delta: float) -> void:
	_call_method_1(_cur_state, 5, delta)

func _input(event: InputEvent) -> void:
	_call_method_1(_cur_state, 6, event)

func _unhandled_input(event: InputEvent) -> void:
	_call_method_1(_cur_state, 7, event)
