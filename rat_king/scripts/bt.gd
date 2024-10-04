class_name BT

## This is a simple behaviour tree implementation. Usage:
## ```
## # Either create the tree directly:
## _bt = BT.create() \
## 	.parallel() \
## 		.repeat() \
## 			.sequence() \
## 				.do(set_next_pos) \
## 				.do(walk_to_next_pos.bind(walk_speed)) \
## 				.wait(func() -> float: return randf_range(0.0, 1.0)) \
## 			.end() \
## 		.repeat() \
## 			.sequence() \
## 				.do(change_color) \
## 				.wait(0.75) \
## 			.end()
##
## # Or feed a text:
##  var text := "
##  parallel
##  	repeat
##  		sequence
##  			set_next_pos
##  			walk_to_next_pos {0.5 * walk_speed}
## 			wait $wait_time
## 	repeat
## 		sequence
## 			change_color
## 			wait 0.75"
## _bt = BT.create(self, text)
## ```
## To actually run the behaviour tree, call `_bt.tick()` whenever you want it to update - for realtime
## games this is usually every frame, but for turn-based games this could be on each turn.
##
## Behaviour trees created via text also support variables from the target as arguments. If you want
## these to be updated even after the tree's initialisation, give them a $ prefix (this is probably
## expensive performance-wise, so only use this for testing purposes).
## You can also use expressions by using curly braces, for example like this: `{0.5 * _speed}`. The
## expression will be evaluated at initialisation if you don't prefix it with $.
## Text-based behaviour trees also support the node `tree`. If it's at the root, it creates a tree.
## If you use `tree '<name>'` inside a tree, it will insert this tree. You can only insert trees defined
## beforehand, preventing circular insertion. For non-text-based trees, use the insert_tree() method.
##
## Composite nodes (more than 0 children): `sequence`, `selector`, `parallel`, `race`, `random_selector`
## Decorator nodes (1 child): `ignore`, `invert`, `override`, `repeat`, `retry`
## Other nodes (0 children): `nothing`, `fail`, `success`, `log`, `wait`, `do`/`prep_do`/`check`
##
## `do` is the tree node that allows using your own custom behaviours. Your behaviour function should
## return `BT.Status.Success`, `BT.Status.Fail` or `BT.Status.Running`, or a `bool`. If the function
## is `void` or returns `null`, the status is set to Success; in all other cases the internal status
## is not changed. There's `BT.Status.Nothing`, which means the result does not change the execution of
## the parent decorator or composite node.
## You can also create your own custom nodes by inheriting from the `BT.N` class. The `do` and `check`
## nodes both use the `NAction` class.
##
## Originally a port of https://github.com/ratkingsminion/simple-behaviour-tree
## Inspired by fluid BT: https://github.com/ashblue/fluid-behavior-tree
## Also by PandaBT: http://www.pandabt.com/documentation/2.0.0
## About behaviour trees: https://www.gamedeveloper.com/programming/behavior-trees-for-ai-how-they-work

const debug_color_active_node = Color.YELLOW
const debug_color_inactive_node = Color.WHITE

enum Status { Fail, Success, Running, Nothing }

