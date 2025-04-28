class_name SimpleFSM
extends Node

## A method-based FSM node, created on-the-fly via code. Can be used on a single Object or several.
## Create an FSM like this:
##
## enum MyState { IDLE, WALK, DEAD }
## var fsm := SimpleFSM.create(MyState, <target_object>) # do not use SimpleFSM.new()!
## fsm.set_state(MyState.IDLE) # or fsm.set_state("idle")
##
## Possible methods in <target_object>:
##
## func _can_change_state_<state_name>_to(next: MyState) -> bool
## func _can_change_state_<state_name>_from(prev: MyState) -> bool
## func _enter_state_<state_name>(prev: MyState) -> void
## func _leave_state_<state_name>(next: MyState) -> void
## # the following methods only work if <target_object> is a node or a parent was provided in create():
## func _process_state_<state_name>(delta: float) -> void
## func _physics_process_state_<state_name>(delta: float) -> void
## func _input_state_<state_name>(event: InputEvent) -> void
## func _unhandled_input_state_<state_name>(event: InputEvent) -> void
##
## If <target_object> is an array of Objects (usually Nodes), it has to be the same
## size as the MyState Dictionary/enum. Then every method is called on each respective
## Object, as determined by their order, and the method names are shorted by omitting
## the state name ("_enter_state" instead of "_enter_state_<state_name>").
##     As the order of the nodes matters, you can also just create the FSM via
## SimpleFSM.create_by_nodes(). Then set the states via fsm.set_state_name(<node_name>)
## or just fsm.set_state(<node_name>).
##
## Usually <state_name> is the lower-case version of the MyState members, but
## you can change this via the respective parameter in SimpleFSM.create()

signal state_changed(from: int, to: int)

var _states := {} # Dictionary[int, Array]
var _state_names := []
var _state_idx := -1
var _state: Array = _empty # [ Callable, int, Callable, int, ... ]
var _can_process := true

static var _fn_names: Array[String] = [
	"_can_change_state%s_to", "_can_change_state%s_from",
	"_enter_state%s", "_leave_state%s",
	"_process_state%s", "_physics_process_state%s",
	"_input_state%s", "_unhandled_input%s" ]
static var _empty := [ null, -1, null, -1, null, -1, null, -1, null, -1, null, -1, null, -1, null, -1 ]

###

## states: Dictionary[int, String] or enum
## target: Object or Array of Objects
## parent: optional parent for the FSM, needed if target is not a Node so the process methods are called
## force_Lowercase: change state names to lower case in method names and when using set_state_name()
static func create(states: Dictionary, target, parent: Node = null, force_lowercase := true) -> SimpleFSM:
	var fsm := SimpleFSM.new()
	fsm.name = "FSM"
	
	for s in states:
		var str_name := str(s).to_lower() if force_lowercase else str(s)
		var state := []
		var t = target if target is Object else target[states[s]]
		if not t is Object: printerr("Parameter 'target' must only contain Objects"); return
		for i: int in _fn_names.size():
			var fn_name := _fn_names[i] % (("_" + str_name) if not target is Array else "")
			var method = t[fn_name] if t.has_method(fn_name) else null
			state.append(method)
			var arg_count: int = -1 if not method else t.get_method_argument_count(fn_name)
			if arg_count > 1: printerr("Too many arguments for method ", fn_name, " of ", str_name, "!"); return null
			state.append(arg_count)
		fsm._state_names.append(str_name)
		fsm._states[states[s]] = state
	
	if not parent and target is Node: parent = target as Node
	if parent: parent.call_deferred("add_child", fsm, true)
	
	return fsm

## state_nodes: Array of Nodes
## parent: optional parent for the FSM, so the process methods are called
## force_Lowercase: change state names to lower case when using set_state_name()
static func create_by_nodes(state_nodes: Array, parent: Node = null, force_lowercase := false) -> SimpleFSM:
	if not state_nodes: return null
	var dict := {}
	for n in state_nodes:
		if not n is Node: printerr("Wrong type of state node"); return null
		var str_name: String = (n.name.to_lower()) if force_lowercase else n.name
		dict[dict.size()] = str_name
	return create(dict, state_nodes, parent, force_lowercase)

###

func override_process(enabled: bool) -> void:
	_can_process = enabled
	set_process(enabled and _has_method(_state, 4))
	set_physics_process(enabled and _has_method(_state, 5))
	set_process_input(enabled and _has_method(_state, 6))
	set_process_unhandled_input(enabled and _has_method(_state, 7))

func set_state_idx(state: int, force := false) -> bool:
	if state < 0 or state >= _states.size(): printerr("Wrong state index ", state); return false
	if _state_idx == state: return false
		
	var next: Array = _states[state] if state in _states else _empty
	
	if not force:
		if _has_method(_state, 0) and not _call_condition(_state, 0, state): return false
		if _has_method(next, 1) and not _call_condition(next, 1, _state_idx): return false
	
	_call_method(_state, 3, state)
	
	var prev_state := _state_idx
	_state_idx = state
	_state = _states[_state_idx]
	state_changed.emit(prev_state, _state_idx)
	
	_call_method(next, 2, prev_state)

	override_process(_can_process)
	
	return true

func set_state_name(state_name: String, force := false) -> bool:
	var idx := _state_names.find(state_name)
	if idx == -1: printerr("Wrong state name ", state_name); return false
	return set_state_idx(idx) if idx >= 0 else false

func set_state(state, force := false) -> bool:
	if state is int or state is float: return set_state_idx(int(state))
	elif state is String: return set_state_name(state)
	return false

func set_no_state(force := false) -> bool:
	return set_state(-1, force)

func get_state_idx() -> int:
	return _state_idx

func get_state_name() -> String:
	if _state_idx == -1: return "<no state>"
	return _state_names[_state_idx]

###

func _has_method(state: Array, idx: int) -> bool:
	return state[idx * 2 + 1] >= 0 # and state[idx * 2]

func _call_method(state: Array, idx: int, arg):
	match state[idx * 2 + 1]:
		-1: return
		0: state[idx * 2].call()
		_: state[idx * 2].call(arg)

func _call_condition(state: Array, idx: int, arg) -> bool:
	match state[idx * 2 + 1]:
		-1: return false
		0: return state[idx * 2].call()
		_: return state[idx * 2].call(arg)

###

func _ready() -> void:
	override_process(_can_process)

func _process(delta: float) -> void:
	_call_method(_state, 4, delta)

func _physics_process(delta: float) -> void:
	_call_method(_state, 5, delta)

func _input(event: InputEvent) -> void:
	_call_method(_state, 6, event)

func _unhandled_input(event: InputEvent) -> void:
	_call_method(_state, 7, event)
