class_name BT

## A simple behaviour tree implementation
##
## Usage:
##
## # Either create the tree directly:
##	_bt = BT.create() \
##		.parallel() \
##			.repeat() \
##				.sequence() \
##					.do(set_next_pos) \
##					.do(walk_to_next_pos) \
##					.wait(func() -> float: return randf_range(0.0, 1.0)) \
##				.end() \
##			.repeat() \
##				.sequence() \
##					.do(change_color) \
##					.wait(0.75) \
##				.end()
##
## 	# Or feed a text:
## 	var text := "
## parallel
## 	repeat
## 		sequence
## 			set_next_pos
## 			walk_to_next_pos
##			wait 0.1 0.5
##	repeat
##		sequence
##			change_color
##			wait 0.75"
##	_bt = BT.create(self, text)
##	
## Behaviour trees created via text also support arguments that are variables from the target,
## but they won't get updated after the tree's initialisation.

enum Status { Fail, Success, Running }

class N:
	var bt: BT
	var parent: N
	var cur_status: Status
	var is_processing: bool
	var cur_tick := -1
	
	func _init(bt: BT) -> void:
		self.bt = bt
		self.parent = bt._process_nodes.back() if bt._process_nodes else null
	
	func tick():
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
	
	func _on_clone(other_tree: BT) -> N:
		return NCompParallel.new(other_tree)
	
	func _on_start() -> void:
		cur_status = Status.Running
		cur_success = 0
		for i in child_count:
			bt._tick_node(children[i])
	
	func _on_child_report(child: N) -> void:
		match child.cur_status:
			Status.Success:
				cur_success += 1
				if cur_success == child_count:
					cur_status= Status.Success
			Status.Fail:
				cur_status = Status.Fail

class NCompRace extends NComp:
	var cur_fail: int
	
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
			Status.Fail:
				cur_fail += 1
				if cur_fail == child_count:
					cur_status= Status.Fail

class NCompRandomSelector extends NComp:
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

class NDecoInvert extends NDeco:
	func _on_clone(other_tree: BT) -> N:
		return NDecoInvert.new(other_tree)
		
	func _on_child_report(child: N) -> void:
		match child.cur_status:
			Status.Success: cur_status = Status.Fail
			Status.Fail: cur_status = Status.Success
			_: cur_status = child.curStatus

class NDecoOverride extends NDeco:
	var fixed_status: Status
	
	func _init(bt: BT, fixed_status) -> void:
		super(bt)
		if fixed_status == null: self.fixed_status = Status.Success
		if fixed_status is Status: self.fixed_status = fixed_status
		else: self.fixed_status = Status.Success if fixed_status else Status.Fail
	
	func _on_clone(other_tree: BT) -> N:
		return NDecoOverride.new(other_tree, fixed_status)
	
	func _on_child_report(child: N) -> void:
		cur_status = Status.Running if child.cur_status == Status.Running else fixed_status

class NDecoRepeat extends NDeco:
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

class NFail extends N:
	func _init(bt: BT) -> void:
		super(bt)
		cur_status = Status.Fail
	
	func _on_clone(other_tree: BT) -> N:
		return NFail.new(other_tree)

class NSuccess extends N:
	func _init(bt: BT) -> void:
		super(bt)
		cur_status = Status.Success
	
	func _on_clone(other_tree: BT) -> N:
		return NSuccess.new(other_tree)

class NAction extends N:
	var action_start: Callable
	var action_run: Callable
	
	func _init(bt: BT, action_start: Callable, action_run: Callable) -> void:
		super(bt)
		self.action_start = action_start
		self.action_run = action_run
	
	func _on_clone(other_tree: BT) -> N:
		return NAction.new(other_tree, action_start, action_run)
	
	func _on_start() -> void:
		if action_start: action_start.call()
	
	func _on_tick() -> void:
		var res = action_run.call()
		if res == null: cur_status = Status.Success
		elif res is Status: cur_status = res
		elif res is bool: cur_status = Status.Success if res else Status.Fail