const _symbol_lambda = "$"
const _whitespaces = [ " ", "\t", "\n" ]
const _string_tokens = [ "\"", "'" ]
const _digits = [ '.', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' ]
const _expr_tokens = [ '{', '}' ]
const _TYPE_IDENTIFIER = TYPE_MAX + 1
const _TYPE_EXPRESSION = TYPE_MAX + 2

class N:
	var bt: BT
	var parent: N
	var cur_status: Status = Status.Nothing:
		get: return cur_status
		# comment this out if you don't need debug display:
		set(value): cur_status = value; last_change_time = Time.get_ticks_msec()
	var last_change_time: int
	var is_processing: bool
	var cur_tick := -1
	
	func _init(bt: BT) -> void:
		self.bt = bt
		self.parent = bt._process_nodes.back() if bt._process_nodes else null
	
	func _name() -> String:
		return "node"
	
	func tick() -> void:
		if cur_status != Status.Running: _on_start()
		_on_tick()
	
	func _clone(other_tree: BT, parent: N) -> N:
		var clone := _on_clone(other_tree)
		clone.parent = parent
		return clone
	
	func _on_clone(other_tree: BT) -> N:
		return N.new(other_tree)
	
	func _on_start() -> void:
		pass
	
	func _on_tick() -> void:
		pass
	
	func _on_child_report(child: N) -> void:
		pass
	
	func _on_remove() -> void:
		pass

class NComp extends N:
	var children: Array[N] = []
	var child_count := 0
	
	func _on_clone(other_tree: BT) -> N:
		return NComp.new(other_tree)
	
	func _on_remove() -> void:
		for c: N in children:
			bt._untick_node(c, true)
	
	func add_child(n: N) -> void:
		children.append(n)
		child_count += 1

class NCompSequence extends NComp:
	var cur_idx: int
	
	func _name() -> String:
		return "sequence"
	
	func _on_clone(other_tree: BT) -> N:
		return NCompSequence.new(other_tree)
	
	func _on_start() -> void:
		cur_status = Status.Running
		cur_idx = 0
		bt._tick_node(children[cur_idx])
	
	func _on_child_report(child: N) -> void:
		if child.cur_status != Status.Running:
			if child.cur_status == Status.Fail:
				cur_status = child.cur_status
			else:
				cur_idx += 1
				if cur_idx >= child_count:
					cur_status = child.cur_status
				else:
					bt._tick_node(children[cur_idx])
					bt.is_ticking = true

class NCompSelector extends NComp:
	var cur_idx: int
	
	func _name() -> String:
		return "selector"
	
	func _on_clone(other_tree: BT) -> N:
		return NCompSelector.new(other_tree)
	
	func _on_start() -> void:
		cur_status = Status.Running
		cur_idx = 0
		bt._tick_node(children[cur_idx])
	
	func _on_child_report(child: N) -> void:
		if child.cur_status != Status.Running:
			if child.cur_status == Status.Success:
				cur_status = child.cur_status
			else:
				cur_idx += 1
				if cur_idx >= child_count:
					cur_status = child.cur_status
				else:
					bt._tick_node(children[cur_idx])
					bt.is_ticking = true

class NCompParallel extends NComp:
	var cur_success: int
	
	func _name() -> String:
		return "parallel"
	
	func _on_clone(other_tree: BT) -> N:
		return NCompParallel.new(other_tree)
	
	func _on_start() -> void:
		cur_status = Status.Running
		cur_success = 0
		for i in child_count:
			bt._tick_node(children[i])
	
	func _on_child_report(child: N) -> void:
		match child.cur_status:
			Status.Success, Status.Nothing:
				cur_success += 1
				if cur_success == child_count:
					cur_status = Status.Success
			Status.Fail:
				cur_status = Status.Fail

class NCompRace extends NComp:
	var cur_fail: int
	
	func _name() -> String:
		return "race"
	
	func _on_clone(other_tree: BT) -> N:
		return NCompRace.new(other_tree)
	
	func _on_start() -> void:
		cur_status = Status.Running
		cur_fail = 0
		for i in child_count:
			bt._tick_node(children[i])
	
	func _on_child_report(child: N) -> void:
		match child.cur_status:
			Status.Success:
				cur_status = Status.Success
			Status.Fail, Status.Nothing:
				cur_fail += 1
				if cur_fail == child_count:
					cur_status = Status.Fail

class NCompRandomSelector extends NComp:
	func _name() -> String:
		return "random_selector"
	
	func _on_clone(other_tree: BT) -> N:
		return NCompRandomSelector.new(other_tree)
	
	func _on_start() -> void:
		bt._tick_node(children.pick_random())
	
	func _on_child_report(child: N) -> void:
		cur_status = child.cur_status

class NDeco extends N:
	var child: N
	
	func _on_clone(other_tree: BT) -> N:
		return NDeco.new(other_tree)
	
	func _on_start() -> void:
		bt._tick_node(child)
	
	func _on_remove() -> void:
		bt._untick_node(child, true)

class NDecoIgnore extends NDeco:
	func _name() -> String:
		return "ignore"
	
	func _on_clone(other_tree: BT) -> N:
		return NDecoIgnore.new(other_tree)
	
	func _on_child_report(child: N) -> void:
		cur_status = Status.Nothing

class NDecoInvert extends NDeco:
	func _name() -> String:
		return "invert"
	
	func _on_clone(other_tree: BT) -> N:
		return NDecoInvert.new(other_tree)
	
	func _on_child_report(child: N) -> void:
		match child.cur_status:
			Status.Success: cur_status = Status.Fail
			Status.Fail: cur_status = Status.Success
			_: cur_status = child.curStatus

class NDecoOverride extends NDeco:
	var status
	
	func _init(bt: BT, status) -> void:
		super(bt)
		if status == null: self.status = Status.Success
		elif status is Status or status is Callable: self.status = status
		elif status is String and status.to_lower() == "fail": self.status = Status.Fail
		else: self.status = Status.Success if status else Status.Fail
	
	func _name() -> String:
		return "override [" + (str(_symbol_lambda, ":", Status.keys()[cur_status]) if status is Callable else Status.keys()[status]) + "]"
	
	func _on_clone(other_tree: BT) -> N:
		return NDecoOverride.new(other_tree, status)
	
	func _on_child_report(child: N) -> void:
		if child.cur_status == Status.Running:
			cur_status = Status.Running
		else:
			cur_status = status.call() if status is Callable else status

class NDecoRepeat extends NDeco:
	func _name() -> String:
		return "repeat"
	
	func _on_clone(other_tree: BT) -> N:
		return NDecoRepeat.new(other_tree)
	
	func _on_start() -> void:
		cur_status = Status.Running
	
	func _on_tick() -> void:
		if child.cur_status != Status.Running:
			bt._tick_node(child)
	
	func _on_child_report(child: N) -> void:
		if child.cur_status == Status.Fail:
			cur_status = Status.Fail

class NDecoRetry extends NDeco:
	func _name() -> String:
		return "retry"
	
	func _on_clone(other_tree: BT) -> N:
		return NDecoRetry.new(other_tree)
	
	func _on_start() -> void:
		cur_status = Status.Running
	
	func _on_tick() -> void:
		if child.cur_status != Status.Running:
			bt._tick_node(child)
	
	func _on_child_report(child: N) -> void:
		if child.cur_status == Status.Success:
			cur_status = Status.Success

class NNothing extends N:
	func _init(bt: BT) -> void:
		super(bt)
		cur_status = Status.Nothing
	
	func _name() -> String:
		return "nothing"
	
	func _on_clone(other_tree: BT) -> N:
		return NNothing.new(other_tree)

class NFail extends N:
	func _init(bt: BT) -> void:
		super(bt)
		cur_status = Status.Fail
	
	func _name() -> String:
		return "fail"
	
	func _on_clone(other_tree: BT) -> N:
		return NFail.new(other_tree)

class NSuccess extends N:
	func _init(bt: BT) -> void:
		super(bt)
		cur_status = Status.Success
	
	func _name() -> String:
		return "success"
	
	func _on_clone(other_tree: BT) -> N:
		return NSuccess.new(other_tree)

class NWait extends N:
	var wait_time
	var cur_time: float
	
	func _init(bt: BT, wait_time) -> void:
		super(bt)
		if bt._is_num(wait_time): wait_time = float(wait_time)
		self.wait_time = wait_time
	
	func _name() -> String:
		if wait_time is float or wait_time is int or wait_time is String:
			return "wait [%.2f/%.2f]" % [ cur_time, float(wait_time) ]
		elif wait_time is Callable:
			return "wait [%s:%.2f]" % [ _symbol_lambda, cur_time ]
		else:
			return "wait [%.2f]" % cur_time
	
	func _on_clone(other_tree: BT) -> N:
		return NWait.new(other_tree, wait_time)
	
	func _on_start() -> void:
		if wait_time is Callable: cur_time = wait_time.call()
		elif wait_time is float: cur_time = wait_time
		elif wait_time is int or wait_time is String: cur_time = float(wait_time)
		else: cur_time = 1.0
	
	func _on_tick() -> void:
		cur_time = max(0.0, cur_time - bt.dt)
		cur_status = Status.Success if cur_time <= 0.0 else Status.Running

## "log" and "print" are already in use by Godot, so it's "say" here.
class NSay extends N:
	var message
	var cur_message
	
	func _init(bt: BT, message) -> void:
		super(bt)
		self.message = message
		if message is Callable:
			# don't evaluate on _init, to reduce unwanted side effects
			cur_message = "<?>"
	
	func _name() -> String:
		if message is Callable: return "say [%s:%s]" % [ _symbol_lambda, cur_message ]
		return str("say [", message, "]")
	
	func _on_clone(other_tree: BT) -> N:
		return NSay.new(other_tree, message)
	
	func _on_start() -> void:
		if message is Callable: cur_message = message.call()
		else: cur_message = str(message)
	
	func _on_tick() -> void:
		print(cur_message)

class NAction extends N:
	var action_start: Callable
	var action_run: Callable
	var name
	
	func _init(bt: BT, action_start: Callable, action_run: Callable, name = "action") -> void:
		super(bt)
		self.action_start = action_start
		self.action_run = action_run
		self.name = name
	
	func _name() -> String:
		if name is Callable: return name.call()
		return str(name)
	
	func _on_clone(other_tree: BT) -> N:
		return NAction.new(other_tree, action_start, action_run, name)
	
	func _on_start() -> void:
		if action_start: action_start.call()
	
	func _on_tick() -> void:
		if not action_run: cur_status = Status.Fail; return
		var res = action_run.call()
		if res == null: cur_status = Status.Success
		elif res is Status: cur_status = res
		elif res is bool: cur_status = Status.Success if res else Status.Fail

###

## The target is the Godot `Node` that contains the behaviour methods, usually
var target: Object
## The delta time, fed to the tree via the `tick()` method, so the tree nodes
## (for example `BT.NWait`) can use it internally
var dt: float
## Is true if the tree is currently being evaluated via the `tick()` method
var is_ticking := false

var _nodes_to_remove: Array[N] = []
var _process_nodes: Array[N] = []
var _roots: Array[N] = []
var _tick_process_node_idx := 0
var _tick_counter := 0
var _expr := Expression.new()

###

## Create a new behaviour tree, optionally feed it a text. The target is the
## Godot Node that contains the behaviour methods, usually.
static func create(target: Object = null, text := "") -> BT:
	var bt := BT.new()
	bt.target = target
	return bt.parse_text(text) if text else bt

## Parse a string, adds the nodes inside to the tree. The BT needs to have a
## `target` defined if you use this.
func parse_text(text: String) -> BT:
	if not text: return
	
	if not target:
		print("Warning: target missing for text-based behaviour tree!")
		return self
	
	var tbts: Dictionary = {} # Dictionary[String->BT]
	var tbt := BT.create(target)
	var lines := text.replace("\r", "").split("\n")
	var tabs := []
	
	for l in lines:
		var l_stripped := l.strip_edges()
		if not l_stripped: continue
		if l_stripped.begins_with("#") or l_stripped.begins_with("//"): continue
		var cur_tab_count := l.length() - l.dedent().length()
		while tabs.size() > cur_tab_count:
			if tabs.pop_back():
				tbt.end()
		if not tabs and tbt._roots:
			tbt = BT.create(target)
		var l_args := _parse_args(l_stripped)
		var node := l_args["node"] as String
		var l_args_count := (l_args["args"] as Array).size()
		match node:
			"tree":
				if l_args_count == 0:
					print("Warning: ", node, " node needs an argument")
					if tabs: tbt.nothing()
					continue
				if l_args_count > 1:
					print("Warning: too many arguments for ", node, " node, ignoring the rest")
				if not tabs:
					if tbts.has(l_args["args"][0]):
						print("Warning: ", node, " ", l_args["args"][0], " already defined, overwriting")
					if tbt._roots: tbt = BT.create(target)
					tabs.push_back(false)
					tbts[l_args["args"][0]] = tbt
				elif not tbts.has(l_args["args"][0]):
					print("Warning: ", node, " ", l_args["args"][0], " does not exist, can't be inserted")
					tbt.nothing()
				else:
					tbt.insert_tree(tbts[l_args["args"][0]])
			"sequence", "selector", "parallel", "race", "random_selector":
				if l_args_count: print("Warning: ignoring arguments for ", node, " node")
				tabs.push_back(true)
				tbt.call(node)
			"ignore", "invert", "repeat", "retry", "fail", "success":
				if l_args_count: print("Warning: ignoring arguments for ", node, " node")
				tabs.push_back(false)
				tbt.call(node)
			"override":
				if l_args_count > 1:
					print("Warning: too many arguments for ", node, " node, ignoring the rest")
				tabs.push_back(false)
				tbt.override(l_args["args"][0] if l_args_count else Status.Success)
			"say":
				if l_args_count > 1:
					print("Warning: too many arguments for ", node, " node, ignoring the rest")
				tbt.say(l_args["args"][0] if l_args_count else "Hello, world!")
			"wait":
				if l_args_count > 1:
					print("Warning: too many arguments for ", node, " node, ignoring the rest")
				tbt.wait(l_args["args"][0] if l_args_count else 1.0)
			_: # custom node
				if not target.has_method(node):
					print("Warning: method '", node, "' not found in ", target, "!")
				elif l_args_count == 0:
					tbt.do(Callable.create(target, node), node)
				else: # has arguments
					var callable := Callable.create(target, node)
					var dyn_call
					if l_args["dyn_args"] > 0: # TODO!!!
						var dyn_args := []
						dyn_call = func():
							dyn_args.clear()
							for a in l_args["args"]: dyn_args.append(a.call() if a and a is Callable else a)
							return callable.bindv(dyn_args).call() # throws error, callable.callv(dyn_args) does not - better be explicit
					else:
						dyn_call = callable.bindv(l_args["args"])
					tbt.do(dyn_call, str(node, " [", " ".join(l_args["arg_names"]), "]"))
	
	while tabs:
		if tabs.pop_back(): tbt.end()
	
	insert_tree(tbt)
	
	return self

func _parse_args(line: String) -> Dictionary:
	var args: Array = []
	var arg_names: Array[String] = []
	var arg_types: Array[int] = []
	var res: Dictionary = { "dyn_args": 0, "args": args, "arg_types": arg_types, "arg_names": arg_names, "node": "" }
	if not line: return res
	var cur := ""
	var cur_token := ""
	var cur_lambda := false
	for i in line.length():
		var is_last := i == line.length() - 1
		var s := line[i]
		if not cur_token and (s == "#" or (s == "/" and i < line.length() - 1 and line[i + 1] == "/")):
			break
		elif not cur_token and (s in _whitespaces or is_last):
			if is_last: cur += s
			if cur:
				if str(int(cur)) == cur: args.append(int(cur)); arg_types.append(TYPE_INT)
				elif _is_num(cur): args.append(float(cur)); arg_types.append(TYPE_FLOAT)
				elif cur == "true": args.append(true); arg_types.append(TYPE_BOOL)
				elif cur == "false": args.append(false); arg_types.append(TYPE_BOOL)
				elif cur_lambda:
					args.append(func(): return target.get_indexed(cur)) # evaluated later!
					arg_types.append(TYPE_CALLABLE)
					res["dyn_args"] = res["dyn_args"] + 1
					cur = _symbol_lambda + cur # for arg_names
				elif not res["node"]: res["node"] = cur
				else: args.append(target.get_indexed(cur)); arg_types.append(_TYPE_IDENTIFIER)
				if res["node"] != cur: arg_names.append(cur)
				cur = ""
				cur_lambda = false
		elif cur_token in _string_tokens and s == cur_token: # end string
			args.append(cur)
			arg_types.append(TYPE_STRING)
			arg_names.append(str(_string_tokens[0], cur, _string_tokens[0]))
			cur = ""
			cur_token = ""
			cur_lambda = false
		elif cur_token == _expr_tokens[0] and s == _expr_tokens[1]: # end expression
			if cur_lambda:
				args.append(func(): return _evaluate_expr(cur))
				arg_types.append(TYPE_CALLABLE) # but also _TYPE_EXPRESSION
				arg_names.append(str(_symbol_lambda, _expr_tokens[0], cur, _expr_tokens[1]))
				res["dyn_args"] = res["dyn_args"] + 1
			else:
				args.append(_evaluate_expr(cur))
				arg_types.append(_TYPE_EXPRESSION)
				arg_names.append(str(_expr_tokens[0], cur, _expr_tokens[1]))
			cur = ""
			cur_token = ""
			cur_lambda = false
		elif not cur_token and (s in _string_tokens or s == _expr_tokens[0]): # start string / expression
			cur_token = s
		elif not cur and not cur_lambda and s == _symbol_lambda:
			cur_lambda = true
		else:
			cur += s
	return res

func _evaluate_expr(arg: String):
	if _expr.parse(arg) != OK:
		printerr("Expression parsing failed: ", _expr.get_error_text())
		breakpoint
		return null
	var res = _expr.execute([], target, true)
	if _expr.has_execute_failed():
		printerr("Expression execution failed: " + _expr.get_error_text())
		breakpoint
		return null
	return res

func _is_num(arg) -> bool:
	if arg is float or arg is int: return true
	if arg is String and arg[0] in _digits: return true
	return false

## Generate a debug string for the current state of the tree - use it in a `Label`
## or a `RichTextLabel` anytime you wish.
func generate_string(rich_text := false, root_idx := 0, colored_age_seconds := 0.3) -> String:
	var info: Dictionary = { "res": "", "rt": rich_text, "cas": colored_age_seconds }
	if _roots.size() - 1 >= root_idx:
		_generate_string_add_node(_roots[root_idx], info)
	return info["res"]

func _generate_string_add_node(n: N, info: Dictionary, depth := 0, tab_mul := 1) -> void:
	if not n: return
	info["res"] += "\t".repeat(depth * tab_mul)
	var cas: float = info["cas"]
	var age := clampf((Time.get_ticks_msec() - n.last_change_time) * 0.001, 0.0, cas) / cas if cas > 0.0 else 1.0
	var colored: bool = info["rt"] and n.cur_status != Status.Fail and age < 1.0
	if colored:
		var col := debug_color_active_node.lerp(debug_color_inactive_node, age)
		info["res"] += "[color=%s]" % col.to_html(false)
	info["res"] += n._name()
	if colored: info["res"] += "[/color]"
	if n is NDeco:
		info["res"] += " . "
		_generate_string_add_node(n.child, info, depth, 0)
	else:
		info["res"] += "\n"
		if n is NComp:
			for c: N in n.children: _generate_string_add_node(c, info, depth + 1)

###

## Call this everytime you want to evaluate the behaviour tree; if the returned
## `Status` is `BT.Status.Running`, you know that it wasn't evaluated completely
## but is "stuck" at one of the nodes.
func tick(delta_time: float, root_idx := 0) -> Status:
	if not _roots: return Status.Fail
	
	dt = delta_time
	
	is_ticking = true
	if not _process_nodes:
		_tick_node(_roots[root_idx])
	
	_tick_counter += 1
	while is_ticking and _process_nodes:
		_tick_process_node_idx = 0
		
		while _tick_process_node_idx < _process_nodes.size(): # list can increase during iteration
			_process_nodes[_tick_process_node_idx].tick()
			_tick_process_node_idx += 1
		
		is_ticking = false
		
		_tick_process_node_idx -= 1
		while _tick_process_node_idx >= 1:
			var n := _process_nodes[_tick_process_node_idx]
			n.parent._on_child_report(n)
			if n.cur_status != Status.Running: _untick_node(n)
			_tick_process_node_idx -= 1
		if _process_nodes[0].cur_status != Status.Running:
			_untick_node(_process_nodes[0])
		
		while _nodes_to_remove:
			var n: N = _nodes_to_remove.pop_back()
			var count := _process_nodes.size()
			_process_nodes.erase(n)
			if count != _process_nodes.size(): n._on_remove()
	
	is_ticking = false
	
	if not _process_nodes: return Status.Success
	elif _process_nodes.size() == 1: return _process_nodes[0].cur_status
	return Status.Running

func _tick_node(n: N) -> void:
	if n.cur_tick != _tick_counter:
		n.cur_tick = _tick_counter
		n.is_processing = true
		_process_nodes.append(n)

func _untick_node(n: N, set_to_fail := false) -> void:
	if n.is_processing:
		n.is_processing = false
		if set_to_fail: n.cur_status = Status.Fail
		_nodes_to_remove.push_back(n)

## Stop the current tick
func reset() -> void:
	is_ticking = false
	_tick_process_node_idx = 0
	for n: N in _process_nodes:
		n.is_processing = false
		n.cur_tick = -1
		n.cur_status = Status.Fail
	for n: N in _nodes_to_remove:
		n.is_processing = false
		n.cur_tick = -1
		n.cur_status = Status.Fail
	_process_nodes.clear()
	_nodes_to_remove.clear()

## Register a node (of type `BT.N`); usually you use the shortcut functions
## (`sequence()`, `invert()`, `do()`, etc.) for that, but you can also create
## your own nodes and add them to the tree this way
func register(n: N) -> BT:
	if _process_nodes:
		var last: N = _process_nodes.back()
		if last is NComp:
			last.add_child(n)
		elif last is NDeco:
			last.child = n
			_process_nodes.pop_back()
	else:
		_roots.append(n)
	if n is NComp or n is NDeco:
		_process_nodes.append(n)
	return self

## Inserts a tree from another `BT` into this one, copying all the nodes. Useful
## if you want to create slightly different behaviours for different agents.
func insert_tree(other: BT) -> BT:
	if not other or not other._roots:
		return self
	
	for other_root: N in other._roots:
		var cloned_root: N = other_root._clone(self, _process_nodes.back() if _process_nodes else null)
		register(cloned_root)
		
		var stack: Array[Array] = [] # Array[Array[N]]
		stack.push_back([ other_root, cloned_root ])
		while stack:
			var original: N = stack.back()[0]
			var clone: N = stack.pop_back()[1]
			if original is NComp and clone is NComp:
				for c: N in original.children:
					clone.add_child(c._clone(self, clone))
					stack.push_back([ c, clone.children.back() ])
			elif original is NDeco and clone is NDeco:
				clone.child = original.child._clone(self, clone)
				stack.push_back([ original.child, clone.child ])
		
		if cloned_root is NComp or cloned_root is NDeco:
			_process_nodes.pop_back()

	return self

## Always call this at the end of a compositor node's children list
func end() -> BT:
	if not _process_nodes:
		printerr("Malformed Behaviour Tree: too many end() calls")
		return self
	var last: N = _process_nodes.back()
	if last is not NComp:
		printerr("Malformed Behaviour Tree: end() used without composite node! (", last._name(), ")")
		return self
	if not last.child_count:
		printerr("Malformed Behaviour Tree: composite node with no children! (", last._name(), ")")
		return self
	_process_nodes.pop_back()
	return self

## Stops and resets the tree, clearing its root node
func clear_nodes() -> BT:
	reset()
	_roots.clear()
	return self

### compositors

## Iterate over the children until the child that fails.
## Don't forget to close a compositor node with `end()`
func sequence() -> BT:
	return register(NCompSequence.new(self))

## Iterate over the children until the child that succeeds.
## Don't forget to close a compositor node with `end()`
func selector() -> BT:
	return register(NCompSelector.new(self))

## Execute all the children at once until one of them fails or all of them succeed.
## Don't forget to close a compositor node with `end()`
func parallel() -> BT:
	return register(NCompParallel.new(self))

## Execute all the children at once until one of them succeeds or all of them fail.
## Don't forget to close a compositor node with `end()`
func race() -> BT:
	return register(NCompRace.new(self))

## Randomly select a child and execute it.
## Don't forget to close a compositor node with `end()`
func random_selector() -> BT:
	return register(NCompRandomSelector.new(self))

### decorators

## Shortform of `override(Status.Nothing)`, the result will be ignored
func ignore() -> BT:
	return register(NDecoIgnore.new(self))

## Invert the child's `Status`, if it's not `Running`
func invert() -> BT:
	return register(NDecoInvert.new(self))

## Override the child's `Status`, if it's not `Running`; can be a function/`Callable` too
func override(status = Status.Success) -> BT:
	return register(NDecoOverride.new(self, status))

## Repeat the child until it returns `Status.Fail`
func repeat() -> BT:
	return register(NDecoRepeat.new(self))

## Repeat the child until it returns `Status.Success`
func retry() -> BT:
	return register(NDecoRetry.new(self))

### actions

## This node does nothing, similar to `pass` in GDScript
func nothing() -> BT:
	return register(NNothing.new(self))

## Just fail
func fail() -> BT:
	return register(NFail.new(self))

## Just succeed
func success() -> BT:
	return register(NSuccess.new(self))

## Print some text, either fixed or dynamically from a function/`Callable`
func say(message) -> BT:
	return register(NSay.new(self, message))

## Wait either a fixed (`wait_time` is `float`) or a dynamic amount of seconds (`wait_time`
## is a function/`Callable` returning `float`)
func wait(wait_time = 1.0) -> BT:
	return register(NWait.new(self, wait_time))

## Do an action
func do(action: Callable, debug_name := "action") -> BT:
	return register(NAction.new(self, Callable(), action, debug_name))

## Do an action, but with preparation
func prep_do(action_start: Callable, action_run: Callable, debug_name := "action") -> BT:
	return register(NAction.new(self, action_start, action_run, debug_name))

## Same as `do()`, but using `check()` looks nicer when creating the tree and
## the `action` is a condition (e.g. something like `is_player_visible`)
func check(action: Callable, debug_name := "condition") -> BT:
	return register(NAction.new(self, Callable(), action, debug_name))