class NWait extends N:
	var wait_time
	var cur_time: float
	
	func _init(bt: BT, wait_time) -> void:
		super(bt)
		self.wait_time = wait_time
	
	func _on_clone(other_tree: BT) -> N:
		return NWait.new(bt, wait_time)
	
	func _on_start() -> void:
		if wait_time is Callable: cur_time = wait_time.call()
		elif wait_time is float: cur_time = wait_time
		elif wait_time is int or wait_time is String: cur_time = float(wait_time)
		else: cur_time = 1.0
	
	func _on_tick() -> void:
		cur_time -= bt.dt
		cur_status = Status.Success if cur_time <= 0.0 else Status.Running

###

var target: Object
var dt: float # delta time
var is_ticking := false

var _nodes_to_remove: Array[N] = []
var _process_nodes: Array[N] = []
var _roots: Array[N] = []
var _tick_process_node_idx := 0
var _tick_counter := 0

###

static func create(target: Object = null, text := "") -> BT:
	var bt := BT.new()
	bt.target = target
	
	var lines := text.replace("\r", "").split("\n")
	var tabs := []
	for l in lines:
		if not target:
			print("Warning: target missing for text-based behaviour tree!")
			break
		var l_stripped := l.strip_edges()
		if not l_stripped: continue
		if l_stripped.begins_with("#") or l_stripped.begins_with("//"): continue
		var cur_tab_count := l.length() - l.dedent().length()
		while tabs.size() > cur_tab_count:
			if tabs.pop_back(): bt.end()
		var l_parts := l_stripped.split(" ", false)
		var node := l_parts[0]
		match node:
			"sequence":
				tabs.push_back(true)
				bt.sequence();
			"selector":
				tabs.push_back(true)
				bt.selector()
			"parallel":
				tabs.push_back(true)
				bt.parallel()
			"race":
				tabs.push_back(true)
				bt.race()
			"random_selector":
				tabs.push_back(true)
				bt.random_selector()
			"invert":
				tabs.push_back(false)
				bt.invert()
			"override":
				tabs.push_back(false)
				if l_parts.size() <= 1: bt.override(true)
				elif l_parts[1].to_lower() in [ "true", "success" ]: bt.override(Status.Success)
				elif l_parts[1].to_lower() in [ "false", "fail" ]: bt.override(Status.Fail)
				else: bt.override(target.get(l_parts[1]))
			"repeat":
				tabs.push_back(false)
				bt.repeat()
			"retry":
				tabs.push_back(false)
				bt.retry()
			"fail":
				bt.fail()
			"succeess":
				bt.success()
			"wait":
				if l_parts.size() >= 3:
					var from = float(l_parts[1]) if str(float(l_parts[1])) == l_parts[1] else target.get(l_parts[1])
					var to = float(l_parts[2]) if str(float(l_parts[2])) == l_parts[2] else target.get(l_parts[2])
					bt.wait(func() -> float: return randf_range(from, to))
				elif l_parts.size() == 2:
					bt.wait(float(float(l_parts[1]) if str(float(l_parts[1])) == l_parts[1] else target.get(l_parts[1])))
				else:
					bt.wait(1.0)
			_: # self-defined node
				if not target.has_method(node):
					print("Warning: method '", node, "' not found in ", target, "!")
					continue
				if l_parts.size() == 1:
					bt.do(Callable.create(target, node))
				else: # has arguments
					var arguments := []
					var cur_str := ""
					var cur_str_token := ""
					var l_len := l_stripped.length()
					var l_idx := node.length()
					while l_idx < l_len:
						if not cur_str_token and (l_idx == l_len - 1 or l_stripped[l_idx] in [ " ", "\t", "\n" ]):
							if l_idx == l_len - 1:
								cur_str += l_stripped[l_idx]
							if cur_str:
								if str(int(cur_str)) == cur_str: arguments.append(int(cur_str))
								elif str(float(cur_str)) == cur_str: arguments.append(float(cur_str))
								elif cur_str == "true": arguments.append(true)
								elif cur_str == "false": arguments.append(false)
								else: arguments.append(target.get(cur_str))
								cur_str = ""
						elif not cur_str_token and l_stripped[l_idx] in [ "\"", "'" ]:
							cur_str_token = l_stripped[l_idx]
						elif cur_str_token and l_stripped[l_idx] == cur_str_token:
							arguments.append(cur_str)
							cur_str = ""
							cur_str_token = ""
						else:
							cur_str += l_stripped[l_idx]
						l_idx += 1
					#print("arguments for ", node, ": ", arguments)
					var callable := Callable.create(target, l_parts[0])
					if arguments.size() > callable.get_argument_count():
						print("Warning: too many arguments for method", node, ", ignoring the rest")
						arguments = arguments.slice(0, callable.get_argument_count())
					bt.do(callable.bindv(arguments))
	
	while tabs:
		if tabs.pop_back(): bt.end()
	
	return bt

###

func tick(delta_time: float, root_idx := 0) -> Status:
	if not _roots: return Status.Fail
	
	self.dt = delta_time
	
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

func register(n: N) -> BT:
	if _process_nodes:
		var last: N = _process_nodes.back()
		if last is NComp: last.add_child(n)
		elif last is NDeco:
			last.child = n
			_process_nodes.pop_back()
	else:
		_roots.append(n)
	if n is NComp or n is NDeco:
		_process_nodes.append(n)
	return self

func insert_tree(other: BT) -> BT:
	if not other or not other._roots:
		return self
	
	for other_root: N in other._roots:
		var cloned_root: N = other_root.clone(self, _process_nodes.back() if _process_nodes else null)
		register(cloned_root)
		
		var stack: Array[N] = []
		stack.push_back(other_root)
		stack.push_back(cloned_root)
		while stack:
			var clone: N = stack.pop_back()
			var original: N = stack.pop_back()
			if original is NComp and clone is NComp:
				for c: N in original.children:
					clone.add_child(c.clone(self, clone))
					stack.push_back(c)
					stack.push_back(clone.children.back())
			elif original is NDeco and clone is NDeco:
				clone.child = original.child.clone(self, clone)
				stack.push_back(original.child)
				stack.push_back(clone.child)
		
		if cloned_root is NComp:
			_process_nodes.pop_back()
	
	return self

## Always call this at the end of a compositor node's children list
func end() -> BT:
	if not _process_nodes:
		printerr("Malformed Behaviour Tree: too many end() calls")
		return self
	var last: N = _process_nodes.back()
	if last is not NComp:
		printerr("Malformed Behaviour Tree: end() used without composite node!")
		return self
	if not last.child_count:
		printerr("Malformed Behaviour Tree: composite node with no children!")
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
## Don't forget to close a compositor node with end()
func sequence() -> BT:
	return register(NCompSequence.new(self))

## Iterate over the children until the child that succeeds.
## Don't forget to close a compositor node with end()
func selector() -> BT:
	return register(NCompSelector.new(self))

## Execute all the children at once until one of them fails or all of them succeed.
## Don't forget to close a compositor node with end()
func parallel() -> BT:
	return register(NCompParallel.new(self))

## tExecute all the children at once until one of them succeeds or all of them fail.
## Don't forget to close a compositor node with end()
func race() -> BT:
	return register(NCompRace.new(self))

## Randomly select a child and execute it.
## Don't forget to close a compositor node with end()
func random_selector() -> BT:
	return register(NCompRandomSelector.new(self))

### decorators

## Invert the child's Status, if it's not running
func invert() -> BT:
	return register(NDecoInvert.new(self))

## Override the child's Status, if it's not running
func override(status) -> BT:
	return register(NDecoOverride.new(self, status))

 ## Repeat the child until it returns Status.Fail
func repeat() -> BT:
	return register(NDecoRepeat.new(self))

## Repeat the child until it returns Status.Success
func retry() -> BT:
	return register(NDecoRetry.new(self))

### actions

## Just fail
func fail() -> BT:
	return register(NFail.new(self))

## Just succeed
func success() -> BT:
	return register(NSuccess.new(self))

## Just do an action
func do(action: Callable) -> BT:
	return register(NAction.new(self, Callable(), action))

## Just do an action
func prep_do(action_start: Callable, action_run: Callable) -> BT:
	return register(NAction.new(self, action_start, action_run))

## Wait either a fixed (if wait_time is a float)
## or a dynamic amount of seconds (if wait_time is a Callable returning float)
func wait(wait_time) -> BT:
	if wait_time is not float and wait_time is not int and wait_time is not Callable and wait_time is not String:
		print("Warning: wait() should be called with either a number or a Callable")
	return register(NWait.new(self, wait_time))
